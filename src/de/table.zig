const std = @import("std");
const de = @import("../de.zig");
const resource = @import("./resource.zig");

const View = de.View;
const TableRecord = resource.TableRecord;

pub const HeadTable = @import("table/head.zig");
pub const CmapTable = @import("table/cmap.zig");

head: HeadTable,
cmap: CmapTable,

const RawTableHead = enum {
    head,
    cmap
};

const RawTables = struct {
    head: ?[]const u8 = null,
    cmap: ?[]const u8 = null,

    pub fn parse(records: *const View(TableRecord), buffer: []const u8) !@This() {
        var tables = @This(){};

        var iter = records.iter();
        while (try iter.next()) |record| {
            if (std.meta.stringToEnum(RawTableHead, &record.tag)) |tag| {
                switch (tag) {
                    .head => tables.head = buffer[record.offset..record.offset+record.length],
                    .cmap => tables.cmap = buffer[record.offset..record.offset+record.length],
                }
            }
        }

        return tables;
    }
};


pub fn parse(records: *const View(TableRecord), data: []const u8) !@This() {
    const raw = try RawTables.parse(records, data);

    return .{
        .head = try HeadTable.parse(raw.head.?),
        .cmap = try CmapTable.parse(raw.cmap.?),
    };
}
