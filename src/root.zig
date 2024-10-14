const std = @import("std");

test "root" {
    std.testing.refAllDeclsRecursive(@This());
}
