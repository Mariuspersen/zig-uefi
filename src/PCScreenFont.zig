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
    b1: bool,
    b2: bool,
    b3: bool,
    b4: bool,
    b5: bool,
    MODESEQ: bool,
    MODEHASTAB: bool,
    MODE512: bool,
};

pub const PSF1_Header = packed struct {
    const STARTSEQ = &[_]u8{ 0xFE, 0xFF };
    const SEPARATOR = &[_]u8{ 0xFF, 0xFF };
    const MAGIC = 0x0436;
    pub const WIDTH = 8;
    magic: u16,
    font: Mode,
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
glyphCount: usize = 256,

pub fn init() !Self {
    var fbs = std.io.fixedBufferStream(default8x16);
    const reader = fbs.reader();
    const header = try Header.init(reader);

    return .{
        .header = header,
        .glyphs = default8x16[fbs.pos..],
    };
}
