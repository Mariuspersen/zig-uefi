const std = @import("std");
const io = @import("io.zig");
const uefi = std.os.uefi;
const builtin = std.builtin;

export fn _start() callconv(.Win64) noreturn {
    main() catch |err| @panic(@errorName(err));
    while (true) {}
}

fn main() !void {
    const text = "Hello World!\n";
    const writer = try io.UART_OUT.writer();
    try writer.writeAll(text);
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    _ = stack_trace;

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
