const std = @import("std");

const uefiWriter = @import("writer.zig");
const uefiReader = @import("reader.zig");

const uefi = std.os.uefi;

const Status = uefi.Status;

const SimpleTextInput = uefi.protocol.SimpleTextInput;
const Input = SimpleTextInput.Key.Input;
const BootServices = uefi.tables.BootServices;
const allocator = uefi.pool_allocator;

pub fn main() Status {
    var uefi_out = uefiWriter.init() catch return Status.Aborted;
    const stdout = uefi_out.writer();
    setup() catch |err| {
        stdout.print("\r\nERROR: {any}\r\n", .{err}) catch {};
        return Status.Aborted;
    };
    return Status.Success;
}

fn setup() !void {
    const bs = uefi.system_table.boot_services orelse return error.NoBs;

    var uefi_out = try uefiWriter.init();
    var uefi_in = try uefiReader.init();

    const stdout = uefi_out.writer();
    const stdin = uefi_in.reader();

    try uefi_out.reset();
    try stdout.print("Hello UEFI from Zig", .{});

    while (uefi_in.WaitForKeyPress(bs)) {
        var buffer: [2]u8 = undefined;
        _ = try stdin.read(&buffer);
        switch (buffer[0]) {
            '\r' => try stdout.writeAll("\r\n"),
            'a'...'z','A'...'Z','0'...'9' => try stdout.writeByte(buffer[0]),
            0 => break,
            else => try stdout.print("{x}\r\n", .{buffer}),
        }
    }
}
