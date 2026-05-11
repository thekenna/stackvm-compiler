pub const OpCode = enum(u8) {
    exit = 0x00,
    push = 0x01,
    add = 0x02,
    sub = 0x03,
    jump = 0x04,
    jump_if_zero = 0x05,
    call = 0x06,
    ret = 0x07,
    store = 0x08,
    load = 0x09,
};
