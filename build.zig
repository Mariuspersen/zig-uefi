const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .os_tag = .uefi,
            .cpu_arch = .x86_64,
            .abi = .gnu,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    const uefi_exe = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = b.path("src/uefi.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.exe_dir = "zig-out/EFI/BOOT/";
    b.default_step.dependOn(&uefi_exe.step);

    const install_step = b.addInstallArtifact(uefi_exe, .{
        .dest_dir = .{ .override = .bin },
    });

    const run_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-serial",
        "stdio",
        "-bios",
        "/usr/share/OVMF/x64/OVMF.fd",
        "-drive",
        "format=raw,file=fat:rw:zig-out",
    });
    run_cmd.step.dependOn(&install_step.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
