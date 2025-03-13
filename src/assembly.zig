pub fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "{dx}" (port),
        : "dx", "al"
    );
}

pub fn outw(port: u16, val: u16) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{ax}" (val),
          [port] "{dx}" (port),
        : "dx", "ax"
    );
}

pub fn outl(port: u16, val: u32) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{eax}" (val),
          [port] "{dx}" (port),
        : "dx", "eax"
    );
}

pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[byte]"
        : [byte] "={al}" (-> u8),
        : [port] "{dx}" (port),
        : "dx", "al"
    );
}

pub fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[word]"
        : [word] "={ax}" (-> u16),
        : [port] "{dx}" (port),
        : "dx", "ax"
    );
}

pub fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[long]"
        : [long] "={eax}" (-> u32),
        : [port] "{dx}" (port),
        : "dx", "eax"
    );
}

pub fn io_wait() void {
    outb(0x80, 0);
}