const std = @import("std");
const Self = @This();

//lat0-08.psf from console-data package of Debian
const lat0 = @embedFile("lat0-08.psf");

const Header = union(enum) {
    psf1: PSF1_Header,
    psf2: PSF2_Header,

    pub fn init(reader: anytype) !Header {
        const temp = try reader.readStruct(PSF1_Header);
        if (temp.magic == PSF1_HEADER_MAGIC) {
            return .{
                .psf1 = temp,
            };
        }

        reader.context.pos = 0;

        const temp2 = try reader.readStruct(PSF2_Header);
        if (temp2.magic == PSF2_HEADER_MAGIC) {
            return .{
                .psf2 = temp2,
            };
        }
        return error.NotRecognizedHeader;
    }
};

const Mode = enum(u8) {
    PSF1_MODE512 = 0x01,
    PSF1_MODEHASTAB = 0x2,
    PSF1_MODESEQ = 0x4,
};

const PSF1_STARTSEQ = &[_]u8{0xFE, 0xFF};
const PSF1_SEPARATOR = &[_]u8{0xFF,0xFF};
const PSF1_HEADER_MAGIC = 0x0436;
const PSF1_Header = packed struct {
    magic: u16,
    font: Mode,
    charsize: u8,
};


const PSF2_HAS_UNICODE_TABLE = 0x01;
const PSF2_MAXVERSION = 0;
const PSF2_SEPARATOR = 0xFF;
const PSF2_STARTSEQ = 0xFE;
const PSF2_HEADER_MAGIC = 0x864ab572;
const PSF2_Header = packed struct {
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

pub fn init() !Self {
    var fbs = std.io.fixedBufferStream(lat0);
    const reader = fbs.reader();
    const header = try Header.init(reader);



    return .{
        .header = header,
        .glyphs = lat0[fbs.pos..],
    };
}
