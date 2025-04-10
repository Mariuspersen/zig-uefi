const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .os_tag = .uefi,
            .cpu_arch = .x86_64,
            .abi = .msvc,
        },
    });

    const freestandingTarget = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .x86_64,
        .abi = .eabi,
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

    //freestanding.entry = .disabled;
    freestanding.setLinkerScript(b.path("src/freestanding.ld"));

    const freestandingArtifact = b.addInstallArtifact(freestanding, .{
        .dest_dir = .{ .override = .{ .custom = "/EFI" } },
    });
    b.default_step.dependOn(&freestandingArtifact.step);

    const uefiArtifact = b.addInstallArtifact(uefi_exe, .{
        .dest_dir = .{ .override = .{ .custom = "/EFI/BOOT" } },
    });
    b.default_step.dependOn(&uefiArtifact.step);

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-device",
        "pci-testdev",
        "-serial",
        "stdio",
        "-vga",
        "std",
        "-bios",
        // TODO: Figure out why OVMF.fd.4m on Arch Linux returns wrong 
        // Memory description tables...
        "OVMF.fd",
        "-drive",
        "format=raw,file=fat:rw:zig-out",
        "-S",
        "-s",
    });
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
