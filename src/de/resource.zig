const font = @import("root.zig");
const Decoder = font.de.Decoder;

pub const Version = enum(u32) {
    /// 0x00010000 | 0x74727565
    TrueType = 0x00010000,
    /// 0x4F54544F
    OpenType = 0x4F54544F,
    /// 0x74746366
    Collection = 0x74746366,
};

pub const TableRecord = struct {
    pub const DECODE_SIZE = 16;

    tag: [4]u8,
    checksum: u32,
    offset: u32,
    length: u32,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder{ .source = data };

        return .{ 
            .tag = try decoder.slice(4),
            .checksum = try decoder.get(u32),
            .offset = try decoder.get(u32),
            .length = try decoder.get(u32),
        };
    }
};

pub const Resource = struct {
    version: Version,
    num_tables: u16,
    records: font.de.View(TableRecord),

    pub fn parse(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        const version = @as(Version, @enumFromInt(try decoder.get(u32)));
        const num_tables = try decoder.get(u16);

        try decoder.skip(u16, 3);

        return .{
            .version = version,
            .num_tables = num_tables,
            .records = try decoder.array(TableRecord, num_tables),
        };
    }
};
