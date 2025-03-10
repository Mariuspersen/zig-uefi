const std = @import("std");
const Self = @This();

//lat0-08.psf from console-data package of Debian
const lat0 = @embedFile("lat0-08.psf");
const default8x16 = @embedFile("default8x16.psf");

const Header = union(enum) {
    psf1: PSF1_Header,
    psf2: PSF2_Header,

    pub fn init(reader: anytype) !Header {
        const temp = try reader.readStruct(PSF1_Header);
        if (temp.magic == PSF1_Header.MAGIC) {
            return .{
                .psf1 = temp,
            };
        }

        reader.context.pos = 0;

        const temp2 = try reader.readStruct(PSF2_Header);
        if (temp2.magic == PSF2_Header.MAGIC) {
            return .{
                .psf2 = temp2,
            };
        }
        return error.NotRecognizedHeader;
    }
};

const Mode = packed struct {
    MODE512: bool,
    MODEHASTAB: bool,
    MODESEQ: bool,
    unused: u5,
};

pub const PSF1_Header = packed struct {
    const STARTSEQ = &[_]u8{ 0xFE, 0xFF };
    const SEPARATOR = &[_]u8{ 0xFF, 0xFF };
    const MAGIC = 0x0436;
    pub const WIDTH = 8;
    magic: u16,
    mode: Mode,
    height: u8,
};

const PSF2_Header = packed struct {
    const HAS_UNICODE_TABLE = 0x01;
    const MAXVERSION = 0;
    const SEPARATOR = 0xFF;
    const STARTSEQ = 0xFE;
    const MAGIC = 0x864ab572;
    magic: u32,
    version: u32,
    headersize: u32,
    flags: u32,
    length: u32,
    charsize: u32,
    height: u32,
    width: u32,
};

header: Header,
glyphs: []const u8,
glyphCount: usize,

pub fn init() !Self {
    var fbs = std.io.fixedBufferStream(default8x16);
    const reader = fbs.reader();
    const header = try Header.init(reader);

    return .{
        .header = header,
        .glyphs = default8x16[fbs.pos..],
        .glyphCount = switch (header) {
            .psf1 => |p1| if (p1.mode.MODE512) 512 else 256,
            .psf2 => |p2| p2.length
        }
    };
}

pub fn getHeight(self: *const Self) @TypeOf(switch (self.header) {
    .psf1 => |a| a.height,
    .psf2 => |b| b.height,
}) {
    return switch (self.header) {
        .psf1 => |a| a.height,
        .psf2 => |b| b.height,
    };
}

pub fn getWidth(self: *const Self) @TypeOf(switch (self.header) {
        .psf1 => PSF1_Header.WIDTH,
        .psf2 => |b| b.width,
    }) {
    return switch (self.header) {
        .psf1 => PSF1_Header.WIDTH,
        .psf2 => |b| b.width,
    };
}

pub fn getChar(self: *const Self, index: usize) []const u8 {
    const width = self.getWidth();
    const height = self.getHeight();
    const start = index * height * width / 8;
    const end = start + height * width / 8;
    return self.glyphs[start..end];
}
