const std = @import("std");
const psf = @import("PCScreenFont.zig");
const uefi = std.os.uefi;
const GraphicsOutput = uefi.protocol.GraphicsOutput;

const Self = @This();

const Cursor = struct {
    x: usize = 0,
    y: usize = 0,
};

context: *GraphicsOutput,
buffer: []u32,
background: u32 = 0x00000000,
foreground: u32 = 0x0000FF00,
font: psf,
cursor: Cursor = .{},

pub fn init(ctx: *GraphicsOutput) Self {
    return .{
        .context = ctx,
        .buffer = @as([*]u32, @ptrFromInt(ctx.mode.frame_buffer_base))[0..@divExact(ctx.mode.frame_buffer_size, 4)],
        .font = psf.init() catch @panic("Could not init a font!"),
    };
}

pub inline fn setPixel(self: *Self, x: usize, y: usize, color: u32) void {
    self.buffer[x + (y * self.context.mode.info.pixels_per_scan_line)] = color;
}

pub fn writeGlyph(self: *Self, index: usize, x: usize, y: usize) void {
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
    const glyph = self.font.getChar(index);

    var ys: usize = 0;
    for (glyph) |line| {
        const bits: bitField = @bitCast(line);
        const info = @typeInfo(@TypeOf(bits));
        inline for (info.Struct.fields, 0..) |field, xs| {
            const value = @field(bits, field.name);
            const len = info.Struct.fields.len;
            self.setPixel(len - xs + x, y + ys, if (value) self.foreground else self.background);
        }
        ys += 1;
    }
}

const Writer = std.io.Writer(
    *Self,
    error{},
    write,
);

fn write(self: *Self, data: []const u8) error{}!usize {
    for (data) |char| {
        if (self.cursor.x + self.font.getWidth() > self.context.mode.info.pixels_per_scan_line) {
            self.cursor.y += self.font.getHeight();
            self.cursor.x = 0;
        }
        switch (char) {
            0x7F => {
                // TODO: Fix wrapping
                self.writeGlyph(0, self.cursor.x, self.cursor.y);
                self.cursor.x -= self.font.getWidth();
            },
            '\n' => {
                self.cursor.y += self.font.getHeight();
                self.cursor.x = 0;
            },
            '\r' => self.cursor.x = 0,
            else => {
                self.writeGlyph(char,self.cursor.x,self.cursor.y);
                self.cursor.x += self.font.getWidth();
            }
        }
    }
    return data.len;
}

pub fn writer(self: *Self) Writer {
    return Writer{ .context = self };
}

pub fn getInfo(self: *Self, mode: u32) *GraphicsOutput.Mode.Info {
    var info: *GraphicsOutput.Mode.Info = undefined;
    var size: usize = @sizeOf(GraphicsOutput.Mode.Info);
    _ = self.context.queryMode(mode, &size, &info);
    return info;
}
