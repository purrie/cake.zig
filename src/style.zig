const types = @import("types.zig");
const Color = types.Color;
const ColorScheme = types.ColorScheme;
const StateColor = types.StateColor;

/// Creates a palette that holds colors corresponding to each enum value
pub fn FixedPalette (comptime ThemeEnum : type) type  {
    const info = @typeInfo(ThemeEnum);
    if (info != .Enum) {
        @compileError("FixedPalette theme must be enum based");
    }
    const entries = info.Enum.fields.len;
    const ordered = for (info.Enum.fields, 0..) |field, i| {
        if (field.value != i) break false;
    } else true;

    return struct {
        const Self = @This();
        schemes : [entries]ColorScheme = undefined,

        pub fn getColors (self : *const Self, scheme : ThemeEnum) ColorScheme {
            if (ordered) {
                return self.schemes[@intFromEnum(scheme)];
            }
            else {
                inline for (info.Enum.fields, 0..) |field, i| {
                    if (field.value == @intFromEnum(scheme)) {
                        return self.schemes[i];
                    }
                }
                unreachable;
            }
        }
        pub fn setColors (self : *Self, scheme : ThemeEnum, colors : ColorScheme) void {
            if (ordered) {
                self.schemes[@intFromEnum(scheme)] = colors;
            }
            else {
                inline for (info.Enum.fields, 0..) |field, i| {
                    if (field.value == @intFromEnum(scheme)) {
                        self.schemes[i] = colors;
                    }
                }
            }
        }
    };
}

/// Enumeration for default color palette
pub const DefaultTheme = enum {
    normal,
    highlight,
    interactive,
    danger,
};
pub const DefaultPalette = FixedPalette(DefaultTheme);

/// Default color palette with light shade color scheme
pub const light_theme = DefaultPalette {
    .schemes = [_]ColorScheme{
        ColorScheme.contrastingBase(.{ .r = 0xf0, .g = 0xf0, .b = 0xf0 }),
        ColorScheme.contrastingBase(.{ .r = 0xd0, .g = 0xd2, .b = 0xd2 }),
        ColorScheme.contrastingBase(.{ .r = 0xb0, .g = 0xc0, .b = 0xd0 }),
        ColorScheme.contrastingBase(.{ .r = 0xe0, .g = 0x80, .b = 0x80 }),
    }
};
/// Default color palette with dark shaded color scheme
pub const dark_theme = DefaultPalette {
    .schemes = [_]ColorScheme{
        ColorScheme.contrastingBase(.{ .r = 0x20, .g = 0x20, .b = 0x20 }),
        ColorScheme.contrastingBase(.{ .r = 0x40, .g = 0x40, .b = 0x40 }),
        ColorScheme.contrastingBase(.{ .r = 0x30, .g = 0x40, .b = 0x48 }),
        ColorScheme.contrastingBase(.{ .r = 0xa0, .g = 0x20, .b = 0x20 }),
    }
};


test "Enum based themes" {
    const Styles = enum {
        first, second, third,
    };
    const T = FixedPalette(Styles);
    var theme : T = undefined;
    theme.setColors(.first, .{
        .background = StateColor.shadeDarker(Color.gray),
        .foreground = StateColor.shadeDarker(Color.gray),
        .text = StateColor.shadeDarker(Color.black)
    });

    const p = theme.getColors(.first);
    try @import("std").testing.expectEqualDeep(Color.gray, p.background.normal);
}

