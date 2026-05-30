const std = @import("std");
const opCode = @import("../vm/instructions.zig").OpCode;
const Node = @import("ast.zig").Node;

pub const Compiler = struct {
    bytecode: std.ArrayList(u8),
    // variables: std.StringHashMap(usize), // variable name -> vm mem address
    globals: std.StringHashMap(usize), 
    scopes: std.ArrayList(std.StringHashMap(isize)),
    allocator: std.mem.Allocator,

    functions: std.StringHashMap(usize),
    current_func_arg_count: usize = 0,

    next_address_idx: usize = 0,

    scope_offset: isize = 0, // current scope offset

    pub fn init(allocator: std.mem.Allocator) Compiler {
        const compiler = Compiler{
            .allocator = allocator,
            .bytecode = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable,
            // .variables = std.StringHashMap(usize).init(allocator),
            .globals = std.StringHashMap(usize).init(allocator),
            .scopes = std.ArrayList(std.StringHashMap(isize)).initCapacity(allocator, 1) catch unreachable,
            .functions = std.StringHashMap(usize).init(allocator),
        };

        // try compiler.pushScope(); // init Global scope

        return compiler;
    }

    pub fn deinit(self: *Compiler) void {
        self.bytecode.deinit(self.allocator);
        self.globals.deinit();
        self.functions.deinit();

        for (self.scopes.items) |*scope| {
            scope.deinit();
        }
        self.scopes.deinit(self.allocator);
    }

    fn pushScope(self: *Compiler) !void {
        const scope = std.StringHashMap(isize).init(self.allocator);
        try self.scopes.append(self.allocator, scope);

        self.scope_offset = 0; // reset offset for new scope
    }

    fn popScope(self: *Compiler) !void {
        var scope = self.scopes.pop() orelse {
            return error.PopEmptyScope;
        };

        scope.deinit();   
    }

    fn resolveLocal(self: *Compiler, var_name: []const u8) ?isize {
        var i = self.scopes.items.len;
        while (i > 0) {
            i -= 1;
            if (self.scopes.items[i].get(var_name)) |offset| {
                return offset;
            }
        }

        return null;
    }

    pub fn emit(self: *Compiler, item: u8) !void {
        try self.bytecode.append(self.allocator, item);
    }

    pub fn emitOp(self: *Compiler, op: opCode) !void {
        try self.emit(@intFromEnum(op));
    }

    // parse ast three to bytecode
    pub fn genNode(self: *Compiler, node: *Node) !void {
        switch (node.*) {
            .number => |n| {
                try self.emitOp(.push);
                try self.emit(@intCast(n));
            },
            .binary_op => |b| {
                try self.genNode(b.l);
                try self.genNode(b.r);

                switch (b.op) {
                    .add => try self.emitOp(.add),
                    // .sub => try self.emitOp(.sub),
                    else => return error.UnsupportedOp,
                }
            },
            .assignment => |a| {
                try self.genNode(a.value);


                if (self.scopes.items.len > 0) {
                    var offset: isize = 0;
                    if (self.resolveLocal(a.name)) |current_offset| {
                        offset = current_offset;
                    } else {
                        offset = self.scope_offset;
  
                        const scope_idx = self.scopes.items.len - 1;
                        try self.scopes.items[scope_idx].put(a.name, offset);
                        self.scope_offset += 1;
                    }
                    try self.emitOp(.store_local);
                    try self.emit(@bitCast(@as(i8, @intCast(offset))));
                } else {
                    var addr: usize = 0;
                    if (self.globals.get(a.name)) |existing_addr| {
                        addr = existing_addr;
                    } else {
                        addr = self.next_address_idx;
                        try self.globals.put(a.name, addr);
                        self.next_address_idx += 1;
                    }
                    try self.emitOp(.store);
                    try self.emit(@intCast(addr));
                }
            },
             .variable => |name| {
                if (self.resolveLocal(name)) |offset| {
                    try self.emitOp(.load_local);
                    try self.emit(@bitCast(@as(i8, @intCast(offset))));
                } 
                else if (self.globals.get(name)) |addr| {
                    try self.emitOp(.load);
                    try self.emit(@intCast(addr));
                } else {
                    std.debug.print("COMPILER ERROR: Undefined variable '{s}'\n", .{name});
                    return error.UndefinedVariable;
                }
            },
            // ** FUNCTION DECLARATION */
            .function_decl => |f| {
                // function test (a, b) {return a + b}

                // 1. (JUMP) over function body
                try self.emitOp(.jump);
                const jump_placeholder = self.bytecode.items.len; // after we load end of function body offset
                try self.emit(0); // mock it with zero
                // ['jump', 0]

                // function start index
                const func_addr = self.bytecode.items.len;
                // ['jump', 0, [idx(2)], ]
                try self.functions.put(f.name, func_addr); // func name => function start index

                // CREATE NEW FUNCTION SCOPE
                try self.pushScope();

                // Register local scope variables (params)
                const args_len = f.params.len;
                for (f.params, 0..) |param, i| {
                    const offset: isize = -@as(isize, @intCast(args_len - i)); // (a[i=0], b[i=1]) => (-(2-0), -(2-1)) => [-2, -1]
                    const scope_idx = self.scopes.items.len - 1;

                    try self.scopes.items[scope_idx].put(param, offset);
                }

                const prev_func_arg_count = self.current_func_arg_count;
                self.current_func_arg_count = f.params.len;

                // GENERATE BODY
                for (f.body) |_node| {
                    try self.genNode(_node);
                }
                
                try self.emitOp(.ret);
                try self.emit(@intCast(f.params.len));

                self.current_func_arg_count = prev_func_arg_count;

                // Clear local scope
                try self.popScope();

                // FIX JUMP IDX rewrite zero "0" to this address
                self.bytecode.items[jump_placeholder] = @intCast(self.bytecode.items.len);
            },
            // ** FUNCTION CALL */
            .call_expr => |c| {
                for (c.args) |arg| {
                    try self.genNode(arg);
                }
               
                const addr = self.functions.get(c.name) orelse return error.UndefinedFunction;
                
               
                try self.emitOp(.call);
                try self.emit(@intCast(addr));
            },
            .return_stmt => |_node| {
                try self.genNode(_node);

                try self.emitOp(.ret);
                try self.emit(@intCast(self.current_func_arg_count));
            }
        }
    }
};
