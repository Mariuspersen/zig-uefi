const std = @import("std");

const uefiWriter = @import("writer.zig");
const uefiReader = @import("reader.zig");
const mmap = @import("mmap.zig");
const video = @import("video.zig");

const uefi = std.os.uefi;

const Status = uefi.Status;

const SimpleTextInput = uefi.protocol.SimpleTextInput;
const GraphicsOutput = uefi.protocol.GraphicsOutput;
const Input = SimpleTextInput.Key.Input;
const BootServices = uefi.tables.BootServices;
const RuntimeServices = uefi.tables.RuntimeServices;

const PageAlignedPointer = [*]align(std.heap.pageSize()) u8;

const efi_page_mask: usize = 0xfff;
const efi_page_shift: usize = 12;
/// Convert a memory size to memory pages (4096 bytes each)
pub inline fn efiSizeToPages(value: anytype) @TypeOf(value) {
    const addition: @TypeOf(value) = if (value & efi_page_mask != 0) 1 else 0;
    const ret = (value >> efi_page_shift) + addition;
    return ret;
}

pub fn main() Status {
    const v = video.get();
    const screen = v.writer();

    setup() catch |err| {
        screen.print("ERROR: {s}\n", .{@errorName(err)}) catch {};
    };
    if (uefi.system_table.boot_services) |bs| {
        try screen.writeAll("Returning to UEFI in 5 seconds...\n");
        _ = bs.stall(1000 * 1000 * 5);
    } else {
        try screen.writeAll("Press the power button to restart...\n");
        asm volatile ("HLT");
    }
    return Status.success;
}

fn setup() !void {
    const bs = uefi.system_table.boot_services orelse return error.NoBootService;
    const rs = uefi.system_table.runtime_services;
    var fs: *uefi.protocol.SimpleFileSystem = undefined;
    var root: *const uefi.protocol.File = undefined;
    const path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\EFI\\freestanding.elf");

    var grapics: *GraphicsOutput = undefined;
    try bs.locateProtocol(
        &GraphicsOutput.guid,
        null,
        @ptrCast(&grapics),
    ).err();

    video.init(grapics,0,0);
    const v = video.get();
    const screen = v.writer();

    try screen.writeAll("Locating protocol for SimpleFileSystem\n");
    try bs.locateProtocol(
        &uefi.protocol.SimpleFileSystem.guid,
        null,
        @ptrCast(&fs),
    ).err();

    try screen.writeAll("Opening root volume\n");
    try fs.openVolume(&root).err();

    try screen.print("Opening image\n", .{});
    var program: *const uefi.protocol.File = undefined;
    try root.open(
        &program,
        path,
        uefi.protocol.File.efi_file_mode_read,
        uefi.protocol.File.efi_file_read_only,
    ).err();

    try screen.print("Checking elf magic\n", .{});
    const reader = program.reader();
    if ((try reader.readByte() != 0x7f) or
        (try reader.readByte() != 0x45) or
        (try reader.readByte() != 0x4c) or
        (try reader.readByte() != 0x46))
    {
        return error.InvalidElfMagic;
    }

    try screen.print("Confirming is 64-bit program\n", .{});
    if (try reader.readByte() != std.elf.ELFCLASS64) {
        return error.Not64BitBinary;
    }

    try screen.print("Confirming is LE\n", .{});
    if (try reader.readByte() != std.elf.ELFDATA2LSB) {
        return error.NotLittleEndian;
    }

    try reader.context.setPosition(0).err();

    try screen.print("Reading ELF 64-Bit Header\n", .{});
    const header = try reader.readStruct(std.elf.Elf64_Ehdr);

    try screen.print("Program entry at 0x{X}\n", .{header.e_entry});
    try screen.print("Reading Program Headers\n", .{});

    for (0..header.e_phnum) |_| {
        const Phdr = try reader.readStruct(std.elf.Elf64_Phdr);
        var nextPos: u64 = undefined;
        try reader.context.getPosition(&nextPos).err();
        if (Phdr.p_type != std.elf.PT_LOAD) continue;

        var segBuf: PageAlignedPointer = @ptrFromInt(Phdr.p_paddr);

        const pageCount = efiSizeToPages(Phdr.p_memsz);
        try bs.allocatePages(
            .allocate_address,
            .loader_data,
            pageCount,
            &segBuf,
        ).err();
        try reader.context.setPosition(Phdr.p_offset).err();
        _ = try reader.readAtLeast(segBuf[0..Phdr.p_filesz], Phdr.p_filesz);
        try reader.context.setPosition(nextPos).err();
    }

    try screen.print("Disabling watchdog timer\n", .{});
    try bs.setWatchdogTimer(0, 0, 0, null).err();

    _ = root.close();
    _ = program.close();

    try screen.writeAll("Finding Memory Map\n");
    const m = try mmap.init(bs);

    try screen.writeAll("Exiting boot services\n");
    try bs.exitBootServices(uefi.handle, m.key).err();

    try screen.writeAll("Setting Virtual Address Map\n");
    try rs.setVirtualAddressMap(m.size, m.descSize, m.descVer, m.map).err();

    try screen.writeAll("Exiting UEFI Bootloader\n");
    const entry: *const fn (*GraphicsOutput, *const mmap, *RuntimeServices, x: usize, y: usize) noreturn = @ptrFromInt(header.e_entry);
    entry(grapics, &m, rs, v.cursor.x,v.cursor.y);
}
