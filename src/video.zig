const std = @import("std");
const uefi = std.os.uefi;
const GraphicsOutput = uefi.protocol.GraphicsOutput;

const Self = @This();

graphics: *GraphicsOutput,
buffer: []u32,

pub fn init(g: *GraphicsOutput) Self {    
    return .{
        .graphics = g,
        .buffer = @as([*]u32, @ptrFromInt(g.mode.frame_buffer_base))[0..@divExact(g.mode.frame_buffer_size, 4)]
    };
}

pub inline fn setPixel(self: *Self, x: usize, y: usize, color: u32) void {
    self.buffer[x + (y * self.graphics.mode.info.pixels_per_scan_line)] = color;
}

pub fn getInfo(self: *Self, mode: u32) *GraphicsOutput.Mode.Info {
    var info: *GraphicsOutput.Mode.Info = undefined;
    var size: usize = @sizeOf(GraphicsOutput.Mode.Info);
    _ = self.graphics.queryMode(mode, &size, &info);
    return info;
}