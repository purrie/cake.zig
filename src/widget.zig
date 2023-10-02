const types = @import("types.zig");
const Rectangle = @import("Rectangle.zig");
const DrawFilter = types.DrawFilter;

pub fn WidgetConfig (
    comptime Interaction : type,
    comptime Theme : type,
    comptime Identity : type,
) type {
    switch (@typeInfo(Identity)) {
        .Enum, .Void => {},
        else => @compileError("Widget identity must be either an enum or void type"),
    }
    const theme_info = @typeInfo(Theme);
    if (theme_info != .Enum) {
        @compileError("Color theme of a widget must be an enum");
    }
    const default_theme = if (@hasDecl(Theme, "default"))
        Theme.default()
    else
        @as(Theme , @enumFromInt(theme_info.Enum.fields[0].value));


    return struct {
        const Self = @This();
        pub const Navigation = struct {
            up : ?*Self = null,
            down : ?*Self = null,
            left : ?*Self = null,
            right : ?*Self = null,
        };

        theme       : Theme        = default_theme,
        draw_filter : DrawFilter   = .{},
        can_focus   : bool         = false,
        identity    : ?Identity    = null,
        interaction : ?Interaction = null,
        navigation  : Navigation   = .{},
    };
}
