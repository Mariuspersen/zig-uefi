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
    try writer.writeAll("Hello World!\n");

    for (0..graphics.graphics.mode.max_mode) |i| {
        const mode = graphics.getInfo(@intCast(i));
        try writer.print("{any}\n", .{mode});
    }
    
    const font = try pcf.init();
    switch (font.header) {
        else => |header| try writer.print("{any}\n", .{header}),
    }

    var x: usize = 0;
    var y: usize = 0;
    const bitField = packed struct {
        b1: bool,
        b2: bool,
        b3: bool,
        b4: bool,
        b5: bool,
        b6: bool,
        b7: bool,
        b8: bool,
    };
    var count: usize = 0;
    var ys: usize = 0;
    for (font.glyphs) |char| {
        if (char == 0) {
            y = 1;
            x += switch (font.header) {
                .psf1 => 8,
                .psf2 => |h2| h2.width,
            };
            count += 1;
            if (count > font.glyphCount) break;
            try writer.print("------------------------------------\n", .{});
            continue;
        }
        if (x + pcf.PSF1_Header.WIDTH > graphics.graphics.mode.info.pixels_per_scan_line) {
            x = 1;
            ys += switch (font.header) {
                .psf1 => |h1| h1.height,
                .psf2 => |h2| h2.height,
            };
        }
        const bits: bitField = @bitCast(char);
        const info = @typeInfo(@TypeOf(bits));
        inline for (info.Struct.fields,0..) |field,xs| {
            const value = @field(bits, field.name);
            const len = info.Struct.fields.len;
            graphics.setPixel(len - xs + x, y + ys, if (value) 0x0000FF00 else 0x00000000);
            //@compileLog(value);
        }
        y += 1;
        try writer.print("{b:0>8}\n", .{char});
        //try writer.print("0x{X}\n", .{char});
    }

    

    var char: u8 = 0;
    while (char != 'P') : (char = io.inb(io.PORT)) {
        if (char == 0) continue;
        try writer.print("Char: {c}\n", .{char});     
    }
    @panic("Oopsies");
}

pub fn panic(msg: []const u8, stack_trace: ?*builtin.StackTrace, return_address: ?usize) noreturn {
    for (graphics.buffer) |*pixel| {
        pixel.* = 0x00FF0000;
    }

    const writer = io.UART_OUT.writer() catch while (true) {};
    writer.print("Kernel panicked: {s}\n", .{msg}) catch while (true) {};
    if (stack_trace) |strace| {
        strace.format("", .{}, writer) catch while (true) {};
    }
    if (return_address) |ret_addr| {
        writer.print("return_address: 0x{X}\n", .{ret_addr}) catch while (true) {};
    }
    while (true) {}
}
