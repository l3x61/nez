const std = @import("std");
const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);

const gui = @import("zgui");
const glfw = @import("zglfw");

pub fn draw(label: [:0]const u8, allocator: Allocator, bytes: []const u8) !void {
    const bytes_per_row = 16;
    const half_per_row = @divFloor(bytes_per_row, 2);
    const rows = @divFloor(bytes.len, bytes_per_row);

    if (bytes.len == 0) {
        gui.text("empty", .{});
        return;
    }

    if (gui.button("Copy Contents", .{})) {
        var buffer = String.init(allocator);
        defer buffer.deinit();
        var writer = buffer.writer();
        for (0.., bytes) |i, byte| {
            try writer.print("{x:0>2}{s}", .{ byte, if ((i + 1) % bytes_per_row == 0) "\n" else " " });
        }
        const slice = try buffer.toOwnedSliceSentinel(0);
        defer allocator.free(slice);
        //gui.setClipboardText(slice); // does not work reliably ?
        glfw.setClipboardString(glfw.getCurrentContext().?, slice);
    }

    if (gui.beginChild(label, .{ .child_flags = .{ .border = true }, .h = 200 })) {
        var clipper = gui.ListClipper.init();
        clipper.begin(@intCast(rows), gui.getTextLineHeight());

        while (clipper.step()) {
            for (@intCast(clipper.DisplayStart)..@intCast(clipper.DisplayEnd)) |row| {
                const offset = row * bytes_per_row;

                gui.text("{x:0>8}: ", .{offset});
                gui.sameLine(.{});

                for (offset..offset + bytes_per_row) |i| {
                    gui.text("{s}{x:0>2}", .{ if (i % half_per_row == 0 and i % bytes_per_row != 0) " " else "", bytes[i] });
                    gui.sameLine(.{});
                }
                gui.newLine();
            }
        }
        clipper.end();
    }

    gui.endChild();
}
