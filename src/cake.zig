const options = @import("build_options");

pub const Backend = enum {
    raylib,
};

pub const backend = switch (options.backend) {
    .raylib => @import("backend/raylib.zig"),
};

pub const text = @import("text.zig");

pub const types      = @import("types.zig");
pub const ui         = @import("ui.zig");
pub const style      = @import("style.zig");
pub const widgets    = @import("widgets.zig");
pub const view       = @import("viewers.zig");

pub const contains   = @import("data.zig");
pub const acts_like  = @import("behaviors.zig");
pub const looks_like = view.viewers(backend);

pub const FixedUi = ui.FixedUi;
pub const Context = ui.UIContext;

pub const FixedPalette   = style.FixedPalette;
pub const DefaultPalette = style.DefaultPalette;
pub const DefaultTheme   = style.DefaultTheme;

pub const Rectangle = @import("Rectangle.zig");
pub const Vector    = types.Vector;

pub const ColorScheme = types.ColorScheme;
pub const StateColor  = types.StateColor;
pub const Color       = types.Color;

pub const EventResult      = types.EventResult;
pub const PointerEvent     = types.PointerEvent;
pub const PointerButton    = types.PointerButton;
pub const KeyboardEvent    = types.KeyboardEvent;
pub const KeyboardModifier = types.KeyboardModifier;
pub const KeyboardContext  = types.KeyboardContext;

pub const theme_light = style.light_theme;
pub const theme_dark  = style.dark_theme;
