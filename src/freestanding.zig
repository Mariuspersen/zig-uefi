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
const interrupts = @import("interrupts.zig");

const RuntimeServices = uefi.tables.RuntimeServices;

var rs: *RuntimeServices = undefined;

export fn _start(g: *uefi.protocol.GraphicsOutput, m: *const mmap, r: *RuntimeServices) callconv(.Win64) noreturn {
    rs = r;
    video.init(g);
    alloc.init(m);
    interrupts.init();
    PS2.init();
    UART.init();
    PCI.init();
    main() catch |err| errorHandler(err);
    while (true) {}
}

fn main() !void {
    const GA = alloc.get();
    const allocator = GA.allocator();
    
    var buffer = std.ArrayList(u8).init(allocator);
    const writer = buffer.writer();

    const graphics = video.get();
    const screen = graphics.writer();

    var ps2 = PS2.get();
    //const keyboard = ps2.reader();

    try screen.print("{s}\n", .{a.cpuid()});
    try screen.print("Memory: {d}MB\n", .{GA.buf.len / (1028 * 1028)});


    try screen.print("{any}", .{rs.resetSystem});

    var scan = PS2.ScanCode.fetch();
    while (true) : (scan = PS2.ScanCode.fetch()) {
        switch (scan.key) {
            .ESC => ps2.reboot(),
            .F1 => shutdown(),
            else => {
                if (scan.key.getChar()) |char| {
                    try screen.writeByte(char);
                    try writer.writeByte(char);
                }
            },
        }
    }

    @panic("End of main");
}

fn shutdown() noreturn {
    rs.resetSystem(
        .reset_cold,
        .success,
        0,
        null,
    );
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

pub fn errorHandler(err: anyerror) noreturn {
    @panic(@errorName(err));
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    const graphics = video.get();
    const RED = 0x00FF0000;
    for (graphics.buffer) |*pixel| {
        pixel.* = RED;
    }

    const serial = UART.get();
    const uart = serial.writer();
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
