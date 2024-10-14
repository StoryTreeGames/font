const std = @import("std");

const font = @import("font");
const Decoder = font.de.Decoder;
const Resource = font.de.Resource;

const font_file: []const u8 = "assets/Roboto/Roboto-Regular.ttf";

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    // Load font file into memory
    var file = try std.fs.cwd().openFile(font_file, .{});
    defer file.close();

    const size = (try file.stat()).size;

    const buffer = try alloc.alloc(u8, size);
    defer alloc.free(buffer);

    const read = try file.readAll(buffer);
    std.debug.assert(read == size);

    // Parse font resource
    const resource = try Resource.parse(buffer);

    std.debug.print("{any}\n", .{ resource.version });
    std.debug.print("{any}\n", .{ try resource.records.get(0) });
}
