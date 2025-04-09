const InterruptDescriptorTable = packed struct {
    size: u16,
    offset: u64,
};

pub const Privilege = enum(u2) {
    kernel = 0b00,
    user = 0b11,
};

/// Global Descriptor Table entry.
pub const SegmentSelector = enum(u16) {
    null_desc = 0x00,
    kernel_code = 0x08,
    kernel_data = 0x10,
    user_code = 0x18,
    user_data = 0x20,
    tss = 0x28,
};

const InterruptDescriptor = packed struct {
    offset_low: u16,
    code_segment: SegmentSelector = .kernel_code,
    ist: u8 = 0,
    @"type": u4 = 0xE,
    zero: u1 = 0,
    dpl: Privilege,
    present: bool = true,
    offset_high: u48,
    reserved: u32 = 0,
};


pub fn disable() void {
    asm volatile ("cli");
}

pub fn enable() void {
    asm volatile ("sti");
}

var idt: [256]InterruptDescriptor linksection(".bss") = undefined;

pub fn getTable() InterruptDescriptorTable {
    var temp: InterruptDescriptorTable = undefined;
    asm volatile (
        \\sidt %[long]
        : [long] "=m" (temp),
    );
    return temp;
}

pub fn setTable(_idt: InterruptDescriptorTable) void {
    asm volatile ("lidt (%[idtr])"
        :
        : [idtr] "r" (&_idt),
    );
}

pub fn init() void {
    setTable(.{
        .offset = @intFromPtr(&idt[0]),
        .size = @sizeOf(@TypeOf(idt)) - 1,
    });
}

pub fn setupHandler(idx: u8, dpl: Privilege, fn_ptr: *const fn() void) void {

    const offset = @intFromPtr(fn_ptr);
    const offset_low: u16 = @truncate(offset);
    const offset_high: u48 = @truncate(offset >> 16);

    idt[idx] = .{
        .offset_low = offset_low,
        .dpl = dpl,
        .offset_high = offset_high
    };
}