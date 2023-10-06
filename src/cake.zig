const types = @import("types.zig");
pub const ui = @import("ui.zig");
const style = @import("style.zig");
const options = @import("build_options");

pub const backend = switch (options.backend) {
    .raylib => @import("backend/raylib.zig"),
};
pub const widgets = @import("widgets.zig");
pub const behaviors = @import("behaviors.zig");

pub const text = @import("text.zig");

pub const FixedUi = ui.FixedUi;
pub const FixedPallete = style.FixedPalette;
pub const Context = ui.Context;

pub const Rectangle = @import("Rectangle.zig");
pub const Vector = types.Vector;

pub const ColorScheme = types.ColorScheme;
pub const StateColor = types.StateColor;
pub const Color = types.Color;

pub const EventResult = types.EventResult;
pub const PointerEvent = types.PointerEvent;
pub const PointerButton = types.PointerButton;
pub const KeyboardEvent = types.KeyboardEvent;
pub const KeyboardModifier = types.KeyboardModifier;
pub const KeyboardContext = types.KeyboardContext;

pub const theme_light = style.light_theme;
pub const theme_dark = style.dark_theme;

pub const Backend = enum {
    raylib,
};
