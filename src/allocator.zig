const std = @import("std");
const mmap = @import("mmap.zig");

const mem = std.mem;
const Allocator = std.mem.Allocator;
const Self = @This();
const MemoryDescriptor = std.os.uefi.tables.MemoryDescriptor;

//"MOOOOM, I WANT A NEW ALLOCATOR!"
//"We already have a allocator"
//The allocator at home:

var GA: Self = undefined;

buf: []u8 = undefined,
index: usize = 0,
last: ?[*]u8 = null,

pub fn init(m: *const mmap) void {
    var temp_mem: MemoryDescriptor = m.map[0];

    for (m.getSlice()) |mdesc| {
        if (mdesc.type == .ConventionalMemory and mdesc.number_of_pages > temp_mem.number_of_pages) {
            temp_mem = mdesc;
        }
    }

    GA = Self{
        .buf = @as([*]align(4096) u8, @ptrFromInt(temp_mem.physical_start))[0 .. temp_mem.number_of_pages * 4096],
    };
}

pub fn get() *Self {
    return &GA;
}

pub fn allocator(self: *Self) Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .free = free,
        },
    };
}

fn alloc(
    ctx: *anyopaque,
    len: usize,
    log2_align: u8,
    _: usize,
) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const ptr_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_align));
    const adjust_off = mem.alignPointerOffset(self.buf.ptr + self.index, ptr_align) orelse return null;
    const adjusted_index = self.index + adjust_off;
    const new_index = adjusted_index + len;
    if (new_index > self.buf.len) return null;
    self.index = new_index;
    self.last = self.buf.ptr + adjusted_index;
    return self.buf.ptr + adjusted_index;
}

fn resize(
    ctx: *anyopaque,
    buf: []u8,
    _: u8,
    _: usize,
    _: usize,
) bool {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (self.last) |last| {
        return buf.ptr == last;
    }
    return false;
}

fn free(
    ctx: *anyopaque,
    buf: []u8,
    _: u8,
    _: usize,
) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (buf.ptr == self.last) {
        self.index -= buf.len;
    }
}
