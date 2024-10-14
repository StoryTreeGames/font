const std = @import("std");

pub const de = @import("de.zig");

test "root" {
    std.testing.refAllDeclsRecursive(@This());
}
