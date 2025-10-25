pub fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "{dx}" (port),
        : .{ .dx = true, .al = true }
    );
}

pub fn outw(port: u16, val: u16) void {
    asm volatile ("outw %[val], %[port]"
        :
        : [val] "{ax}" (val),
          [port] "{dx}" (port),
        : .{ .dx = true, .ax = true }
    );
}

pub fn outl(port: u16, val: u32) void {
    asm volatile ("outl %[val], %[port]"
        :
        : [val] "{eax}" (val),
          [port] "{dx}" (port),
        : .{ .dx = true, .eax = true }
    );
}

pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[byte]"
        : [byte] "={al}" (-> u8),
        : [port] "{dx}" (port),
        : .{ .dx = true, .al = true }
    );
}

pub fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[word]"
        : [word] "={ax}" (-> u16),
        : [port] "{dx}" (port),
        : .{ .dx = true, .ax = true }
    );
}

pub fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[long]"
        : [long] "={eax}" (-> u32),
        : [port] "{dx}" (port),
        : .{ .dx = true, .eax = true }
    );
}

pub fn io_wait() void {
    outb(0x80, 0);
}

const RFLAGS = packed struct {
    CF: bool,
    _1: bool,
    PF: bool,
    _2: bool,
    AF: bool,
    _3: bool,
    ZF: bool,
    SF: bool,
    TF: bool,
    IF: bool,
    DF: bool,
    OF: bool,
    IOPL: u2,
    NT: bool,
    MD: bool,
    RF: bool,
    VM: bool,
    AC: bool,
    VIF: bool,
    VIP: bool,
    ID: bool,
    _4: u8,
    AES: bool,
    AI: bool,
    _5: u32,
};

pub fn cpuid() [12]u8 {
    const part1: [4]u8 = @bitCast(asm volatile (
        \\xor %eax,%eax
        \\cpuid
        : [_] "={ebx}" (-> u32),
        :
        : .{ .eax = true, .ebx = true, .ecx = true, .edx = true }
    ));
    const part2: [4]u8 = @bitCast(asm volatile (
        \\mov %[reg],%edx
        : [reg] "={edx}" (-> u32),
        :
        : .{ .edx = true }
    ));
    const part3: [4]u8 = @bitCast(asm volatile (
        \\mov %[reg],%ecx
        : [reg] "={ecx}" (-> u32),
        :
        : .{ .ecx = true }
    ));
    return part1 ++ part2 ++ part3;
}

pub fn flags() RFLAGS {
    return asm volatile (
        \\pushfq
        \\pop %[long]
        : [long] "={rcx}" (-> RFLAGS),
        :
        : .{ .rcx = true }
    );
}
