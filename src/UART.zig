const std = @import("std");
const a = @import("assembly.zig");

const Self = @This();

pub const PORT: u16 = 0x3f8;

const Writer = std.io.Writer(
    *Self,
    error{NotSuccess},
    write,
);
fn write(
    self: *Self,
    data: []const u8,
) error{NotSuccess}!usize {
    _ = self;
    for (data) |value| {
        a.outb(PORT, value);
    }
    return data.len;
}
pub fn writer() !Writer {
    try init();
    return .{ .context = undefined };
}

fn init() !void {
    a.outb(PORT + 1, 0x00);
    a.outb(PORT + 3, 0x80);
    a.outb(PORT + 0, 0x03);
    a.outb(PORT + 1, 0x00);
    a.outb(PORT + 3, 0x03);
    a.outb(PORT + 2, 0xC7);
    a.outb(PORT + 4, 0x0B);
    a.outb(PORT + 4, 0x1E);
    a.outb(PORT + 0, 0xAE);

    if (a.inb(PORT) != 0xAE) {
        return error.FaultySerial;
    }

    a.outb(PORT + 4, 0x0F);
}

const Reader = std.io.Reader(
    *Self,
    error{},
    read,
);

fn read(
    _: *Self,
    dest: []u8,
) error{}!usize {
    var char: u8 = a.inb(PORT);
    while (char == 0) : (char = a.inb(PORT)) {}
    for (dest) |*c| c.* = char;
    return dest.len;
}

pub fn reader() Reader {
    return .{ .context = undefined };
}
