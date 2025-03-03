const Self = @This();
const std = @import("std");
const uefi = std.os.uefi;
const SimpleTextOutput = uefi.protocol.SimpleTextOutput;
const Status = uefi.Status;

output: *SimpleTextOutput,
buffer: [64:0]u16,

const Writer = std.io.Writer(
    *Self,
    error{ NotSuccess, InvalidUtf8, OutOfMemory },
    appendWrite,
);

pub fn init() !Self {
    var temp: Self = undefined;
    if (uefi.system_table.con_out) |con| {
        temp.output = con;
    }
    else return error.ConOutNotFound;
    return temp;
}

pub fn reset(self: *Self) !void {
    if (self.output.reset(false) != .Success) return error.ResetFailed;
}

fn appendWrite(
    self: *Self,
    data: []const u8,
) error{ NotSuccess, InvalidUtf8, OutOfMemory }!usize {
    const written = try std.unicode.utf8ToUtf16Le(&self.buffer,data);
    self.buffer[written] = 0;
    if (.Success != self.output.outputString(&self.buffer)) {
        return error.NotSuccess;
    }
    return written;
}

pub fn writer(self: *Self) Writer {
    return .{ .context = self };
}
