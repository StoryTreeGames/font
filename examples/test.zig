const std = @import("std");

const font = @import("font");

pub fn main() void {
    std.debug.print("Hello, world! {d}", .{font.add(1, 3)});
}
