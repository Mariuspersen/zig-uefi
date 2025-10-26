const std = @import("std");
const psf = @import("PCScreenFont.zig");
const uefi = std.os.uefi;
const GraphicsOutput = uefi.protocol.GraphicsOutput;
const Writer = std.io.Writer;
const Error = Writer.Error;

const Self = @This();

const Cursor = struct {
    x: usize = 0,
    y: usize = 0,
};

var graphics: Self = undefined;
var buf: [1024]u8 = undefined;

context: *GraphicsOutput,
buffer: []u32,
background: u32 = 0x18181818,
foreground: u32 = 0xAAAAAAAA,
font: psf,
cursor: Cursor = .{},

pub fn init(ctx: *GraphicsOutput, x: usize, y: usize) void {
    var temp = Self{
        .context = ctx,
        .buffer = @as([*]u32, @ptrFromInt(ctx.mode.frame_buffer_base))[0..@divExact(ctx.mode.frame_buffer_size, 4)+1],
        .font = psf.init() catch @panic("Could not init a font!"),
        .cursor = .{ .x = x, .y = y},
    };
    if (x == 0 and y == 0) {
        temp.clearScreen(temp.background);
    }
    graphics = temp;
}

pub fn get() *Self {
    return &graphics;
}

pub inline fn setPixel(self: *Self, x: usize, y: usize, color: u32) void {
    self.buffer[x + (y * self.context.mode.info.pixels_per_scan_line)] = color;
}

pub fn clearScreen(self: *Self, color: u32) void {
    for (self.buffer) |*pixel| {
        pixel.* = color;
    }
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
        inline for (info.@"struct".fields, 0..) |field, xs| {
            const value = @field(bits, field.name);
            const len = info.@"struct".fields.len;
            self.setPixel(len - xs + x, y + ys, if (value) self.foreground else self.background);
        }
        ys += 1;
    }
}

const _Writer = std.io.Writer(
    *Self,
    error{},
    write,
);

fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    _ = w;
    _ = data;
    _ = splat;
}

fn writer(buffer: []u8) Writer {
    return .{
        .buffer = buffer,
        .vtable = .{
            .drain = drain,
        },
    };
}

fn write(self: *Self, data: []const u8) error{}!usize {
    const width = self.font.getWidth();
    const height = self.font.getHeight();
    for (data) |char| {
        if (self.cursor.x + width > self.context.mode.info.horizontal_resolution) {
            self.cursor.y += height;
            self.cursor.x = 0;
        }
        if (self.cursor.y + height > self.context.mode.info.vertical_resolution) {
            self.cursor.y = 0;
            self.cursor.x = 0;
        }
        switch (char) {
            0x7F => {
                if (self.cursor.x < width) {
                    if (self.cursor.y < height) {
                        self.cursor.x = self.context.mode.info.horizontal_resolution;
                        self.cursor.y = self.context.mode.info.vertical_resolution;
                    }
                    self.cursor.y -= height;
                    self.cursor.x = self.context.mode.info.horizontal_resolution;

                }
                self.cursor.x -= width;
                self.writeGlyph(0, self.cursor.x, self.cursor.y);
            },
            '\n' => {
                self.cursor.y += height;
                self.cursor.x = 0;
            },
            '\r' => self.cursor.x = 0,
            else => {
                self.writeGlyph(char,self.cursor.x,self.cursor.y);
                self.cursor.x += width;
            }
        }
    }
    return data.len;
}

pub fn _writer(self: *Self) Writer {
    return Writer{ .context = self };
}

// TODO: This can't be used after exitBootServices, is there another way?
pub fn getInfo(self: *Self, mode: u32) *GraphicsOutput.Mode.Info {
    var info: *GraphicsOutput.Mode.Info = undefined;
    var size: usize = @sizeOf(GraphicsOutput.Mode.Info);
    _ = self.context.queryMode(mode, &size, &info);
    return info;
}
