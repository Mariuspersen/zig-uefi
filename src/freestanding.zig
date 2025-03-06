const std = @import("std");
const io = @import("io.zig");
const uefi = std.os.uefi;
const builtin = std.builtin;
const video = @import("video.zig");
const pcf = @import("PCScreenFont.zig");

var graphics: video = undefined;

export fn _start(g: *uefi.protocol.GraphicsOutput) callconv(.Win64) noreturn {
    graphics = video.init(g);
    main() catch |err| @panic(@errorName(err));
    while (true) {}
}

fn main() !void {
    const writer = try io.UART_OUT.writer();
    try writer.writeAll("Hello World!\n");

    for (0..graphics.graphics.mode.max_mode) |i| {
        const mode = graphics.getInfo(@intCast(i));
        try writer.print("{any}\n", .{mode});
    }

    graphics.setPixel(1, 1, 0x0000FF00);
    graphics.setPixel(1, 2, 0x0000FF00);
    graphics.setPixel(1, 3, 0x0000FF00);
    graphics.setPixel(3, 1, 0x0000FF00);
    graphics.setPixel(3, 2, 0x0000FF00);
    graphics.setPixel(3, 3, 0x0000FF00);
    graphics.setPixel(2, 2, 0x0000FF00);

    var fbs = std.io.fixedBufferStream(pcf.lat0);
    const fontReader = fbs.reader();

    const header = try fontReader.readStruct(pcf.PSF1_Header);
    if (header.magic != pcf.PSF1_FONT_MAGIC) return error.InvalidPSF1FontMagic;
    try writer.print("{any}\n", .{header});

    var char: u8 = 0;
    while (char != 'P') : (char = io.inb(io.PORT)) {
        if (char == 0) continue;
        try writer.print("Char: {c}\n", .{char});     
    }
    @panic("Oopsies");
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    for (graphics.buffer) |*pixel| {
        pixel.* = 0x00FF0000;
    }

    const writer = io.UART_OUT.writer() catch while (true) {};
    writer.print("Kernel panicked: {s}\n", .{msg}) catch while (true) {};
    if (stack_trace) |strace| {
        strace.format("", .{}, writer) catch while (true) {};
    }
    if (return_address) |ret_addr| {
        writer.print("return_address: 0x{X}\n", .{ret_addr}) catch while (true) {};
    }
    while (true) {}
}
