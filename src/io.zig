const std = @import("std");

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[byte]"
        : [byte] "={al}" (-> u8),
        : [port] "{dx}" (port),
        : "dx", "al"
    );
}

fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[word]"
        : [word] "={ax}" (-> u16),
        : [port] "{dx}" (port),
        : "dx", "ax"
    );
}

fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[long]"
        : [long] "={eax}" (-> u32),
        : [port] "{dx}" (port),
        : "dx", "eax"
    );
}

const PORT: u16 = 0x3f8;

var incompleteInit = true;
pub const UART_OUT = struct {
    const Self = @This();
    const Writer = std.io.Writer(
        *Self,
        error{NotSuccess},
        write,
    );
    fn write(
        self: *Self,
        data: []const u8,
    ) error{NotSuccess}!usize {
        _ = self;
        for (data) |value| {
            outb(PORT, value);
        }
        return data.len;
    }
    pub fn writer() !Writer {
        try init();
        return .{ .context = undefined };
    }
    fn init() !void {
        outb(PORT + 1, 0x00);
        outb(PORT + 3, 0x80);
        outb(PORT + 0, 0x03);
        outb(PORT + 1, 0x00);
        outb(PORT + 3, 0x03);
        outb(PORT + 2, 0xC7);
        outb(PORT + 4, 0x0B);
        outb(PORT + 4, 0x1E);
        outb(PORT + 0, 0xAE);

        if (inb(PORT) != 0xAE) {
            return error.FaultySerial;
        }

        outb(PORT + 4, 0x0F);
    }
    fn outb(port: u16, val: u8) void {
        asm volatile ("outb %[val], %[port]"
            :
            : [val] "{al}" (val),
              [port] "{dx}" (port),
            : "dx", "al"
        );
    }

    fn outw(port: u16, val: u16) void {
        asm volatile ("outb %[val], %[port]"
            :
            : [val] "{ax}" (val),
              [port] "{dx}" (port),
            : "dx", "ax"
        );
    }

    fn outl(port: u16, val: u32) void {
        asm volatile ("outb %[val], %[port]"
            :
            : [val] "{eax}" (val),
              [port] "{dx}" (port),
            : "dx", "eax"
        );
    }
};
