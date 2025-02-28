const std = @import("std");
const uefi = std.os.uefi;
const builtin = std.builtin;
const FBA = std.heap.FixedBufferAllocator;
const io = @import("io.zig");

var stackMem: [4096]u8 = undefined;

export fn _start(ptr: *uefi.tables.MemoryDescriptor) callconv(.Win64) noreturn {
    main(ptr) catch |err| @panic(@errorName(err));
    while (true) {}
}

fn main(mem: *uefi.tables.MemoryDescriptor) !void {
    const writer = io.UART_OUT.writer() catch while (true) {};
    writer.print("Hello World!\n{any}", .{mem}) catch while (true) {};

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
