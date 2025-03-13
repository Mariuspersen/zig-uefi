const std = @import("std");
const UART = @import("UART.zig");
const PS2 = @import("PS2.zig");
const PCI = @import("PCI.zig");
const uefi = std.os.uefi;
const builtin = std.builtin;
const video = @import("video.zig");
const pcf = @import("PCScreenFont.zig");
const a = @import("assembly.zig");
const mmap = @import("mmap.zig");
const alloc = @import("allocator.zig");


export fn _start(g: *uefi.protocol.GraphicsOutput, m: *const mmap) callconv(.Win64) noreturn {
    video.init(g);
    alloc.init(m);
    PS2.init();
    main() catch |err| @panic(@errorName(err));
    while (true) {}
}

fn main() !void {
    const GA = alloc.get();
    const allocator = GA.allocator();

    const graphics = video.get();
    const screen = graphics.writer();
    
    var ps2 = PS2.get();
    const keyboard = ps2.reader();

    //const uart_r = UART.reader();
    //const uart_w = try UART.writer();
    try screen.print("Hello world from {any}!\n", .{@This()});
    try screen.print("Memory: {d}MB\n", .{GA.buf.len / (1028 * 1028)});
    const buf = try std.fmt.allocPrint(allocator, "{s}\n", .{"Hello :)"});
    try screen.writeAll(buf);
    try screen.print("Allocator Index {}\n", .{GA.index});
    allocator.free(buf);
    try screen.print("Allocator Index {}\n", .{GA.index});
    

    var char: u8 = try keyboard.readByte();
    while (char != 'P') : (char = try keyboard.readByte()) {
        try screen.writeByte(char);
    }

    @panic("End of main");
}

fn structInfo(writer: anytype) !void {
    const bi = @import("builtin");
    const info = @typeInfo(bi);
    inline for (info.Struct.decls) |decl| {
        try writer.print("{s} = {any}\n", .{ decl.name, @field(bi, decl.name) });
    }
}

fn makeDwarfSection(start: *u8, end: *u8) std.dwarf.DwarfInfo.Section {
    const ptr = @intFromPtr(start);
    const size = @intFromPtr(end) - @intFromPtr(start);
    return .{
        .data = @as([*]u8, @ptrFromInt(ptr))[0..size],
        .owned = false,
    };
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    const graphics = video.get();
    const RED = 0x00FF0000;
    for (graphics.buffer) |*pixel| {
        pixel.* = RED;
    }

    const uart = UART.writer() catch loopForever();
    const screen = graphics.writer();

    graphics.cursor = .{ .x = 20, .y = 20 };
    graphics.background = RED;
    graphics.foreground = 0xFFFFFFFF;

    uart.print("Kernel panicked: {s}\n", .{msg}) catch loopForever();
    screen.print("Kernel panicked: {s}\n\n", .{msg}) catch loopForever();
    if (stack_trace) |strace| {
        graphics.cursor.x = 20;
        strace.format("", .{}, uart) catch loopForever();
        strace.format("", .{}, screen) catch loopForever();
    }
    if (return_address) |ret_addr| {
        graphics.cursor.x = 20;
        uart.print("return_address: 0x{X}\n", .{ret_addr}) catch loopForever();
        screen.print("return_address: 0x{X}\n", .{ret_addr}) catch loopForever();
    }

    var stackIt = std.debug.StackIterator.init(return_address, null);
    while (stackIt.next()) |address| {
        graphics.cursor.x = 40;
        screen.print("0x{X}\n", .{address}) catch loopForever();
    }

    loopForever();
}

inline fn loopForever() noreturn {
    while (true) {
        @breakpoint();
    }
}
