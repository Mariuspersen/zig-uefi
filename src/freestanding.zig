const std = @import("std");
const builtin = std.builtin;
const FBA = std.heap.FixedBufferAllocator;
const io = @import("io.zig");

var stackMem: [4096]u8 = undefined;

export fn main() void {
    var fba = FBA.init(&stackMem);
    const alloc = fba.allocator();
    _ = alloc;

    const writer = io.UART_OUT.writer() catch while (true) {};
    writer.print("Hello World! {any}\n", .{@This()}) catch while (true) {};
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
