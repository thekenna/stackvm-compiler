const std = @import("std");
const opCode = @import("../vm/instructions.zig").OpCode;
const Node = @import("ast.zig").Node;

pub const Compiler = struct {
    bytecode: std.ArrayList(u8),
    // variables: std.StringHashMap(usize), // variable name -> vm mem address
    scopes: std.ArrayList(std.StringHashMap(isize)),
    allocator: std.mem.Allocator,

    functions: std.StringHashMap(usize),

    next_address_idx: usize = 0,

    scope_offset: isize = 0, // current scope offset

    pub fn init(allocator: std.mem.Allocator) Compiler {
        var compiler = Compiler{
            .allocator = allocator,
            .bytecode = std.ArrayList(u8).initCapacity(allocator, 0) catch unreachable,
            // .variables = std.StringHashMap(usize).init(allocator),
            .scopes = std.ArrayList(std.StringHashMap(isize)).initCapacity(allocator, 1) catch unreachable,
            .functions = std.StringHashMap(usize).init(allocator),
        };

        try compiler.pushScope(); // init Global scope

        return compiler;
    }

    pub fn deinit(self: *Compiler) void {
        self.bytecode.deinit(self.allocator);
        // self.variables.deinit();
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

    fn resolveVariable

    pub fn emit(self: *Compiler, item: u8) !void {
        try self.bytecode.append(self.allocator, item);
    }

    pub fn emitOp(self: *Compiler, op: opCode) !void {
        try self.emit(@intFromEnum(op));
    }

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

                var addr: usize = 0;
                if (self.variables.get(a.name)) |existing_addr| {
                    addr = existing_addr;
                } else {
                    addr = self.next_address_idx;

                    try self.variables.put(a.name, addr);
                    self.next_address_idx += 1;
                }

                try self.emitOp(.store);
                try self.emit(@intCast(addr));
            },
            .variable => |name| {
                if (self.variables.get(name)) |addr| {
                    try self.emitOp(.load);
                    try self.emit(@intCast(addr));
                } else {
                    std.debug.print("COMPILER ERROR: Undefined variable '{s}'\n", .{name});
                    return error.UndefinedVariable;
                }
            },
            // .function_decl => |f| {
            //     // f.
            // },
            // .call_expr => || {

            // },
        }
    }
};
