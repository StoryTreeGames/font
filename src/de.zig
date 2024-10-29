const std = @import("std");

const resource = @import("de/resource.zig");

pub const Resource = resource.Resource;
pub const TableRecord = resource.TableRecord;
pub const Version = resource.Type;

// TODO: Add more complex errors to better describe what went wrong
const DecodeError = error{
    OutOfBounds,

    NotImplemented,
};

/// A wrapper around an array of bytes to produce zig types and custom user types
/// the map over the bytes.
pub const Decoder = struct {
    offset: usize = 0,
    source: []const u8,

    /// Move the decoder forward or backward depending on the size of the type
    /// and the amount of the specific type to skip.
    pub fn skip(self: *@This(), T: type, count: usize) !void {
        const size = type_byte_size(T);

        const total = size * count;

        if (self.offset + total >= self.source.len) {
            return DecodeError.OutOfBounds;
        }

        self.offset += total;
    }

    /// Move the decoder's position in the underlying bytes forward or backward.
    pub fn seek(self: *@This(), amount: isize) !void {
        const total = @as(isize, @intCast(self.offset)) + amount;
        if (total < 0 or total >= self.source.len) {
            return DecodeError.OutOfBounds;
        }
        self.offset = @as(usize, @intCast(total));
    }

    /// Get a specific type from the underlying bytes.
    ///
    /// Increments and progresses the decoder.
    pub fn get(self: *@This(), T: type) !T {
        const size = type_byte_size(T);
        defer self.offset += size;
        return decode(self.source[self.offset..], T);
    }

    /// Aquire a lazy mapped view into the underlying data.
    ///
    /// Increments and progresses the decoder.
    pub fn array(self: *@This(), T: type, count: usize) !View(T) {
        const size = type_byte_size(T);
        if (self.offset + (size * count) > self.source.len) {
            return DecodeError.OutOfBounds;
        }

        const start = self.offset;
        self.offset += size * count;

        return .{ .data = self.source[start..self.offset], .count = count };
    }

    /// Get a slice of bytes from the underlying data.
    pub fn slice(self: *@This(), comptime count: usize) ![count]u8 {
        if (self.offset + count > self.source.len) {
            return DecodeError.OutOfBounds;
        }

        var result: [count]u8 = [_]u8 { 0 } ** count;
        inline for (0..count) |i| {
            result[i] = self.source[self.offset + i];
        }
        defer self.offset += count;

        return result;
    }
};

/// get the size of a specific type that is able to be decoded.
fn type_byte_size(T: type) usize {
    return switch (T) {
        f32 => type_byte_size(i32),
        u64 => 8,
        u32 => 4,
        i32 => 4,
        u16 => 2,
        i16 => 2,
        u8 => 1,
        i8 => 1,
        else => T.DECODE_SIZE,
    };
}

fn decode(source: []const u8, T: type) !T {
    switch (T) {
        u64 => {
            if (7 >= source.len) {
                return DecodeError.OutOfBounds;
            }
            var result: u64 = 0;
            result |= @as(u64, source[0]) << 56;
            result |= @as(u64, source[1]) << 48;
            result |= @as(u64, source[2]) << 40;
            result |= @as(u64, source[3]) << 32;
            result |= @as(u64, source[4]) << 24;
            result |= @as(u64, source[5]) << 16;
            result |= @as(u64, source[6]) << 8;
            result |= @as(u64, source[7]);
            return result;
        },

        f32 => {
            return @as(f32, @floatFromInt(try decode(i32))) / 65536.0;
        },

        u32 => {
            if (3 >= source.len) {
                return DecodeError.OutOfBounds;
            }
            var result: u32 = 0;
            result |= @as(u32, source[0]) << 24;
            result |= @as(u32, source[1]) << 16;
            result |= @as(u32, source[2]) << 8;
            result |= @as(u32, source[3]);
            return result;
        },
        i32 => {
            if (3 >= source.len) {
                return DecodeError.OutOfBounds;
            }
            var result: i32 = 0;
            result |= @as(i32, source[0]) << 24;
            result |= @as(i32, source[1]) << 16;
            result |= @as(i32, source[2]) << 8;
            result |= @as(i32, source[3]);
            return result;
        },

        u16 => {
            if (1 >= source.len) {
                return DecodeError.OutOfBounds;
            }
            var result: u16 = 0;
            result |= @as(u16, source[0]) << 8;
            result |= @as(u16, source[1]);
            return result;
        },
        i16 => {
            if (1 >= source.len) {
                return DecodeError.OutOfBounds;
            }
            var result: i16 = 0;
            result |= @as(i16, source[0]) << 8;
            result |= @as(i16, source[1]);
            return result;
        },

        u8 => {
            if (0 == source.len) {
                return DecodeError.OutOfBounds;
            }
            return source[0];
        },
        i8 => {
            if (0 == source.len) {
                return DecodeError.OutOfBounds;
            }
            return @as(i8, source[0]);
        },

        else => {
            const size: usize = T.DECODE_SIZE;
            if (size - 1 >= source.len) {
                return DecodeError.OutOfBounds;
            }

            const data = source[0 .. size];
            return T.decode(data);
        },
    }
}

/// A lazy mapping of an array where the type if mapped onto an underlying array of bytes.
pub fn View(T: type) type {
    return struct {
        data: []const u8,
        count: usize,

        /// Get a specific index from the array.
        pub fn get(self: *const @This(), index: usize) !?T {
            const size = type_byte_size(T);
            if (size * index >= self.data.len) {
                return null;
            }

            if (decode(self.data[size * index .. (size * index) + size], T)) |v| {
                return v;
            } else |e| {
                return e;
            }
        }

        /// Length of the array as the mapped type.
        pub fn len(self: *const @This()) usize {
            return @divFloor(self.data.len, type_byte_size(T));
        }

        /// Check if the array of the mapped type is empty.
        pub fn is_empty(self: *const @This()) bool {
            return self.len() == 0;
        }

        pub fn iter(self: *const @This()) ViewIter(T) {
            return .{ .context = self };
        }
    };
}

/// Iterator over the values in a `View`
pub fn ViewIter(T: type) type {
    return struct {
        index: usize = 0,
        context: *const View(T),

        pub fn next(self: *@This()) !?T {
            if (self.index + 1 >= self.context.len()) {
                return null;
            }

            defer self.index += 1;
            return self.context.get(self.index);
        }
    };
}

test "parse" {
    const source = [_]u8{ 0, 0, 1, 144, 104, 101, 97, 100, 0, 0, 1, 144, 0, 0, 1, 144 };
    var decoder: Decoder = .{ .source = &source };

    const number = decoder.get(u32) catch unreachable;
    try std.testing.expectEqual(number, 400);
    try std.testing.expectEqual(decoder.offset, 4);

    const tag = try decoder.slice(4);
    try std.testing.expectEqualSlices(u8, &tag, &[4]u8{104, 101, 97, 100});
    try std.testing.expectEqual(decoder.offset, 8);

    const numbers = try decoder.array(u32, 2);
    try std.testing.expectEqual(numbers.len(), 2);
    try std.testing.expectEqual(numbers.is_empty(), false);
    try std.testing.expectEqual(try numbers.get(0), 400);
    try std.testing.expectEqual(try numbers.get(1), 400);
}
