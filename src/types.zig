const std = @import("std");

const floatEql = std.math.approxEqAbs;
const floatEpsilon = std.math.floatEps;

const Rectangle = @import("Rectangle.zig");

pub const Vector = @Vector(2, f32);
pub const vector_zero = Vector { 0.0, 0.0 };
pub const vector_one = Vector { 1.0, 1.0 };

pub const DrawState = packed struct {
    normal : bool = true,
    hover : bool = true,
    focus : bool = true,
    active : bool = true,

    pub fn isMismatch (self : DrawState, other : DrawState) bool {
        const me : u4 = @bitCast(self);
        const you : u4 = @bitCast(other);
        return me & you == 0;
    }

    pub fn selectColor (self : DrawState, state : StateColor) Color {
        if (self.active) return state.press;
        if (self.hover) return state.hover;
        if (self.focus) return state.focus;
        return state.normal;
    }
};

pub const ColorVec = @Vector(4, u8);

pub const Color = packed struct {
    r : u8,
    g : u8,
    b : u8,
    a : u8 = 255,

    pub inline fn hex(code : u32) Color {
        return .{
            .r = @truncate(code >> 24),
            .g = @truncate(code >> 16),
            .b = @truncate(code >> 8),
            .a = @truncate(code),
        };
    }
    pub inline fn lightness (self : Color) u8 {
        return @max(self.r, @max(self.g, self.b));
    }
    pub inline fn isLight (self : Color) bool {
        return self.lightness() >= 128;
    }
    pub inline fn isLightnessEdge (self : Color) bool {
        const light = self.lightness();
        return light >= 194 or light <= 64;
    }
    pub inline fn flip (self : Color) Color {
        const vcolor = @as(@Vector(4, u8), @bitCast(self));
        const reverse : @Vector(4, u8) = @splat(255);
        const result = reverse - vcolor;
        return @bitCast(@shuffle(u8, result, vcolor, @Vector(4, i32) { 0, 1, 2, -4 }));
    }
    pub inline fn rollUp (self : Color, amount : u8) Color {
        const diff = ColorVec { amount, amount, amount, 0 };
        const vcolor : ColorVec = @bitCast(self);
        return @bitCast(vcolor +% diff);
    }
    pub inline fn rollDown (self : Color, amount : u8) Color {
        const diff = ColorVec { amount, amount, amount, 0 };
        const vcolor : ColorVec = @bitCast(self);
        return @bitCast(vcolor -% diff);
    }
    pub inline fn lighten (self : Color, amount : u8) Color {
        const diff = ColorVec { amount, amount, amount, 0 };
        const vcolor : ColorVec = @bitCast(self);
        return @bitCast(vcolor +| diff);
    }
    pub inline fn darken (self : Color, amount : u8) Color {
        const diff = ColorVec { amount, amount, amount, 0 };
        const vcolor : ColorVec = @bitCast(self);
        return @bitCast(vcolor -| diff);
    }

    pub const black  = Color.hex( 0x0f0f0fff );
    pub const white  = Color.hex( 0xf0f0f0ff );
    pub const gray   = Color.hex( 0x808080ff );
    pub const red    = Color.hex( 0xf01010ff );
    pub const green  = Color.hex( 0x10f010ff );
    pub const blue   = Color.hex( 0x1010f0ff );
    pub const yellow = Color.hex( 0xf0f010ff );
    pub const cyan   = Color.hex( 0x10f0f0ff );
    pub const purple = Color.hex( 0xf010f0ff );
};
pub const StateColor = struct {
    normal : Color,
    hover : Color,
    focus : Color,
    press : Color,

    pub fn shadeLighter (color : Color) StateColor {
        return .{
            .normal = color,
            .hover = .{ .r = color.r +| 8,  .g = color.g +| 8,  .b = color.b +| 8,  .a = color.a },
            .focus = .{ .r = color.r +| 16, .g = color.g +| 16, .b = color.b +| 16, .a = color.a },
            .press = .{ .r = color.r -| 8,  .g = color.g -| 8,  .b = color.b -| 8,  .a = color.a },
        };
    }
    pub fn shadeDarker (color : Color) StateColor {
        return .{
            .normal = color,
            .hover = .{ .r = color.r -| 8,  .g = color.g -| 8,  .b = color.b -| 8,  .a = color.a },
            .focus = .{ .r = color.r -| 16, .g = color.g -| 16, .b = color.b -| 16, .a = color.a },
            .press = .{ .r = color.r +| 8,  .g = color.g +| 8,  .b = color.b +| 8,  .a = color.a },
        };
    }
    pub fn shadeUniform (color : Color) StateColor {
        return .{ .normal = color, .hover = color, .focus = color, .press = color, };
    }
};

pub const ColorScheme = struct {
    background : StateColor,
    foreground : StateColor,
    text : StateColor,

    pub fn contrastingBase (color : Color) ColorScheme {
        const is_light = color.isLight();
        const edge = color.isLightnessEdge();
        return .{
            .background = if (is_light)
                StateColor.shadeDarker(color)
                else StateColor.shadeLighter(color),
            .text = if (is_light)
                StateColor.shadeLighter(
                    if (edge) color.flip() else color.rollUp(128))
                else StateColor.shadeDarker(
                    if (edge) color.flip() else color.rollDown(128)),
            .foreground = if (is_light)
                StateColor.shadeDarker(color.darken(16))
                else StateColor.shadeLighter(color.lighten(16)),
        };
    }
    /// Creates a color scheme that has uniform colors for all parts matching given one
    pub fn uniformBase (color : Color) ColorScheme {
        return .{
            .background = StateColor.shadeUniform(color),
            .foreground = StateColor.shadeUniform(color),
            .text = StateColor.shadeUniform(color),
        };
    }
};

test "color flip" {
    const expected = Color { .r = 15, .g = 1, .b = 32, .a = 255 };
    const color = Color { .r = 240, .g = 254, .b = 223, .a = 255 };
    try std.testing.expectEqualDeep(expected, color.flip());
}
test "Color Hex" {
    const expected = Color { .r = 15, .g = 1, .b = 32, .a = 255 };
    const hexed = Color.hex(0x0f0120ff);
    try std.testing.expectEqualDeep(expected, hexed);
}
test "color lightness" {
    const expect = std.testing.expect;
    try expect(Color.black.isLight() == false);
    try expect(Color.gray.isLight());
    try expect(Color.white.isLight());
}

pub const PointerButton = enum {
    left,
    right,
    middle,
    side,
    extra,
    forward,
    back,
};
pub const PointerEvent = union (enum) {
    press : PointerButton,
    lift  : PointerButton,
    wheel_slide  : f32,
    wheel_delta  : Vector,
};

pub const EventResult = enum {
    activated,
    deactivated,
    focused,
    unfocused,
    processed,
    ignored,
};

pub const KeyboardModifier = packed struct {
    control_left  : bool = false,
    control_right : bool = false,
    alt_left      : bool = false,
    alt_right     : bool = false,
    shift_left    : bool = false,
    shift_right   : bool = false,
    super_left    : bool = false,
    super_right   : bool = false,

    pub fn super (self : @This()) bool {
        return self.super_left or self.super_right;
    }
    pub fn shift (self : @This()) bool {
        return self.shift_left or self.shift_right;
    }
    pub fn alt (self : @This()) bool {
        return self.alt_left or self.alt_right;
    }
    pub fn control (self : @This()) bool {
        return self.control_left or self.control_right;
    }
};
pub const KeyboardEvent = struct {
    character : ?u32 = null,
    keycode   : ?u32 = null,
    modifiers : KeyboardModifier = .{},
};

pub const DrawingContext = struct {
    area     : Rectangle,
    position : ?Vector,
    colors   : ColorScheme,
    state    : DrawState,
};
// TODO implement behaviors
// This will decouple handling input events from drawing functions
pub const BehaviorContext = struct {
    area     : Rectangle,
    position : ?Vector,
    pointer  : ?PointerEvent,
    keyboard : ?KeyboardEvent,
};
pub const PointerContext = struct {
    area     : Rectangle,
    position : Vector,
    pointer  : PointerEvent,
};
pub const KeyboardContext = struct {
    area     : Rectangle,
    keyboard : KeyboardEvent,
};
