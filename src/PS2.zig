const a = @import("assembly.zig");

const Self = @This();

pub const PORT = 0x60;
const STATUS = 0x64;

const Config = packed struct {
    IQR_ENABLE_1: bool,
    IRQ_ENABLE_2: bool,
    POWERED_STATE: bool,
    RESERVED_ZERO_1: bool,
    CLOCK_ENABLE_1: bool,
    CLOCK_ENABLE_2: bool,
    SCAN_CODE_TRANSLATION: bool,
    RESERVED_ZERO_2: bool,
};
