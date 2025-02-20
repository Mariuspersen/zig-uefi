const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .os_tag = .uefi,
            .cpu_arch = .x86_64,
            .abi = .msvc,
            .ofmt = .coff,
        },
    });

    const freestandingTarget = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .x86_64,
        .abi = .none,
        .ofmt = .elf,
    });
    const optimize = b.standardOptimizeOption(.{});

    const uefi_exe = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = b.path("src/uefi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const freestanding = b.addExecutable(.{
        .name = "freestanding.elf",
        .root_source_file = b.path("src/freestanding.zig"),
        .target = freestandingTarget,
        .optimize = optimize,
    });

    freestanding.entry = .disabled;
    freestanding.setLinkerScript(b.path("src/freestanding.ld"));

    const freestandingArtifact = b.addInstallArtifact(freestanding,.{
        .dest_dir = .{ .override = .{ .custom = "/EFI" } },
    });
    b.default_step.dependOn(&freestandingArtifact.step);

    const uefiArtifact = b.addInstallArtifact(uefi_exe, .{
        .dest_dir = .{ .override = .{ .custom =  "/EFI/BOOT"} },
    });
    b.default_step.dependOn(&uefiArtifact.step);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-serial",
        "stdio",
        "-vga",
        "std",
        "-bios",
        "/usr/share/OVMF/x64/OVMF.4m.fd",
        "-drive",
        "format=raw,file=fat:rw:zig-out",
    });

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
