const std = @import("std");
const uefi = std.os.uefi;

const Self = @This();

graphics: *uefi.protocol.GraphicsOutput,
buffer: []u32,

pub fn init(g: *uefi.protocol.GraphicsOutput) Self {
    return .{
        .graphics = g,
        .buffer = @as([*]u32, @ptrFromInt(g.mode.frame_buffer_base))[0..@divExact(g.mode.frame_buffer_size, 4)]
    };
}