const std = @import("std");
const a = @import("assembly.zig");
const Self = @This();

pub const PORT = 0x60;
pub const STATUS = 0x64;

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

const Key = enum(u7) {
    A = 0x1E,
    B = 0x30,
    C = 0x2E,
    D = 0x20,
    E = 0x12,
    F = 0x21,
    G = 0x22,
    H = 0x23,
    I = 0x17,
    J = 0x24,
    K = 0x25,
    L = 0x26,
    M = 0x32,
    N = 0x31,
    O = 0x18,
    P = 0x19,
    Q = 0x10,
    R = 0x13,
    S = 0x1F,
    T = 0x14,
    U = 0x16,
    V = 0x2F,
    W = 0x11,
    X = 0x2D,
    Y = 0x15,
    Z = 0x2C,
    AE = 0x28,
    OE = 0x27,
    AA = 0x1A,
    ESC = 0x01,
    BACKSPACE = 0x0E,
    ENTER = 0x1C,
    RIGHT_SHIFT = 0x36,
    LEFT_SHIFT = 0x2A,
    CTRL = 0x1D,
    SPACE = 0x39,
    MOD = 0x60,
    CAPS = 0x3A,
    TAB = 0x0F,
    META_LEFT = 0x5B,
    META_RIGHT = 0x5C,
    PRINT = 0x37,
    SCROLL = 0x46,
    ALT = 0x38,
    LEFT = 0x4B,
    RIGHT = 0x4D,
    DOWN = 0x50,
    INSERT = 0x52,
    PAUSE = 0x45,
    HOME = 0x47,
    UP = 0x48,
    PAGE_DOWN = 0x51,
    PAGE_UP = 0x49,
    DEL = 0x53,
    F1 = 0x3B,
    F2 = 0x3C,
    F3 = 0x3D,
    F4 = 0x3E,
    F5 = 0x3F,
    F6 = 0x40,
    F7 = 0x41,
    F8 = 0x42,
    F9 = 0x43,
    F10 = 0x44,
    F11 = 0x57,
    F12 = 0x58,
    @"<" = 0x56,
    @"'" = 0x2B,
    @"¨" = 0x1B,
    @"\\" = 0x0D,
    @"+" = 0x0C,
    @"-" = 0x35,
    @"." = 0x34,
    @"," = 0x33,
    @"1" = 0x02,
    @"2" = 0x03,
    @"3" = 0x04,
    @"4" = 0x05,
    @"5" = 0x06,
    @"6" = 0x07,
    @"7" = 0x08,
    @"8" = 0x09,
    @"9" = 0x0A,
    @"0" = 0x0B,
    _,

    pub fn getChar(self: Key) ?u8 {
        return switch (self) {
            .A => 'a',
            .B => 'b',
            .C => 'c',
            .D => 'd',
            .E => 'e',
            .F => 'f',
            .G => 'g',
            .H => 'h',
            .I => 'i',
            .J => 'j',
            .K => 'k',
            .L => 'l',
            .M => 'm',
            .N => 'n',
            .O => 'o',
            .P => 'p',
            .Q => 'q',
            .R => 'r',
            .S => 's',
            .T => 't',
            .U => 'u',
            .V => 'v',
            .W => 'w',
            .X => 'x',
            .Y => 'y',
            .Z => 'z',
            .AE => 0x91,
            .OE => 0xED,
            .AA => 0x86,
            .ENTER => '\n',
            .@"1" => '1',
            .@"2" => '2',
            .@"3" => '3',
            .@"4" => '4',
            .@"5" => '5',
            .@"6" => '6',
            .@"7" => '7',
            .@"8" => '8',
            .@"9" => '9',
            .@"0" => '0',
            .@"<" => '<',
            .@"'" => 0x27,
            .@"¨" => 0x22,
            .@"\\" => 0x5C,
            .@"+" => '+',
            .@"-" => '-',
            .@"." => '.',
            .@"," => ',',
            .BACKSPACE => 0x7F,
            .SPACE => ' ',
            else => null,
        };
    }
};

pub const ScanCode = packed struct {
    key: Key,
    pressed: bool,

    pub fn fetch() ScanCode {
        while (a.inb(STATUS) & 0x01 == 0) {}
        return @bitCast(a.inb(PORT));
    }
};

SHIFT_DOWN: bool = false,
ALT_DOWN: bool = false,
META_DOWN: bool = false,
CTRL_DOWN: bool = false,

pub fn init() Self {
    return .{};
}

const Reader = std.io.Reader(
    *Self,
    error{},
    read,
);

fn read(
    self: *Self,
    dest: []u8,
) error{}!usize {
    //const writer = @import("UART.zig").writer() catch return 0;

    for (dest) |*char| {
        var scan = ScanCode.fetch();

        switch (scan.key) {
            .LEFT_SHIFT, .RIGHT_SHIFT => {
                self.SHIFT_DOWN = !self.SHIFT_DOWN;
                const size = self.read(dest) catch 0;
                return size;
            },
            else => {},
        }
        char.* = scan.key.getChar() orelse '?';
        if (char.* >= 'a' and 'z' >= char.*) {
            char.* -= if (self.SHIFT_DOWN) 'a'-'A' else 0;
        }
    }
    return dest.len;
}

pub fn reader(self: *Self) Reader {
    return .{ .context = self };
}
