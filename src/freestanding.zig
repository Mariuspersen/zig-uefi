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
    const screen = graphics.writer();
    try screen.print("Hello world from {any}!\n", .{@This()});
    try writer.writeAll("Hello World!\n");

    for (0..graphics.context.mode.max_mode) |i| {
        const mode = graphics.getInfo(@intCast(i));
        try writer.print("{any}\n", .{mode});
    }

    var char: u8 = 0;
    while (char != 'P') : (char = io.inb(io.PORT)) {
        if (char == 0) continue;
        switch (char) {
            '\r' => try screen.writeByte('\n'),
            else => try screen.writeByte(char),
        }
        try writer.print("0x{X}\n", .{char});
    }
    @panic("Oopsies");
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    const RED = 0x00FF0000;
    for (graphics.buffer) |*pixel| {
        pixel.* = RED;
    }

    const uart = io.UART_OUT.writer() catch while (true) {};
    const screen = graphics.writer();

    graphics.cursor = .{ .x = 20, .y = 20};
    graphics.background = RED;
    graphics.foreground = 0xFFFFFFFF;

    uart.print("Kernel panicked: {s}\n", .{msg}) catch while (true) {};
    screen.print("Kernel panicked: {s}\n", .{msg}) catch while (true) {};
    if (stack_trace) |strace| {
        strace.format("", .{}, uart) catch while (true) {};
        strace.format("", .{}, screen) catch while (true) {};
    }
    if (return_address) |ret_addr| {
        uart.print("return_address: 0x{X}\n", .{ret_addr}) catch while (true) {};
        screen.print("return_address: 0x{X}\n", .{ret_addr}) catch while (true) {};
    }
    while (true) {}
}
