pub const Op = enum {
    add,
    sub,
};

pub const Node = union(enum) {
    number: i64,
    variable: []const u8,
    assignment: Assigment,
    binary_op: BynaryOp,
    function_decl: FunctionDecl,
    call_expr: CallExpr,
    return_stmt: *Node,

    pub const Assigment = struct {
        name: []const u8,
        value: *Node,
    };

    pub const BynaryOp = struct {
        l: *Node,
        r: *Node,
        op: Op,
    };

    pub const FunctionDecl = struct {
        name: []const u8,
        params: [][]const u8,
        body: []*Node,
    };

    pub const CallExpr = struct {
        name: []const u8,
        args: []*Node,
    }; 
};
