const Self = @This();
const std = @import("std");
const uefi = std.os.uefi;

const BootServices = uefi.tables.BootServices;
const SimpleTextInput = uefi.protocol.SimpleTextInput;
const Input = SimpleTextInput.Key.Input;

input: *SimpleTextInput,

const Reader = std.io.Reader(
    *Self,
    error{
        NotSuccess,
        Utf16LeToUtf8Error,
        DanglingSurrogateHalf,
        ExpectedSecondSurrogateHalf,
        UnexpectedSecondSurrogateHalf,
    },
    read,
);

pub fn init() !Self {
    if (uefi.system_table.con_in) |con| {
        return .{
            .input = con,
        };
    } else return error.ConInNotFound;
}

pub fn WaitForKeyPress(self: *Self, boot_service: *BootServices) bool {
    const input_events = [_]uefi.Event{
        self.input.wait_for_key,
    };
    var index: usize = undefined;

    return (boot_service.waitForEvent(
        input_events.len,
        &input_events,
        &index,
    ) == uefi.Status.Success);
}

fn read(
    self: *Self,
    dest: []u8,
) error{
    NotSuccess,
    Utf16LeToUtf8Error,
    DanglingSurrogateHalf,
    ExpectedSecondSurrogateHalf,
    UnexpectedSecondSurrogateHalf,
} !usize {
    var input: Input = undefined;
    if (self.input.readKeyStroke(&input) != .Success) return error.NotSuccess;

    var buffer: [2]u8 = undefined;
    const size = try std.unicode.utf16LeToUtf8(
        &buffer,
        &[_]u16{input.unicode_char},
    );
    dest[0] = buffer[0];
    dest[1] = buffer[1];

    return size;
}

pub fn reader(self: *Self) Reader {
    return .{ .context = self };
}

inline fn IntToByteSlice(number: anytype) [@divExact(@typeInfo(@TypeOf(number)).Int.bits, 8)]u8 {
    return @bitCast(number);
}
