//lat0-08.psf from console-data package of Debian

pub const lat0 = @embedFile("lat0-08.psf");

pub const PSF1_FONT_MAGIC = 0x0436;

pub const Mode = enum(u8) {
    PSF1_MODE512 = 0x01,
    PSF1_MODEHASTAB = 0x2,
    PSF1_MODESEQ = 0x4,
};

pub const PSF1_Header = packed struct {
    magic: u16, // Magic bytes for identification.
    font: Mode, // PSF font mode.
    characterSize: u8, // PSF character size.
};

pub const PSF_FONT_MAGIC = 0x864ab572;

pub const PSF_font = packed struct {
    magic: u32,
    version: u32,
    headersize: u32,
    flags: u32,
    numglyph: u32,
    bytesperglyph: u32,
    height: u32,
    width: u32,
};


