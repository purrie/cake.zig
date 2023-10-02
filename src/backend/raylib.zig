const ray = @cImport(@cInclude("raylib.h"));
const cake = @import("../main.zig");

const Rectangle = cake.Rectangle;
const Color     = cake.Color;
const Position  = cake.Vector;

pub const String = [:0]const u8;
pub const Font = ray.Font;
pub var default_font : ?ray.Font = null;

pub const view = struct {
    pub fn windowArea () Rectangle {
        return .{ .size = .{ windowWidth(), windowHeight() } };
    }
    pub fn windowWidth () f32 {
        return @floatFromInt(ray.GetScreenWidth());
    }
    pub fn windowHeight () f32 {
        return @floatFromInt(ray.GetScreenHeight());
    }
    pub fn measureText (text : [:0]const u8, font_size : f32) f32 {
        const font = default_font orelse ray.GetFontDefault();
        const result = ray.MeasureTextEx(font, text, font_size, 1);
        return result.x;
    }
};

pub const input = struct {
    pub fn keyboardEvent () ?cake.KeyboardEvent {
        const char = ray.GetCharPressed();
        const key = ray.GetKeyPressed();
        if (char == 0 and key == 0) return null;

        return .{
            .character = @intCast(char),
            .keycode = @intCast(key),
            .modifiers = .{
                .control_left  = ray.IsKeyDown(ray.KEY_LEFT_CONTROL),
                .control_right = ray.IsKeyDown(ray.KEY_RIGHT_CONTROL),
                .alt_left      = ray.IsKeyDown(ray.KEY_LEFT_ALT),
                .alt_right     = ray.IsKeyDown(ray.KEY_RIGHT_ALT),
                .shift_left    = ray.IsKeyDown(ray.KEY_LEFT_SHIFT),
                .shift_right   = ray.IsKeyDown(ray.KEY_RIGHT_SHIFT),
                .super_left    = ray.IsKeyDown(ray.KEY_LEFT_SUPER),
                .super_right   = ray.IsKeyDown(ray.KEY_RIGHT_SUPER),
            }
        };
    }
    pub fn isNavLeft (keycode : u32) bool {
        return keycode == ray.KEY_LEFT;
    }
    pub fn isNavRight (keycode : u32) bool {
        return keycode == ray.KEY_RIGHT;
    }
    pub fn isBackspace (keycode : u32) bool {
        return keycode == ray.KEY_BACKSPACE;
    }
};

pub fn drawRectangle (area : Rectangle, color : Color) void {
    var rect = ray.Rectangle {
        .x = area.position[0],
        .y = area.position[1],
        .width = area.size[0],
        .height = area.size[1],
    };
    ray.DrawRectangleRec(rect, @bitCast(color));
}
pub fn drawRectangleFrame (area : Rectangle, thickness : f32, color : Color) void {
    var rect = ray.Rectangle {
        .x = area.position[0],
        .y = area.position[1],
        .width = area.size[0],
        .height = area.size[1],
    };
    ray.DrawRectangleLinesEx(rect, thickness, @bitCast(color));
}
pub fn drawText (text : [:0]const u8, position : Position, size : f32, color : Color) void {
    const font = default_font orelse ray.GetFontDefault();
    ray.DrawTextEx(font, text, @bitCast(position), size, 1, @bitCast(color));
}
