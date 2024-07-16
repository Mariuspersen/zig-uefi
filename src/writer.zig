const Self = @This();
const std = @import("std");
const uefi = std.os.uefi;
const SimpleTextOutput = uefi.protocol.SimpleTextOutput;
const Status = uefi.Status;
const allocator = uefi.pool_allocator;

output: *SimpleTextOutput,

const Writer = std.io.Writer(
    *Self,
    error{ NotSuccess, InvalidUtf8, OutOfMemory },
    appendWrite,
);

pub fn init() !Self {
    if (uefi.system_table.con_out) |con| {
        return .{
            .output = con,
        };
    }
    else return error.ConOutNotFound;
}

pub fn reset(self: *Self) !void {
    if (self.output.reset(false) != .Success) return error.ResetFailed;
}

fn appendWrite(
    self: *Self,
    data: []const u8,
) error{ NotSuccess, InvalidUtf8, OutOfMemory }!usize {
    const temp = try std.unicode.utf8ToUtf16LeAlloc(allocator, data);
    defer allocator.free(temp);
    const centinel = try allocator.dupeZ(u16, temp);
    defer allocator.free(centinel);
    const result = self.output.outputString(centinel.ptr);
    if (result != .Success) return error.NotSuccess;
    return centinel.len;
}

pub fn writer(self: *Self) Writer {
    return .{ .context = self };
}
