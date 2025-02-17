const std = @import("std");

const font = @import("font");
const Decoder = font.de.Decoder;
const Resource = font.de.Resource;

const print = std.debug.print;

const font_file: []const u8 = "assets/Roboto/Roboto-Regular.ttf";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const buffer = try font.util.readFile(alloc, font_file);
    defer alloc.free(buffer);

    // Parse font resource
    const resource = try Resource.parse(buffer);

    print("{any}\n", .{ resource.version });
    // print("{any}\n", .{ try resource.records.get(0) });
    //
    // var records = resource.records.iter();
    // while (try records.next()) |record| {
    //     print("{s}\n", .{ record.tag });
    // }

    const cmap = (try resource.tables()).cmap;
    print("{any}\n", .{cmap});
    print("{any}\n", .{ cmap.get(0) });
}
