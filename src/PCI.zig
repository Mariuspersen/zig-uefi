const a = @import("assembly.zig");
const std = @import("std");

pub const CONFIG_ADDRESS = 0xCF8;
pub const CONFIG_DATA = 0xCFC;

var PCI: Self = undefined;

const ConfigSpace = packed struct {
    offset: u8,
    func: u3,
    slot: u5,
    bus: u8,
    _: u7 = 0,
    enable: bool = true,
};

comptime {
    if (@sizeOf(StatusRegister) != @sizeOf(u16)) {
        @compileError("Status Register needs to be a u16");
    }
}

const StatusRegister = packed struct {
    //Reserved
    __: u3 = 0,
    //Interrupt Status
    IS: bool,
    //Capabilities List
    CL: bool,
    //66 MHz Capable
    @"66MHzC": bool,
    //Reserved
    _: u1 = 0,
    //Fast Back-to-Back Capable
    FBBC: bool,
    //Master Data Parity Error
    MDPE: bool,
    //DEVSEL Timing
    DEVSEL: u2,
    //Signaled Target Abort
    STA: bool,
    //Received Target Abort
    RTA: bool,
    //Received Master Abort
    RMA: bool,
    //Signaled System Error
    SSE: bool,
    //Detected Parity Error
    DPE: bool,

    pub fn get(bus: u8, slot: u5) StatusRegister {
        return @bitCast(pciConfigReadWord(bus, slot, 0, 6));
    }
};

const CommandRegister = packed struct {
    //I/O Space
    IOS: bool,
    //Memory Space
    MS: bool,
    //Bus Master
    BM: bool,
    //Special Cycles
    SC: bool,
    //Memory Write and Invalidate Enable
    MWIE: bool,
    //VGA Palette Snoop
    VGAPS: bool,
    //Parity Error Response
    PER: bool,
    //Reserved
    _: u1,
    //SERR# Enable
    SERRE: bool,
    //Fast Back-to-Back Enable
    FBBE: bool,
    //Interrupt Disable
    ID: bool,
    //Reserved
    __: u5,

    fn get(bus: u8, slot: u5) CommandRegister {
        return @bitCast(pciConfigReadWord(bus, slot, 0, 4));
    }
};

const Register0 = packed struct {
    vendor: u16,
    device: u16,

    pub fn get(bus: u8, slot: u5) Register0 {
        return @bitCast(pciConfigReadLong(bus, slot, 0, 0));
    }
};

const Register1 = packed struct {
    status: StatusRegister,
    command: CommandRegister,

    pub fn get(bus: u8, slot: u5) Register1 {
        return @bitCast(pciConfigReadLong(bus, slot, 0, 0x4));
    }
};

const Register2 = packed struct {
    rev: u8,
    //Programming Interface
    PI: u8,
    subclass: u8,
    class: u8,

    pub fn get(bus: u8, slot: u5) Register2 {
        return @bitCast(pciConfigReadLong(bus, slot, 0, 0x8));
    }
};

const HeaderType = enum(u8) {
    GENERAL_DEVICE = 0x0,
    PCI_BRIDGE = 0x1,
    CARDBUS_BRIDGE = 0x2,
    _,
};

const Register3 = packed struct {
    //Cache Line Size
    CLS: u8,
    //Latency Timer
    LT: u8,
    T: HeaderType,
    class: u8,

    pub fn get(bus: u8, slot: u5) Register3 {
        return @bitCast(pciConfigReadLong(bus, slot, 0, 0xC));
    }
};

const Header = struct {
    reg0: Register0,
    reg1: Register1,
    reg2: Register2,
    reg3: Register3,

    pub fn get(_: u8, _: u5) Header {}
};

const Self = @This();

pub fn init() void {
    const video = @import("video.zig").get();
    const writer = video.writer();
    const pci = Register0.get(0, 1);
    const status = Register1.get(0, 1);
    const command = Register2.get(0, 1);
    const reg3 = Register3.get(0, 1);
    writer.print("{any}\n", .{pci}) catch @panic("Eh");
    writer.print("{any}\n", .{status}) catch @panic("Eh");
    writer.print("{any}\n", .{command}) catch @panic("Eh");
    writer.print("{any}\n", .{reg3}) catch @panic("Eh");
}

fn pciConfigReadWord(bus: u8, slot: u5, func: u3, offset: u8) u16 {
    const config = ConfigSpace{
        .bus = bus,
        .slot = slot,
        .func = func,
        .offset = offset,
    };
    a.outl(CONFIG_ADDRESS, @bitCast(config));
    return @bitCast(a.inw(CONFIG_DATA));
}

fn pciConfigReadLong(bus: u8, slot: u5, func: u3, offset: u8) u32 {
    const config = ConfigSpace{
        .bus = bus,
        .slot = slot,
        .func = func,
        .offset = offset,
    };
    a.outl(CONFIG_ADDRESS, @bitCast(config));
    return @bitCast(a.inl(CONFIG_DATA));
}
