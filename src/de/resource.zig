const std = @import("std");
const font = @import("../root.zig");
const Tables = @import("./table.zig");
const Decoder = font.de.Decoder;

/// The type of the open type font format.
pub const Type = enum(u32) {
    /// 0x00010000 | 0x74727565
    TrueType = 0x00010000,
    /// 0x4F54544F
    OpenType = 0x4F54544F,
    /// 0x74746366
    Collection = 0x74746366,
};

/// A record of a tables mapping in the files bytes.
///
/// **Fields**
///
/// - tag: unique identifier of the table
/// - checksum: sum of all uint32 units of the table
/// - offset: byte offset from the beginning of the file/byte array
/// - length: number of bytes that make up the table
pub const TableRecord = struct {
    pub const FONT_DECODE_BYTES = 16;

    tag: [4]u8,
    checksum: u32,
    offset: u32,
    length: u32,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder{ .source = data };

        const tag = try decoder.slice(4);
        return .{ 
            .tag = tag,
            .checksum = try decoder.get(u32),
            .offset = try decoder.get(u32),
            .length = try decoder.get(u32),
        };
    }
};

/// Header information of an Open Type Font file
pub const Resource = struct {
    data: []const u8,
    version: Type,
    num_tables: u16,
    records: font.de.View(TableRecord),

    /// Parse an array of bytes as an open type font file
    pub fn parse(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        const version = @as(Type, @enumFromInt(try decoder.get(u32)));
        const num_tables = try decoder.get(u16);

        try decoder.skip(u16, 3);
        std.debug.assert(decoder.offset == 12);

        return .{
            .data = data,
            .version = version,
            .num_tables = num_tables,
            .records = try decoder.view(TableRecord, num_tables),
        };
    }

    /// Parses the table records returning a structure of known
    /// OTF font tables and their parsed data if they exist.
    pub fn tables(self: *const @This()) !Tables {
        return try Tables.parse(&self.records, self.data);
    }
};

test "parse TableRecord" {
    const de = @import ("../de.zig");

    const source = [_]u8{ 104, 101, 97, 100, 0, 0, 0, 100, 0, 0, 1, 144, 0, 0, 5, 144 };
    var decoder: de.Decoder = .{ .source = &source };

    const record = try decoder.get(TableRecord);
    const expected: TableRecord = .{
        .tag = [4]u8{ 104, 101, 97, 100 },
        .checksum = 100,
        .offset = 400,
        .length = 1424,
    };

    try std.testing.expectEqual(record, expected);
    try std.testing.expectEqual(decoder.offset, 16);
}
