const std = @import("std");
const interface = @import("interface.zig");

const floatEql = std.math.approxEqAbs;
const floatEpsilon = std.math.floatEps;

const Rectangle = @import("Rectangle.zig");

pub const Vector = @Vector(2, f32);
pub const vector_zero = Vector { 0.0, 0.0 };
pub const vector_one = Vector { 1.0, 1.0 };

/// Responsible for describing which states are active in a widget
pub const WidgetState = packed struct {
    normal   : bool = true,
    inactive : bool = false,
    hover    : bool = true,
    focus    : bool = true,
    active   : bool = true,

    pub fn isMismatch (self : WidgetState, other : WidgetState) bool {
        const me : u8 = @bitCast(self);
        const you : u8 = @bitCast(other);
        return me & you == 0;
    }

    pub fn selectColor (self : WidgetState, state : StateColor) Color {
        if (self.inactive) return state.inactive;
        if (self.active) return state.press;
        if (self.hover) return state.hover;
        if (self.focus) return state.focus;
        if (self.normal) return state.normal;
        return Color.hex(0x0);
    }
};

pub const ColorVec = @Vector(4, u8);

pub const Color = packed struct {
    r : u8,
    g : u8,
    b : u8,
    a : u8 = 255,

    pub fn hex(code : u32) Color {
        return .{
            .r = @truncate(code >> 24),
            .g = @truncate(code >> 16),
            .b = @truncate(code >> 8),
            .a = @truncate(code),
        };
    }
    pub fn lightness (self : Color) u8 {
        return @max(self.r, @max(self.g, self.b));
    }
    pub fn isBlank (self : Color) bool {
        return self.a == 0;
    }
    pub fn isLight (self : Color) bool {
        return self.lightness() >= 128;
    }
    pub fn isLightnessEdge (self : Color) bool {
        const light = self.lightness();
        return light >= 194 or light <= 64;
    }
    pub fn flip (self : Color) Color {
        const vcolor = @as(@Vector(4, u8), @bitCast(self));
        const reverse : @Vector(4, u8) = @splat(255);
        const result = reverse - vcolor;
        return @bitCast(@shuffle(u8, result, vcolor, @Vector(4, i32) { 0, 1, 2, -4 }));
    }
    pub fn rollUp (self : Color, amount : u8) Color {
        const diff = ColorVec { amount, amount, amount, 0 };
        const vcolor : ColorVec = @bitCast(self);
        return @bitCast(vcolor +% diff);
    }
    pub fn rollDown (self : Color, amount : u8) Color {
        const diff = ColorVec { amount, amount, amount, 0 };
        const vcolor : ColorVec = @bitCast(self);
        return @bitCast(vcolor -% diff);
    }
    pub fn lighten (self : Color, amount : u8) Color {
        const diff = ColorVec { amount, amount, amount, 0 };
        const vcolor : ColorVec = @bitCast(self);
        return @bitCast(vcolor +| diff);
    }
    pub fn darken (self : Color, amount : u8) Color {
        const diff = ColorVec { amount, amount, amount, 0 };
        const vcolor : ColorVec = @bitCast(self);
        return @bitCast(vcolor -| diff);
    }
    pub fn desaturate (self : Color, amount : u8) Color {
        const max : u8 = @max(self.r, @max(self.g, self.b));
        const min : u8 = @min(self.r, @min(self.g, self.b));
        const diff = @min(amount, max - min) / @as(u8, 2);
        var result = self;

        if (result.r == max) result.r -= diff
        else if (result.g == max) result.g -= diff
        else result.b -= diff;

        if (result.b == min) result.b += diff
        else if (result.g == min) result.g += diff
        else result.r += diff;

        return result;
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

/// Contains colors for specific widget states
pub const StateColor = struct {
    normal   : Color,
    inactive : Color,
    hover    : Color,
    focus    : Color,
    press    : Color,

    pub fn shadeLighter (color : Color) StateColor {
        return .{
            .normal = color,
            .inactive = color.darken(4).desaturate(8),
            .hover = color.lighten(8),
            .focus = color.lighten(16),
            .press = color.darken(8),
        };
    }
    pub fn shadeDarker (color : Color) StateColor {
        return .{
            .normal = color,
            .inactive = color.lighten(4).desaturate(8),
            .hover = color.darken(8),
            .focus = color.darken(16),
            .press = color.lighten(8),
        };
    }
    pub fn shadeUniform (color : Color) StateColor {
        return .{ .normal = color, .inactive = color, .hover = color, .focus = color, .press = color };
    }
};

/// Container for colors based on their purpose
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
    drag  : Vector,
    wheel_slide : f32,
    wheel_delta : Vector,
};

/// Result of a pointer event, used to determine which state the widget should go into as a result of the event
pub const EventResult = enum {
    /// Widget gains focus and is active
    activated,
    /// Widget retains focus and is deactivated
    deactivated,
    /// Widget gains focus
    focused,
    /// Widget loses focus and active status
    unfocused,
    /// No change in status
    processed,
    /// Event was ignored and should pass on to another widget
    ignored,
};

pub const WidgetInteractionState = enum {
    normal,
    inactive,
    hidden,
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
/// Keyboard event description, use backend to create the full description
pub const KeyboardEvent = struct {
    character : ?u21 = null,
    keycode   : ?u32 = null,
    modifiers : KeyboardModifier = .{},
};

/// Data passed to widgets on drawing events
pub const DrawingContext = struct {
    area     : Rectangle,
    pointer  : ?Vector,
    colors   : ColorScheme,
    state    : WidgetState,
};
/// Data passed to widgets on input events
pub const BehaviorContext = struct {
    area : Rectangle,
    pointer_position : Vector,
    pointer_event    : ?PointerEvent,
    keyboard_event   : ?KeyboardEvent,
    state : WidgetState,
    ui    : interface.Behavior,
};
/// Data passed to widgets on pointer events
pub const PointerContext = struct {
    area    : Rectangle,
    pointer : Vector,
    event   : PointerEvent,
    state   : WidgetState,
    ui      : interface.Behavior,
};
/// Data passed to widgets on keyboard events
pub const KeyboardContext = struct {
    area  : Rectangle,
    event : KeyboardEvent,
    state : WidgetState,
    ui    : interface.Behavior,
};
