const builtin = @import("std").builtin;
const FBA = @import("std").heap.FixedBufferAllocator;
const io = @import("io.zig");

var stackMem: [4096]u8 = undefined;

export fn main() void {
    var fba = FBA.init(&stackMem);
    const alloc = fba.allocator();
    _ = alloc;

    const writer = io.UART_OUT.writer() catch while (true) {};
    writer.print("Hello World! {}\n", .{2}) catch while (true) {};

    asm volatile ("HLT");
}
