const std = @import("std");
const UART = @import("UART.zig");
const PS2 = @import("PS2.zig");
const PCI = @import("PCI.zig");
const uefi = std.os.uefi;
const builtin = std.builtin;
const video = @import("video.zig");
const pcf = @import("PCScreenFont.zig");
const a = @import("assembly.zig");


var graphics: video = undefined;

export fn _start(g: *uefi.protocol.GraphicsOutput) callconv(.Win64) noreturn {
    graphics = video.init(g);
    main() catch |err| @panic(@errorName(err));
    while (true) {}
}

fn main() !void {
    const uart = try UART.writer();
    const screen = graphics.writer();
    //const keyboard = PS2.reader();
    try screen.print("Hello world from {any}!\n", .{@This()});
    try uart.writeAll("Hello UART!\n");

    var scan = PS2.ScanCode.fetch();
    while (scan.key != .P) : (scan = PS2.ScanCode.fetch()) {
        if (scan.key == .ESC) {
            graphics.clearScreen(0x18181818);
        }
        try screen.print("{any} {X} {any}\n",.{scan.key,@intFromEnum(scan.key), scan.pressed});
    }
    @panic("End of main");
}

fn builtinInfo(writer: anytype) !void {
    const bi = @import("builtin");
    const info = @typeInfo(bi);
    inline for (info.Struct.decls) |decl| {
        try writer.print("{s} = {any}\n", .{decl.name, @field(bi, decl.name)});
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
