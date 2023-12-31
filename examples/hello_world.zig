const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const TextUi = cake.FixedUi(.{}, 1);

pub fn main() !void {
    ray.InitWindow(800, 600, "Hello Cake");
    defer ray.CloseWindow();

    var ui = TextUi.init(cake.theme_dark);
    var label = cake.premade.Plaque { .data = .{ .text = "Hello Cake" } };

    const layout = ui.layout();
    label.area = layout.windowArea();
    try layout.addPlainWidget(label.getInterface());

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);
        ui.draw();
    }
}
