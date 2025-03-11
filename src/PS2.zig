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
    META_LEFT = 0x5B,
    META_RIGHT = 0x5C,
    ALT = 0x38,
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
            .AE => 'æ',
            .OE => 'ø',
            .AA => 'å',
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

const Reader = std.io.Reader(
    *Self,
    error{},
    read,
);

fn read(
    _: *Self,
    dest: []u8,
) error{}!usize {
    for (dest) |*char| {
        var scan = ScanCode.fetch();
        while (scan.pressed) : (scan = ScanCode.fetch()) {}
        char.* = scan.key.getChar() orelse '?';
    }
    return dest.len;
}

pub fn reader() Reader {
    return .{ .context = undefined };
}
