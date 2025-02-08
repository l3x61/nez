const App = @This();

const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const gui = @import("zgui");
const glfw = @import("zglfw");
const Window = glfw.Window;
const opengl = @import("zopengl");

const Nes = @import("nes/Nes.zig");

allocator: Allocator,
window: *Window,
config: Config,
scaled_font_size: usize,
nes: Nes,

const Config = struct {
    title: [:0]const u8 = "NEZ",
    width: c_int = 1600,
    height: c_int = 900,
    gl_major: c_int = 4,
    gl_minor: c_int = 0,
    font_size: f32 = 19.0,
    clear_color: [4]f32 = [_]f32{ 0.1, 0.1, 0.1, 1.0 },
};

pub fn init(allocator: Allocator, config: Config) !App {
    var buffer: [1024]u8 = undefined;
    const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    try std.posix.chdir(path);

    // init glfw
    try glfw.init();

    glfw.windowHint(.context_version_major, config.gl_major);
    glfw.windowHint(.context_version_minor, config.gl_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.doublebuffer, true);

    const window = try glfw.Window.create(
        config.width,
        config.height,
        config.title,
        null,
    );
    window.setSizeLimits(
        config.width,
        config.height,
        -1,
        -1,
    );

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try opengl.loadCoreProfile(
        glfw.getProcAddress,
        @as(u32, @intCast(config.gl_major)),
        @as(u32, @intCast(config.gl_minor)),
    );

    // init gui
    gui.init(allocator);

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };
    const scaled_font_size = @floor(config.font_size * scale_factor);

    _ = gui.io.addFontFromFile(
        "assets/fonts/JetBrainsMono-Regular.ttf",
        scaled_font_size,
    );

    var font_config = gui.FontConfig.init();
    font_config.merge_mode = true;
    const icon_ranges: [*]const gui.Wchar = &[_]gui.Wchar{ 0xe000, 0xf8ff, 0 };
    _ = gui.io.addFontFromFileWithConfig(
        "assets/fonts/JetBrainsMonoNLNerdFontPropo-Regular.ttf",
        scaled_font_size,
        font_config,
        icon_ranges,
    );

    gui.getStyle().scaleAllSizes(scale_factor);
    gui.io.setConfigFlags(.{ .dock_enable = true });
    gui.backend.init(window);

    return App{
        .allocator = allocator,
        .window = window,
        .config = config,
        .scaled_font_size = @as(usize, @intFromFloat(scaled_font_size)),
        .nes = Nes.init(allocator),
    };
}

pub fn deinit(self: *App) void {
    self.nes.deinit();
    gui.backend.deinit();
    gui.deinit();
    self.window.destroy();
    glfw.terminate();
}

pub fn run(self: *App) !void {
    while (!self.window.shouldClose() and self.window.getKey(.escape) != .press) {
        self.update();
        try self.draw();
    }
}

fn update(self: *App) void {
    _ = self;
    glfw.pollEvents();
}

fn draw(self: *App) !void {
    const gl = opengl.bindings;
    gl.clearBufferfv(gl.COLOR, 0, &self.config.clear_color);
    const fb_size = self.window.getFramebufferSize();
    gui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

    const viewport = gui.getMainViewport();
    const dockspace_id = gui.DockSpaceOverViewport(0, viewport, .{});
    try self.nes.draw(dockspace_id);
    //gui.showMetricsWindow(null);

    gui.backend.draw();
    self.window.swapBuffers();
}
