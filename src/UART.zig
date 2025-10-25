const std = @import("std");
const a = @import("assembly.zig");
const Writer = std.io.Writer;
const Error = Writer.Error;
const Reader = std.io.Reader;

pub const PORT: u16 = 0x3f8;

const Self = @This();

interface_write: Writer,

var UART: Self = undefined;
var buf: [1024]u8 = undefined;

fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    if (data.len == 0) return 0;
    var count: usize = 0;
    for (w.buffer[0..w.end]) |char| {
        a.outb(PORT, char);
        count += 1;
    }
    for (data) |string| for (string) |char| {
        a.outb(PORT, char);
        count += 1;
    };
    for (0..splat) |_| {
        for (data[data.len - 1]) |value| {
            a.outb(PORT, value);
            count += 1;
        }
    }
    w.end += count;
    return count;
}

fn writer(buffer: []u8) Writer {
    return .{
        .buffer = buffer,
        .vtable = .{
            .drain = drain,
        },
    };
}

pub fn init() void {
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
        const graphics = @import("video.zig").get();
        const gwriter = graphics.writer();
        gwriter.writeAll("UART Unavailable\n") catch {};
    }

    a.outb(PORT + 4, 0x0F);

    UART = .{
        .interface_write = writer(&buf)
    };
}


fn read(
    _: *Self,
    dest: []u8,
) error{}!usize {
    var char: u8 = a.inb(PORT);
    while (char == 0) : (char = a.inb(PORT)) {}
    for (dest) |*c| c.* = char;
    return dest.len;
}

fn reader(buffer: []u8) Reader {
    return .{
        .buffer = buffer,
        .vtable = .{
            
        }
    };
}
