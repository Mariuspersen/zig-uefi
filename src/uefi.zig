const std = @import("std");

const uefiWriter = @import("writer.zig");
const uefiReader = @import("reader.zig");

const uefi = std.os.uefi;

const Status = uefi.Status;

const SimpleTextInput = uefi.protocol.SimpleTextInput;
const Input = SimpleTextInput.Key.Input;
const BootServices = uefi.tables.BootServices;
const allocator = uefi.pool_allocator;

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
        stdout.print("\r\nERROR: {s}\r\nPress any key to return...\r\n", .{@errorName(err)}) catch {};
    };

    _ = uefi_in.WaitForKeyPress(bs);
    return Status.Success;
}

fn setup() !void {
    var uefi_out = try uefiWriter.init();
    const stdout = uefi_out.writer();
    const alloc = uefi.raw_pool_allocator;

    const bs = uefi.system_table.boot_services orelse return error.NoBootService;
    var fs: *uefi.protocol.SimpleFileSystem = undefined;
    var root: *const uefi.protocol.File = undefined;
    const path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\EFI\\freestanding.elf");

    try stdout.writeAll("Locating protocol for SimpleFileSystem\r\n");
    if (.Success != bs.locateProtocol(&uefi.protocol.SimpleFileSystem.guid, null, @ptrCast(&fs))) {
        return error.CouldNotLocateFileSystemProtocol;
    }

    try stdout.writeAll("Opening root volume\r\n");
    if (.Success != fs.openVolume(&root)) {
        return error.CouldNotOpenRootVolume;
    }

    try stdout.print("Opening image\r\n", .{});
    var programFile: *uefi.protocol.File = undefined;
    if (.Success != root.open(
        &programFile,
        path,
        uefi.protocol.File.efi_file_mode_read,
        uefi.protocol.File.efi_file_read_only,
    )) {
        return error.CouldNotOpenProgram;
    }

    try stdout.print("Checking elf magic\r\n", .{});
    const reader = programFile.reader();
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

    try stdout.print("Reading Program Headers\r\n", .{});
    const programHeaders = try alloc.alloc(std.elf.Elf64_Phdr, header.e_phnum);
    defer alloc.free(programHeaders);

    for (programHeaders) |*Phdr| {
        Phdr.* = try reader.readStruct(std.elf.Elf64_Phdr);
    }

    for (programHeaders) |Phdr| {
        if (Phdr.p_type == std.elf.PT_LOAD) {
            var segBuf: [*]align(4096) u8 = @ptrFromInt(Phdr.p_paddr);
            const pageCount = efiSizeToPages(Phdr.p_memsz);
            if (.Success != bs.allocatePages(
                .AllocateAddress,
                .LoaderData,
                pageCount,
                &segBuf,
            )) {
                return error.UnableToAllocateProgramSegmentBuffer;
            }
            if (.Success != reader.context.setPosition(Phdr.p_offset)) {
                return error.UnableToSetImagePosition;
            }
            try stdout.print("{X}\r\n", .{segBuf[0..Phdr.p_filesz]});
        }
    }
    _ = root.close();
    _ = programFile.close();
    const entry: *const fn() void = @ptrFromInt(header.e_entry);
    entry();
}
