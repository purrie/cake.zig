const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const TextUi = cake.FixedUi(
    .{
        .UiColorPalette = UiTheme,
        .WidgetTheme = WidgetTheme,
    }, 6);

const ColorScheme = cake.ColorScheme;

const UiTheme = cake.FixedPallete(WidgetTheme);
const WidgetTheme = enum {
    light,
    danger,
};

const Ui = struct {
    interface : TextUi = .{
        .theme = .{
            .schemes = [2]ColorScheme{
                ColorScheme.contrastingBase(.{ .r = 194, .g = 194, .b = 194 }),
                ColorScheme.contrastingBase(.{ .r = 132, .g = 64, .b = 64 }),
            }
        }
    },
    font_size : f32 = 20,
    margin : f32 = 8,
    label_top : []const u8 = "Top Side",
    label_bottom : []const u8 = "Bottom Side",

    pub fn uiLayout (self : *@This()) ! void {
        const ui = self.interface.layout();
        const top_width = ui.measureText(self.label_top, self.font_size);
        const bottom_width = ui.measureText(self.label_bottom, self.font_size);

        var area = ui.windowArea();

        var areas = area.splitHorizontalPercent(2, 0.1);
        areas[0].shrinkTo(.{ top_width + self.margin, self.font_size + self.margin });
        try ui.addPlainWidget(areas[0], .{ .background = .{} });

        areas[0].shrinkBy(@splat(self.margin * 0.5));
        try ui.addPlainWidget(areas[0], .{ .frame = .{ .thickness = 1.0 } });

        areas[0].shrinkBy(@splat(self.margin * 0.5));
        try ui.addPlainWidget(areas[0], .{ .label = .{ .text = self.label_top, .size = self.font_size } });

        areas[1].shrinkTo(.{ bottom_width + self.margin, self.font_size + self.margin });
        try ui.addRichWidget(areas[1], .{ .background = .{} }, .{ .theme = .danger });

        areas[1].shrinkBy(@splat(self.margin * 0.5));
        try ui.addRichWidget(areas[1], .{ .frame = .{ .thickness = 2 } }, .{ .theme = .danger });

        areas[1].shrinkBy(@splat(self.margin * 0.5));
        try ui.addRichWidget(
            areas[1],
            .{ .label = .{ .text = self.label_bottom, .size = self.font_size } },
            .{ .theme = .danger }
        );
    }
};

pub fn main() !void {
    ray.InitWindow(800, 600, "Basic Styling");
    defer ray.CloseWindow();

    var ui = Ui{};
    try ui.uiLayout();

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);
        ui.interface.draw();
    }
}
