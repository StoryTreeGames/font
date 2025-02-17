const de = @import("../../de.zig");
const MacStyle = de.MacStyle;
const LocFormat = de.LocFormat;
const Decoder = de.Decoder;

majorVersion: u16,
minorVersion: u16,
fontRevision: f32,
/// To compute: set to 0, sum the entire font as u32, then store 0xB1B0AFBA - sum
checksumAdjustment: u32,
/// Set to 0x5F0F3CF5
magicNumber: u32,
flags: Flags,
/// Set to a value from 16 to 16384. Any value in this range is valid.
///
/// In TrueType outlines a power of 2 is recommended as this allows performance optimization
/// in some rasterizers.
unitsPerEm: u16,
/// Number of seconds since Jan 1, 1904 24:00
created: u64,
/// Number of seconds since Jan 1, 1904 24:00
modified: u64,
/// Minimum x coordinate across all glyph bounding boxes
xMin: i16,
/// Maximum x coordinate across all glyph bounding boxes
xMax: i16,
/// Minimum y coordinate across all glyph bounding boxes
yMin: i16,
/// Maximum y coordinate across all glyph bounding boxes
yMax: i16,
macStyle: MacStyle,
/// Smallest readable size in pixels
lowestRecPPEM: u16,
/// Deprecated: Always set to 2
///
/// 0: Fully mixed directional glyphs
/// 1: Only strongly left to right
/// 2: Like 1 but also contains neutrals
/// -1: Only strongly right to left
/// -2: Like -1 but also contains neutrals
fontDirectionHint: i16,
/// Short - Offset16, Long - Offset32
indexToLocFormat: LocFormat,
/// 0 For current format
glyphDataFormat: i16,

pub fn parse(buffer: []const u8) !@This() {
    var decoder = Decoder { .source = buffer };

    return .{
        .majorVersion = try decoder.get(u16),
        .minorVersion = try decoder.get(u16),
        .fontRevision = try decoder.get(f32),
        .checksumAdjustment = try decoder.get(u32),
        .magicNumber = try decoder.get(u32),
        .flags = @bitCast(try decoder.get(u16)),
        .unitsPerEm = try decoder.get(u16),
        .created = try decoder.get(u64),
        .modified = try decoder.get(u64),
        .xMin = try decoder.get(i16),
        .xMax = try decoder.get(i16),
        .yMin = try decoder.get(i16),
        .yMax = try decoder.get(i16),
        .macStyle = @bitCast(try decoder.get(u16)),
        .lowestRecPPEM = try decoder.get(u16),
        .fontDirectionHint = try decoder.get(i16),
        .indexToLocFormat = @enumFromInt(try decoder.get(i16)),
        .glyphDataFormat = try decoder.get(i16),
    };
}

pub const Flags = packed struct(u16) {
    /// Baseline for font at y=0
    Baseline: bool = false,
    /// Left sidebearing point at x=0 (Only relevant for TrueType rasterizers)
    LeftSidebearing: bool = false,
    /// Instructions may depend on point size
    PointSizeDependent: bool = false,
    /// Force ppem to integer values for all internal scaler math. If false,
    /// may use fractional ppem.
    ///
    /// It is strongly recommended that this be set in hinted fonts
    ForcePPEMToInteger: bool = false,
    /// Instructions may alter adnvance width (the advance  widths might not scale linearly)
    AlterAdvanceWidth: bool = false,
    /// Reserved
    _5_10: u6 = 0,
    /// Font data is "lossless" as a result of having been subjected to optimizing
    /// transformations and/or compression
    Lossless: bool = false,
    /// Font converted (produce compatible metrics)
    Converted: bool = false,
    /// Font optimized for ClearType.
    ///
    /// Note: fonts that rely on embedded bitmaps (EBDT) for rendering should not be 
    /// considered optimized for ClearType.
    ClearTypeOptimized: bool = false,
    /// If set, indicates that the glyphs encoded in "cmap" subtables are simply
    /// generic symbolic representations of code point ranges and do not truly
    /// represent support for those code points.
    ///
    /// If unset, indicates that the glyphs encoded in the "cmap" subtables represent
    /// proper support for those code points
    LastResortFont: bool = false,
    /// Reserved
    _16: u1 = 0,
};
