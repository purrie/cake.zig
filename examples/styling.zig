const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const TextUi = cake.FixedUi(
    .{
        .ColorPalette = UiTheme,
        .Theme = WidgetTheme,
    }, 6);

const ColorScheme = cake.ColorScheme;

const UiTheme = cake.FixedPalette(WidgetTheme);
const WidgetTheme = enum {
    light,
    danger,
};
const Bg = cake.premade.Background;
const Frame = cake.premade.Frame;
const Label = cake.premade.Label;

const Ui = struct {
    interface : TextUi = .{
        .theme = .{
            .schemes = [2]ColorScheme{
                ColorScheme.contrastingBase(.{ .r = 194, .g = 194, .b = 194 }),
                ColorScheme.contrastingBase(.{ .r = 132, .g = 64, .b = 64 }),
            }
        }
    },
    margin : f32 = 8,

    background_top    : Bg = .{ .data = {} },
    background_bottom : Bg = .{ .data = {} },

    label_top    : Label = .{ .data = .{ .text = "Top Side", .font_size = 32 } },
    label_bottom : Label = .{ .data = .{ .text = "Bottom Side", .font_size = 20 } },

    frame       : Frame = .{ .data = .{ .thickness = 4.0 } },
    other_frame : Frame = .{ .data = .{ .thickness = 3.0 } },

    pub fn connect (self : *@This()) ! void {
        const ui = self.interface.layout();
        try ui.addPlainWidget(self.background_top.getInterface());
        try ui.addPlainWidget(self.frame.getInterface());
        try ui.addPlainWidget(self.label_top.getInterface());

        try ui.addWidget(self.background_bottom.getInterface(), .{ .theme = .danger });
        try ui.addWidget(self.other_frame.getInterface(), .{ .theme = .danger });
        try ui.addWidget(self.label_bottom.getInterface(), .{ .theme = .danger });
    }
    pub fn uiLayout (self : *@This()) void {
        const top_width = cake.backend.measureText(self.label_top.data.text, self.label_top.data.font_size);
        const bottom_width = cake.backend.measureText(self.label_bottom.data.text, self.label_bottom.data.font_size);

        var area = cake.backend.windowArea();
        var areas = area.splitHorizontalPercent(2, 0.1);
        areas[0].shrinkTo(.{ top_width + self.margin, self.label_top.data.font_size + self.margin });
        self.background_top.area = areas[0];

        areas[0].shrinkBy(@splat(self.margin * 0.2));
        self.frame.area = areas[0];

        areas[0].shrinkBy(@splat(self.margin * 0.8));
        self.label_top.area = areas[0];

        areas[1].shrinkTo(.{ bottom_width + self.margin, self.label_bottom.data.font_size + self.margin });
        self.background_bottom.area = areas[1];

        areas[1].shrinkBy(@splat(self.margin * 0.2));
        self.other_frame.area = areas[1];

        areas[1].shrinkBy(@splat(self.margin * 0.8));
        self.label_bottom.area = areas[1];
    }
};

pub fn main() !void {
    ray.InitWindow(800, 600, "Basic Styling");
    defer ray.CloseWindow();

    var ui = Ui{};
    ui.uiLayout();
    try ui.connect();

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);
        ui.interface.draw();
    }
}
