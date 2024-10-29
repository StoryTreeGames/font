const std = @import("std");

/// Helper to read a files bytes into a byte array.
///
/// The returned byte array must be freed by the caller.
pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const real_path = try std.fs.realpathAlloc(allocator, path);

    const file = try std.fs.openFileAbsolute(real_path, .{ });
    defer file.close();

    const size = (try file.stat()).size;

    const buffer = try allocator.alloc(u8, size);

    const read = try file.readAll(buffer);
    std.debug.assert(read == size);

    return buffer;
}
