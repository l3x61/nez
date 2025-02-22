const std = @import("std");
const App = @import("App.zig");
const Ansi = @import("utils/Ansi.zig");

pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = logFn,
};

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = switch (level) {
        .debug => Ansi.Dim ++ "debg" ++ Ansi.Reset,
        .info => Ansi.Cyan ++ "info" ++ Ansi.Reset,
        .warn => Ansi.Yellow ++ "warn" ++ Ansi.Reset,
        .err => Ansi.Red ++ "err!" ++ Ansi.Reset,
    };
    const scope_prefix = @tagName(scope);
    const prefix = level_prefix ++ " [" ++ scope_prefix ++ "] ";

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var app = try App.init(gpa, .{});
    defer app.deinit();
    try app.run();
}
