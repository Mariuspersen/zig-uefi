const std = @import("std");
const io = @import("io.zig");
const uefi = std.os.uefi;
const builtin = std.builtin;
const video = @import("video.zig");

var graphics: video = undefined;

export fn _start(g: *uefi.protocol.GraphicsOutput) callconv(.Win64) noreturn {
    graphics = video.init(g);
    main() catch |err| @panic(@errorName(err));
    while (true) {}
}

fn main() !void {
    const writer = try io.UART_OUT.writer();
    try writer.writeAll("Hello World!\n");
    @panic("Oopsies");
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    _ = stack_trace;

    for (graphics.buffer) |*value| {
        value.* = 0x00FF0000;
    }

    const writer = io.UART_OUT.writer() catch while (true) {};
    writer.print(
        "Kernel panicked: {s}",
        .{ msg},
    ) catch while (true) {};
    if (return_address) |ret_addr| {
         writer.print(
        "return_address: {d}\n",
        .{ ret_addr},
    ) catch while (true) {};
    }
    while (true) {}
}
