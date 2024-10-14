const std = @import("std");

const resource = @import("de/resource.zig");

pub const Resource = resource.Resource;
pub const TableRecord = resource.TableRecord;
pub const Version = resource.Version;

// TODO: Add more complex errors to better describe what went wrong
const DecodeError = error{
    OutOfBounds,

    NotImplemented,
};

pub const Decoder = struct {
    offset: usize = 0,
    source: []const u8,

    pub fn skip(self: *@This(), T: type, count: usize) !void {
        const size = type_byte_size(T);

        const total = size * count;

        if (self.offset + (total - 1) >= self.source.len) {
            return DecodeError.OutOfBounds;
        }

        self.offset += size;
    }

    pub fn seek(self: *@This(), amount: isize) !void {
        const total = @as(isize, @intCast(self.offset)) + amount;
        if (total < 0 or total >= self.source.len) {
            return DecodeError.OutOfBounds;
        }
        self.offset = @as(usize, @intCast(total));
    }

    pub fn get(self: *@This(), T: type) !T {
        switch (T) {
            u64 => {
                if (self.offset + 7 >= self.source.len) {
                    return DecodeError.OutOfBounds;
                }
                var result: u64 = 0;
                result |= @as(u64, self.source[self.offset]) << 56;
                result |= @as(u64, self.source[self.offset + 1]) << 48;
                result |= @as(u64, self.source[self.offset + 2]) << 40;
                result |= @as(u64, self.source[self.offset + 3]) << 32;
                result |= @as(u64, self.source[self.offset + 4]) << 24;
                result |= @as(u64, self.source[self.offset + 5]) << 16;
                result |= @as(u64, self.source[self.offset + 6]) << 8;
                result |= @as(u64, self.source[self.offset + 7]);
                self.offset += 8;
                return result;
            },

            f32 => {
                return @as(f32, @floatFromInt(try self.get(i32))) / 65536.0;
            },

            u32 => {
                if (self.offset + 3 >= self.source.len) {
                    return DecodeError.OutOfBounds;
                }
                var result: u32 = 0;
                result |= @as(u32, self.source[self.offset]) << 24;
                result |= @as(u32, self.source[self.offset + 1]) << 16;
                result |= @as(u32, self.source[self.offset + 2]) << 8;
                result |= @as(u32, self.source[self.offset + 3]);
                self.offset += 4;
                return result;
            },
            i32 => {
                if (self.offset + 3 >= self.source.len) {
                    return DecodeError.OutOfBounds;
                }
                var result: i32 = 0;
                result |= @as(i32, self.source[self.offset]) << 24;
                result |= @as(i32, self.source[self.offset + 1]) << 16;
                result |= @as(i32, self.source[self.offset + 2]) << 8;
                result |= @as(i32, self.source[self.offset + 3]);
                self.offset += 4;
                return result;
            },

            u16 => {
                if (self.offset + 1 >= self.source.len) {
                    return DecodeError.OutOfBounds;
                }
                var result: u16 = 0;
                result |= @as(u16, self.source[self.offset]) << 8;
                result |= @as(u16, self.source[self.offset + 1]);
                self.offset += 2;
                return result;
            },
            i16 => {
                if (self.offset + 1 >= self.source.len) {
                    return DecodeError.OutOfBounds;
                }
                var result: i16 = 0;
                result |= @as(i16, self.source[self.offset]) << 8;
                result |= @as(i16, self.source[self.offset + 1]);
                self.offset += 2;
                return result;
            },

            u8 => {
                if (self.offset >= self.source.len) {
                    return DecodeError.OutOfBounds;
                }
                defer self.offset += 1;
                return self.source[self.offset];
            },
            i8 => {
                if (self.offset >= self.source.len) {
                    return DecodeError.OutOfBounds;
                }
                defer self.offset += 1;
                return @as(i8, self.source[self.offset]);
            },

            else => {
                const size: usize = T.DECODE_SIZE;
                if (self.offset + (size - 1) >= self.source.len) {
                    return DecodeError.OutOfBounds;
                }

                const data = self.source[self.offset .. self.offset + size];
                self.offset += size;
                return T.decode(data);
            },
        }
    }

    pub fn array(self: *@This(), T: type, count: usize) !View(T) {
        const size = type_byte_size(T);
        if (self.offset + (size * count) > self.source.len) {
            return DecodeError.OutOfBounds;
        }

        const start = self.offset;
        self.offset += size * count;

        return .{ .data = self.source, .count = count, .start = start };
    }

    pub fn slice(self: *@This(), comptime count: usize) ![4]u8 {
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

pub fn View(T: type) type {
    return struct {
        data: []const u8,
        count: usize,
        start: usize,

        pub fn get(self: *const @This(), comptime index: usize) !?T {
            const size = type_byte_size(T);
            const byte_length = size * self.count;
            if (self.start + (size * index) >= self.start + byte_length) {
                return null;
            }

            if (T.decode(self.data[self.start + (size * index) .. self.start + (size * index) + size])) |v| {
                return v;
            } else |e| {
                return e;
            }
        }

        pub fn len(self: *const @This()) usize {
            return type_byte_size(T) * self.count;
        }

        pub fn is_empty(self: *const @This()) bool {
            return self.len() == 0;
        }
    };
}
