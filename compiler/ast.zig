
pub const Op = enum {add, sub,};

pub const Node = union(enum) {
    number: i64,
    variable: []const u8,
    assignment: Assigment,
    binary_op: BynaryOp,

    pub const Assigment = struct {
        name: []const u8,
        value: *Node,
    };

    pub const BynaryOp = struct {
        l: *Node,
        r: *Node,
        op: Op,
    };
};
