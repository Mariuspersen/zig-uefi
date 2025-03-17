const std = @import("std");

const uefiWriter = @import("writer.zig");
const uefiReader = @import("reader.zig");
const mmap = @import("mmap.zig");

const uefi = std.os.uefi;

const Status = uefi.Status;

const SimpleTextInput = uefi.protocol.SimpleTextInput;
const GraphicsOutput = uefi.protocol.GraphicsOutput;
const Input = SimpleTextInput.Key.Input;
const BootServices = uefi.tables.BootServices;

const PageAlignedPointer = [*]align(std.mem.page_size) u8;

const efi_page_mask: usize = 0xfff;
const efi_page_shift: usize = 12;
/// Convert a memory size to memory pages (4096 bytes each)
pub inline fn efiSizeToPages(value: anytype) @TypeOf(value) {
    const addition: @TypeOf(value) = if (value & efi_page_mask != 0) 1 else 0;
    const ret = (value >> efi_page_shift) + addition;
    return ret;
}

pub fn main() Status {
    const bs = uefi.system_table.boot_services orelse return Status.Aborted;
    var uefi_out = uefiWriter.init() catch return Status.Aborted;
    var uefi_in = uefiReader.init() catch return Status.Aborted;

    uefi_out.reset() catch return Status.Aborted;

    const stdout = uefi_out.writer();

    setup() catch |err| {
        stdout.print("ERROR: {s}\r\nPress any key to return...\r\n", .{@errorName(err)}) catch {};
    };
    _ = uefi_in.WaitForKeyPress(bs);
    return Status.Success;
}

fn setup() !void {
    var uefi_out = try uefiWriter.init();
    const stdout = uefi_out.writer();

    const bs = uefi.system_table.boot_services orelse return error.NoBootService;
    //const rs = uefi.system_table.runtime_services;
    var fs: *uefi.protocol.SimpleFileSystem = undefined;
    var root: *const uefi.protocol.File = undefined;
    const path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\EFI\\freestanding.elf");

    var grapics: *GraphicsOutput = undefined;
    try bs.locateProtocol(
        &GraphicsOutput.guid,
        null,
        @ptrCast(&grapics),
    ).err();

    try stdout.writeAll("Locating protocol for SimpleFileSystem\r\n");
    try bs.locateProtocol(
        &uefi.protocol.SimpleFileSystem.guid,
        null,
        @ptrCast(&fs),
    ).err();

    try stdout.writeAll("Opening root volume\r\n");
    try fs.openVolume(&root).err();

    try stdout.print("Opening image\r\n", .{});
    var program: *uefi.protocol.File = undefined;
    try root.open(
        &program,
        path,
        uefi.protocol.File.efi_file_mode_read,
        uefi.protocol.File.efi_file_read_only,
    ).err();

    try stdout.print("Checking elf magic\r\n", .{});
    const reader = program.reader();
    if ((try reader.readByte() != 0x7f) or
        (try reader.readByte() != 0x45) or
        (try reader.readByte() != 0x4c) or
        (try reader.readByte() != 0x46))
    {
        return error.InvalidElfMagic;
    }

    try stdout.print("Confirming is 64-bit program\r\n", .{});
    if (try reader.readByte() != std.elf.ELFCLASS64) {
        return error.Not64BitBinary;
    }

    try stdout.print("Confirming is LE\r\n", .{});
    if (try reader.readByte() != std.elf.ELFDATA2LSB) {
        return error.NotLittleEndian;
    }

    if (.Success != reader.context.setPosition(0)) {
        return error.UnableToSetImagePosition;
    }

    try stdout.print("Reading ELF 64-Bit Header\r\n", .{});
    const header = try reader.readStruct(std.elf.Elf64_Ehdr);

    try stdout.print("program entry at 0x{X}\r\n", .{header.e_entry});
    try stdout.print("Reading Program Headers\r\n", .{});

    for (0..header.e_phnum) |_| {
        const Phdr = try reader.readStruct(std.elf.Elf64_Phdr);
        var nextPos: u64 = undefined;
        try reader.context.getPosition(&nextPos).err();
        if (Phdr.p_type != std.elf.PT_LOAD) continue;

        var segBuf: PageAlignedPointer = @ptrFromInt(Phdr.p_paddr);

        const pageCount = efiSizeToPages(Phdr.p_memsz);
        try bs.allocatePages(
            .AllocateAddress,
            .LoaderData,
            pageCount,
            &segBuf,
        ).err();
        try reader.context.setPosition(Phdr.p_offset).err();
        _ = try reader.readAtLeast(segBuf[0..Phdr.p_filesz], Phdr.p_filesz);

        try reader.context.setPosition(nextPos).err();
    }

    try stdout.print("Disabling watchdog timer\r\n", .{});
    try bs.setWatchdogTimer(
        0,
        0,
        0,
        null,
    ).err();

    _ = root.close();
    _ = program.close();

    try stdout.writeAll("Finding Memory Map\r\n");
    const m = try mmap.init(bs);

    if (.Success != bs.exitBootServices(uefi.handle, m.key)) {
        while (true) {}
    }

    const entry: *const fn (*GraphicsOutput, *const mmap) noreturn = @ptrFromInt(header.e_entry);
    entry(grapics, &m);
}
