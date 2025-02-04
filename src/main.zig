const std = @import("std");
const App = @import("App.zig");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var app = try App.init(gpa, .{});
    defer app.deinit();
    app.run();
}

test "all" {
    _ = @import("App.zig");
}
