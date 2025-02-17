const de = @import("../../de.zig");
const Decoder = de.Decoder;
const View = de.View;

version: u16,
records: View(EncodingRecord),

data: []const u8,

pub fn parse(buffer: []const u8) !@This() {
    var decoder = Decoder { .source = buffer };

    const version = try decoder.get(u16);
    const numTables = try decoder.get(u16);

    return .{
        .version = version,
        .records = try decoder.view(EncodingRecord, numTables),
        .data = buffer,
    };
}

pub fn get(self: *const @This(), index: usize) !?Subtable {
    const record = try self.records.get(index);
    if (record) |r| return try self.subtable(&r);
    return null;
}

pub fn subtable(self: *const @This(), record: *const EncodingRecord) !Subtable {
    return try Subtable.decode(self.data[record.offset..]);
}

pub const EncodingRecord = struct {
    pub const FONT_DECODE_BYTES = 8;

    platform: PlatformId,
    encoding: u16,
    offset: u32,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };
        return .{
            .platform = @enumFromInt(try decoder.get(u16)),
            .encoding = try decoder.get(u16),
            .offset = try decoder.get(u32),
        };
    }
};

pub const PlatformId = enum(u16) {
    Unicode = 0,
    Macintosh = 1,
    /// Deprecated
    ISO = 2,
    Windows = 3,
    Custom = 4
};

pub const Subtable = union(enum) {
    format0: Format0,
    format2: Format2,
    format4: Format4,
    format6: Format6,
    format8: Format8,
    format10: Format10,
    format12: Format12,
    format13: Format13,
    format14: Format14,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        const format = try decoder.get(u16);
        return switch(format) {
            0 => .{ .format0 = try Format0.decode(data)  },
            2 => .{ .format2 = try Format2.decode(data)  },
            4 => .{ .format4 = try Format4.decode(data)  },
            6 => .{ .format6 = try Format6.decode(data)  },
            8 => .{ .format8 = try Format8.decode(data)  },
            10 => .{ .format10 = try Format10.decode(data)  },
            12 => .{ .format12 = try Format12.decode(data)  },
            13 => .{ .format13 = try Format13.decode(data)  },
            14 => .{ .format14 = try Format14.decode(data)  },
            else => return error.InvalidSubtableFormat
        };
    }
};

pub const Format0 = struct {
    glyphIds: [256]u8,

    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format, length, and language
        try decoder.skip(u16, 3);

        return .{
            .glyphIds = try decoder.slice(256),
            .data = data,
        };
    }
};

pub const Format2 = struct {
    /// Maps high byts into subHeaders. Value is subHeaders index * 8
    subHeaderKeys: [256]u16,
    /// Collection of SubHeader records
    subHeaders: View(SubHeaderRecord),

    /// Location in the raw bytes where the sub headers start
    subHeaderOffset: usize,
    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format, length, and language
        try decoder.skip(u16, 3);

        const keys = try decoder.array(u16, 256);

        // The max index in subHeaderKeys is the number of SubHeaders
        var max_index: u16 = 0;
        for (keys) |key| {
            const v: u16 = @divFloor(key, 8);
            if (v > max_index) max_index = v;
        }
        max_index += 1;

        return .{
            .data = data,
            .subHeaderOffset = decoder.offset,
            .subHeaderKeys = keys,
            .subHeaders = try decoder.view(SubHeaderRecord, max_index),
        };
    }
};

pub const SubHeaderRecord = struct {
    pub const FONT_DECODE_BYTES = 8;

    /// First valid low byte for this SubHeader.
    firstCode: u16,
    /// Number of valid low bytes for this SubHeader.
    entryCount: u16,
    idDelta: i16,
    idRangeOffset: u16,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };
        return .{
            .firstCode = try decoder.get(u16),
            .entryCode = try decoder.get(u16),
            .idDelta = try decoder.get(i16),
            .idRangeOffset = try decoder.get(u16),
        };
    }
};

pub const Format4 = struct {
    segCount: u16,

    /// End characterCode for each segment, last=0xFFFF.
    endCode: View(u16),
    /// Start character code for each segment.
    startCode: View(u16),
    /// Delta for all character codes in segment.
    idDelta: View(u16),
    /// Offsets into glyphIdArray or 0
    idRangeOffset: View(u16),

    idRangeOffsetPos: usize,

    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format, length, and language
        try decoder.skip(u16, 3);

        const segCount = @divFloor(try decoder.get(u16), 2);

        // searchRange, entrySelector, rangeShift
        try decoder.skip(u16, 3);

        const endCode = try decoder.view(u16, segCount);

        // Reserved Padding
        try decoder.skip(u16, 1);

        return .{
            .data = data,
            .segCount = segCount,
            .endCode = endCode,
            .startCode = try decoder.view(u16, segCount),
            .idDelta = try decoder.view(u16, segCount),
            .idRangeOffsetPos = decoder.offset,
            .idRangeOffset = try decoder.view(u16, segCount),
        };
    }
};

pub const Format6 = struct {
    firstCode: u16,
    glyphIds: View(u16),

    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format, length, and language
        try decoder.skip(u16, 3);

        const firstCode = try decoder.get(u16);
        const count = try decoder.get(u16);

        return .{
            .data = data,
            .firstCode = firstCode,
            .glyphIds = try decoder.view(u16, count)
        };
    }
};

pub const Format8 = struct {
    is32: [8192]u8,
    groups: View(SequentialMapGroup),

    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format, reserved
        try decoder.skip(u16, 2);
        // length, and language
        try decoder.skip(u32, 2);

        const is32 = try decoder.slice(8192);
        const numGroups = try decoder.get(u32);

        return .{
            .data = data,
            .is32 = is32,
            .groups = try decoder.view(SequentialMapGroup, numGroups),
        };
    }
};

pub const SequentialMapGroup = struct {
    pub const FONT_DECODE_BYTES = 12;

    /// First character code in this group; note that if this group is for one or more 16-bit
    /// character codes (which is determined from the is32 array), this 32-bit value will have
    /// the high 16-bits set to zero
    startCharCode: u32,
    /// Last character code in this group; same condition as listed above for the startCharCode
    endCharCode: u32,
    /// Glyph index corresponding to the starting character code
    startGlyphId: u32,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };
        return .{
            .startCharCode = try decoder.get(u32),
            .endCharCode = try decoder.get(u32),
            .startGlyphId = try decoder.get(u32),
        };
    }
};

pub const Format10 = struct {
    startCharCode: u32,
    glyphIds: View(u16),

    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format, reserved
        try decoder.skip(u16, 2);
        // Skip length, language
        try decoder.skip(u32, 2);

        const startCharCode = try decoder.get(u32);
        const count = try decoder.get(u32);

        return .{
            .data = data,
            .startCharCode = startCharCode,
            .glyphIds = try decoder.view(u16, count)
        };
    }
};

pub const Format12 = struct {
    groups: View(SequentialMapGroup),

    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format, reserved
        try decoder.skip(u16, 2);
        // Skip length, language
        try decoder.skip(u32, 2);

        const count = try decoder.get(u32);

        return .{
            .data = data,
            .groups = try decoder.view(SequentialMapGroup, count)
        };
    }
};

pub const Format13 = struct {
    groups: View(ConstantMapGroup),

    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format, reserved
        try decoder.skip(u16, 2);
        // Skip length, language
        try decoder.skip(u32, 2);

        const count = try decoder.get(u32);

        return .{
            .data = data,
            .groups = try decoder.view(ConstantMapGroup, count)
        };
    }
};

pub const ConstantMapGroup = struct {
    pub const FONT_DECODE_BYTES = 12;

    /// First character code in this group
    startCharCode: u32,
    /// Last character code in this group
    endCharCode: u32,
    /// Glyph index to be used for all the characters in the group’s range
    glyphId: u32,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };
        return .{
            .startCharCode = try decoder.get(u32),
            .endCharCode = try decoder.get(u32),
            .glyphId = try decoder.get(u32),
        };
    }
};

pub const Format14 = struct {
    variationSelectors: View(VariationSelector),

    /// Entire table data
    data: []const u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        // Skip format
        try decoder.skip(u16, 1);
        // Skip length
        try decoder.skip(u32, 1);

        const count = try decoder.get(u32);

        return .{
            .data = data,
            .variationSelectors = try decoder.view(VariationSelector, count)
        };
    }
};

pub const VariationSelector = struct {
    pub const FONT_DECODE_BYTES = 11;

    /// Variation selector
    varSelector: u24,
    /// Offset from the start of the format 14 subtable to Default UVS table. May be 0.
    defaultUVSOffset: u32,
    /// Offset from the start of the format 14 subtable to Non-Default UVS table. May be 0.
    nonDefaultUVSOffset: u32,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };
        return .{
            .varSelector = try decoder.get(u24),
            .defaultUVSOffset = try decoder.get(u32),
            .nonDefaultUVSOffset = try decoder.get(u32),
        };
    }
};

pub const DefaultUVS = struct {
    ranges: View(UnicodeRange),

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        const count = try decoder.get(u32);
        return .{
            .ranges = try decoder.view(UnicodeRange, count),
        };
    }
};

pub const NonDefaultUVS = struct {
    uvsMappings: View(UVSMapping),

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };

        const count = try decoder.get(u32);
        return .{
            .uvsMappings = try decoder.view(UVSMapping, count),
        };
    }
};

pub const UnicodeRange = struct {
    pub const FONT_DECODE_BYTES = 4;

    /// First value in the range
    startUnicodeValue: u24,
    /// Number of additional values in this range
    additionalCount: u8,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };
        return .{
            .startUnicodeValue = try decoder.get(u24),
            .additionalCount = try decoder.get(u8),
        };
    }
};

pub const UVSMapping = struct {
    pub const FONT_DECODE_BYTES = 5;

    /// Base unicode value of the UVS
    unicodeValue: u24,
    /// Glyph id of the UVS
    glyphId: u16,

    pub fn decode(data: []const u8) !@This() {
        var decoder = Decoder { .source = data };
        return .{
            .unicodeValue = try decoder.get(u24),
            .glyphId = try decoder.get(u16),
        };
    }
};
