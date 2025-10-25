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

export fn _start(
    g: *uefi.protocol.GraphicsOutput,
    m: *const mmap,
    r: *RuntimeServices,
    x: usize,
    y: usize
) callconv(.{ .x86_64_win = .{} }) noreturn {
    rs = r;
    video.init(g,x,y);
    alloc.init(m);
    interrupts.init();
    PS2.init();
    UART.init();
    PCI.init();
    main() catch |err| errorHandler(err);
    while (true) asm volatile ("hlt");
}

fn main() !void {
    const GA = alloc.get();
    const allocator = GA.allocator();

    const graphics = video.get();
    const screen = graphics.writer();

    try screen.writeAll("Now in freestanding elf binary!\n");

    const string = try std.fmt.allocPrint(
        allocator,
        "{s}",
        .{"This string was allocated on the heap\n"},
    );
    defer allocator.free(string);
    try screen.writeAll(string);

    var ps2 = PS2.get();
    const keyboard = ps2.reader();

    try screen.print("CPU: {s}\n", .{a.cpuid()});
    try screen.print(
        "Largest Memory Descriptor: {d}MB\n",
        .{GA.buf.len / (1028 * 1028)},
    );
    try screen.writeAll("Press P if you want to test the panic handler\n");

    var char = try keyboard.readByte();
    while (true) : (char = try keyboard.readByte()) {
        switch (char) {
            '!' => ps2.reboot(),
            '"' => shutdown(),
            'P' => @panic("Pressed P for Panic"),
            else => try screen.writeByte(char),
        }
    }
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
