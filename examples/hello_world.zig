const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const TextUi = cake.FixedUi(
    .{
        .Core = struct {
            text : [:0]const u8,

            pub fn uiLayout (self : *const @This(), ui : TextUi.LayoutContext) ! void {
                const width = ui.measureText(self.text, 20);
                var area = ui.windowArea();
                area.shrinkTo(.{ width, 20 });
                try ui.addWidget(area, .{ .text = self.text }, .{});
            }
        },
        .Widget = cake.widgets.Label,
    },
    1
);

pub fn main() !void {
    ray.InitWindow(800, 600, "Hello Cake");
    defer ray.CloseWindow();

    var ui = TextUi.init(.{ .text = "Hello Cake!" }, cake.theme_dark);
    try ui.bake();

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);
        ui.draw();
    }
}
