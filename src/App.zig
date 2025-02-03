const App = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const gui = @import("zgui");
const glfw = @import("zglfw");
const Window = glfw.Window;
const opengl = @import("zopengl");

const NesFile = @import("NesFile.zig");

const Config = struct {
    title: [:0]const u8 = "NEZ",
    width: c_int = 900,
    height: c_int = 500,
    gl_major: u32 = 4,
    gl_minor: u32 = 6,
    font_size: f32 = 18.0,
    clear_color: [4]f32 = [_]f32{ 0.1, 0.1, 0.1, 1.0 },
};

allocator: Allocator,
window: *Window,
config: Config,

pub fn init(allocator: Allocator, config: Config) !App {
    var buffer: [1024]u8 = undefined;
    const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    try std.posix.chdir(path);

    // init glfw
    try glfw.init();

    glfw.windowHintTyped(.context_version_major, @as(i32, @intCast(config.gl_major)));
    glfw.windowHintTyped(.context_version_minor, @as(i32, @intCast(config.gl_minor)));
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = try glfw.Window.create(
        config.width,
        config.height,
        config.title,
        glfw.Monitor.getPrimary(),
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
        config.gl_major,
        config.gl_minor,
    );

    // init gui
    gui.init(allocator);

    gui.io.setConfigFlags(.{
        .dock_enable = true,
        .viewport_enable = true,
    });
    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };
    const scaled_font_size = config.font_size * scale_factor;

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
    gui.backend.init(window);

    return App{
        .allocator = allocator,
        .window = window,
        .config = config,
    };
}

pub fn deinit(self: *App) void {
    gui.backend.deinit();
    gui.deinit();
    self.window.destroy();
    glfw.terminate();
}

pub fn run(self: *App) !void {
    while (!self.window.shouldClose()) {
        self.update();
        self.draw();
    }
}

inline fn update(self: *App) void {
    _ = self;
    glfw.pollEvents();
}

inline fn draw(self: *App) void {
    // clear
    const gl = opengl.bindings;
    gl.clearBufferfv(gl.COLOR, 0, &self.config.clear_color);

    // draw
    const fb_size = self.window.getFramebufferSize();
    gui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

    gui.showDemoWindow(null);

    gui.backend.draw();
    self.window.swapBuffers();
}
