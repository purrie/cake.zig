const std = @import("std");
const ray = @cImport(@cInclude("raylib.h"));
const cake = @import("../cake.zig");

const Rectangle = cake.Rectangle;
const Color     = cake.Color;
const Vector  = cake.Vector;

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
    pub fn measureText (text : []const u8, font_size : f32) f32 {
        const font = default_font orelse ray.GetFontDefault();
        const result = measureText2D(text, font_size, font_size / 10.0, font);
        return result[0];
    }
    pub fn measureText2D (text : []const u8, font_size : f32, spacing : f32, font : ray.Font) Vector {
        var size = Vector{0, 0};
        var scale = font_size / @as(f32, @floatFromInt(font.baseSize));
        var width_accumulator : f32 = 0;
        var spacings : f32 = 0;
        var spacings_accumulator : f32 = 0;

        var utf8 = std.unicode.Utf8View.init(text) catch unreachable;
        var iter = utf8.iterator();

        while (iter.nextCodepoint()) |codepoint| {
            const cpoint : c_int = @intCast(codepoint);
            const index : usize = @intCast(ray.GetGlyphIndex(font, cpoint));

            switch (cpoint) {
                '\n' => {
                    if (width_accumulator > size[0]) size[0] = width_accumulator;
                    if (spacings_accumulator > spacings) spacings = spacings_accumulator;
                    width_accumulator = 0;
                    size[1] += font_size;
                },
                else => {
                    const advance = if (font.glyphs[index].advanceX != 0)
                        @as(f32, @floatFromInt(font.glyphs[index].advanceX))
                    else
                        font.recs[index].width + @as(f32, @floatFromInt(font.glyphs[index].offsetX));
                    width_accumulator += advance;
                    spacings_accumulator += 1;
                }
            }
        }
        if (width_accumulator > size[0]) size[0] = width_accumulator;
        if (spacings_accumulator > spacings) spacings = spacings_accumulator;

        size *= @splat(scale);
        size[0] += spacings * spacing;
        return size;
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
pub fn drawFrame (area : Rectangle, thickness : f32, color : Color) void {
    var rect = ray.Rectangle {
        .x = area.position[0],
        .y = area.position[1],
        .width = area.size[0],
        .height = area.size[1],
    };
    ray.DrawRectangleLinesEx(rect, thickness, @bitCast(color));
}
pub fn drawText (text : []const u8, position : Vector, size : f32, color : Color) void {
    const font = default_font orelse ray.GetFontDefault();

    var text_offset_y : f32 = 0;
    var text_offset_x : f32 = 0;
    var scale_factor = size / @as(f32, @floatFromInt(font.baseSize));

    var utf8 = std.unicode.Utf8View.init(text) catch unreachable;
    var iter = utf8.iterator();
    const spacing = size / 10.0;

    while (iter.nextCodepoint()) |codepoint| {
        const cpoint : c_int = @intCast(codepoint);
        const index : usize = @intCast(ray.GetGlyphIndex(font, cpoint));
        switch (cpoint) {
            '\n' => {
                text_offset_y += size;
                text_offset_x = 0;
                continue;
            },
            ' ', '\t' => {},
            else => {
                ray.DrawTextCodepoint(
                    font,
                    cpoint,
                    .{
                        .x = position[0] + text_offset_x,
                        .y = position[1] + text_offset_y
                    },
                    size,
                    @bitCast(color)
                );
            }
        }
        const advance = if (font.glyphs[index].advanceX == 0)
            font.recs[index].width
        else
            @as(f32, @floatFromInt(font.glyphs[index].advanceX));

        text_offset_x += advance * scale_factor + spacing;
    }
}
