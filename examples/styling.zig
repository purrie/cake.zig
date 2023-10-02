const std = @import("std");
const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const WidgetTheme = enum {
    light,
    danger,

    pub fn default () WidgetTheme {
        return .light;
    }
    pub fn getColorScheme(self : WidgetTheme, theme : *const UiTheme) ColorScheme {
        return theme.getColors(self);
    }
};
const Core = struct {
    font_size : f32 = 20,
    margin : f32 = 8,
    label_top : [:0]const u8 = "Top Side",
    label_bottom : [:0]const u8 = "Bottom Side",

    pub fn uiLayout (self : *const @This(), ui : TextUi.LayoutContext) ! void {
        const top_width = ui.measureText(self.label_top, self.font_size);
        const bottom_width = ui.measureText(self.label_bottom, self.font_size);

        var area = ui.windowArea();

        var areas = area.splitHorizontalPercent(2, 0.1);
        areas[0].shrinkTo(.{ top_width + self.margin, self.font_size + self.margin });
        try ui.addWidget(areas[0], .{ .background = .{} }, .{});

        areas[0].shrinkBy(@splat(self.margin * 0.5));
        try ui.addWidget(areas[0], .{ .frame = .{ .thickness = 1.0 } }, .{});

        areas[0].shrinkBy(@splat(self.margin * 0.5));
        try ui.addWidget(areas[0], .{ .label = .{ .text = self.label_top, .size = self.font_size } }, .{});

        areas[1].shrinkTo(.{ bottom_width + self.margin, self.font_size + self.margin });
        try ui.addWidget(areas[1], .{ .background = .{} }, .{ .theme = .danger });

        areas[1].shrinkBy(@splat(self.margin * 0.5));
        try ui.addWidget(areas[1], .{ .frame = .{ .thickness = 2 } }, .{ .theme = .danger });

        areas[1].shrinkBy(@splat(self.margin * 0.5));
        try ui.addWidget(areas[1], .{ .label = .{ .text = self.label_bottom, .size = self.font_size } },
                      .{ .theme = .danger });
    }
};

const context = cake.Context {
    .Core = Core,
    .UiColorPalette = UiTheme,
    .Widget = WidgetType,
    .WidgetTheme = WidgetTheme,
};

const WidgetType = cake.widgets.BuiltinWidgets;
const UiTheme = cake.FixedPallete(WidgetTheme);
const TextUi = cake.FixedUi(context, 6);
const ColorScheme = cake.ColorScheme;

pub fn main() !void {
    ray.InitWindow(800, 600, "Basic Styling");
    defer ray.CloseWindow();
    var theme : UiTheme = .{};
    theme.setColors(.light, ColorScheme.contrastingBase(.{ .r = 194, .g = 194, .b = 194 }));
    theme.setColors(.danger, ColorScheme.contrastingBase(.{ .r = 132, .g = 64, .b = 64 }));

    var ui = TextUi.init(.{}, theme);
    try ui.bake();

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);
        ui.draw();
    }
}
