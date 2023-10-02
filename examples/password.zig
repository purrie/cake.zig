const std = @import("std");
const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const Core = struct {
    const font_size : f32 = 20;
    const margin : f32 = 8;

    area : cake.Rectangle,
    login_buffer : [9]u8 = [_]u8{0} ** 9,
    password_buffer : [9]u8 = [_]u8{0} ** 9,

    const accept_label = "Accept";
    const cancel_label = "Cancel";
    const login_label = "Login:";
    const password_label = "Password:";

    pub fn uiLayout (self : *const @This(), ui : Form.LayoutContext) ! void {
        var area = self.area;
        try ui.addWidget(area, .{ .background = .{} }, .{});
        area.shrinkBy(@splat(3));
        try ui.addWidget(area, .{ .frame = .{ .thickness = 2 } }, .{});

        area.shrinkBy(@splat(8));
        var button_line = area.cutHorizontalPercent(-0.2, 0.1);

        _ = area.cutHorizontalPercent(0.2, 0);
        var areas = area.splitHorizontalPercent(2, 0.1);
        areas[0].shrinkTo(.{areas[0].size[0] - margin, font_size + margin});

        try ui.addWidget(
            areas[0],
            .{
                .text_input = .{
                    .text = @constCast(self.login_buffer[0..0 :0]),
                    .size = font_size,
                    .capacity = 9,
                }
            },
            .{ .theme = .highlight, .can_focus = true }
        );
        areas[0].move(.{ 0, -(margin + font_size) });
        try ui.addWidget(
            areas[0],
            .{ .label = .{ .text = login_label[0..], .size = font_size } },
            .{}
        );

        areas[1].shrinkTo(.{ areas[1].size[0] - margin, font_size + margin });
        try ui.addWidget(
            areas[1],
            .{
                .text_input = .{
                    .text = @constCast(self.password_buffer[0..0 :0]),
                    .size = font_size,
                    .capacity = 9,
                }
            },
            .{ .theme = .highlight, .can_focus = true }
        );
        areas[1].move(.{ 0, -(margin + font_size) });
        try ui.addWidget(
            areas[1],
            .{ .label = .{ .text = password_label[0..], .size = font_size } },
            .{}
        );

        var buttons = button_line.splitVerticalPercent(2, 0.1);
        buttons[0].shrinkByPercent(.{ 0.4, 0.1 });
        try ui.addWidget(
            buttons[0],
            .{ .button = .{ .text = accept_label, .size = font_size, .event = .accept } },
            .{ .theme = .interactive, .interaction = true }
        );

        buttons[1].shrinkByPercent(.{ 0.4, 0.1 });
        try ui.addWidget(
            buttons[1],
            .{ .button = .{ .text = cancel_label, .size = font_size, .event = .cancel } },
            .{ .theme = .interactive, .interaction = true }
        );
    }

    pub fn validateLogin (self : *@This()) FormResult {
        const login_z : [*:0]const u8 = self.login_buffer[0..8 :0];
        const pass_z : [*:0]const u8 = self.password_buffer[0..8 :0];
        const login = std.mem.span(login_z);
        const pass = std.mem.span(pass_z);
        if (std.mem.eql(u8, login, "cake")) {
            if (std.mem.eql(u8, pass, "yummy")) {
                return .accept;
            }
            else {
                return .wrong_password;
            }
        }
        else {
            return .wrong_login;
        }
    }
};

const WidgetAction = enum {
    accept,
    cancel,
};
const FormResult = enum {
    accept,
    wrong_login,
    wrong_password,
};
const Form = cake.FixedUi(
    .{
        .Core = Core,
        .Widget = cake.widgets.ExtendedWidgets(WidgetAction),
        .Interaction = bool,
        .UiEvent = WidgetAction,
    },
    12
);

const TextUi = cake.FixedUi(
    .{
        .Core = struct {
            text : [:0]const u8 = "",
            area : cake.Rectangle,

            pub fn uiLayout (self : *@This(), ui : TextUi.LayoutContext) ! void {
                try ui.addWidget(self.area, .{ .text = self.text }, .{});
            }
        },
        .Widget = cake.widgets.TextDisplay,
    },
    1
);


pub fn main() !void {
    ray.InitWindow(800, 600, "Basic Styling");
    defer ray.CloseWindow();

    var area = cake.backend.view.windowArea();
    area.shrinkTo(.{300, 200});
    var ui = Form.init(.{ .area = area, }, cake.theme_light);
    try ui.bake();

    var login_accepted : bool = false;
    var countdown : f32 = 3;
    var result_ui = TextUi.init(
        .{
            .area = ar: {
                var scr = cake.backend.view.windowArea();
                scr.shrinkByPercent(.{0.5, 0.5});
                break :ar scr;
            }
        },
        cake.theme_light
    );
    var hint = TextUi.init(
        .{
            .text = "login: cake, password: yummy",
            .area = ar: {
                var scr = cake.backend.view.windowArea();
                scr = scr.cutHorizontalPercent(-0.2, 0);
                scr.shrinkByPercent(.{ 0.3, 0.2 });
                break :ar scr;
            }
        },
        cake.theme_light
    );
    try hint.bake();

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);
        if (login_accepted) {
            result_ui.draw();
            countdown -= ray.GetFrameTime();
            if (countdown < 0) break;
        }
        else {
            const cursor = ray.GetMousePosition();
            ui.setPointerPosition(@bitCast(cursor));

            if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
                try ui.sendPointerEvent(.{ .press = .left });
            }
            if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_LEFT)) {
                try ui.sendPointerEvent(.{ .lift = .left });
            }
            if (cake.backend.input.keyboardEvent()) |ev| {
                try ui.sendKeyboardEvent(ev);
            }

            if (ui.popEvent()) |ev| switch (ev) {
                .accept => {
                    switch (ui.core.validateLogin()) {
                        .accept => {
                            result_ui.core.text = "Login Successful!";
                            try result_ui.bake();
                            login_accepted = true;
                            countdown = 3;
                        },
                        .wrong_login => {
                            hint.core.text = "Incorrect Login";
                            try hint.bake();
                            countdown = 3;
                        },
                        .wrong_password => {
                            hint.core.text = "Incorrect Password";
                            try hint.bake();
                            countdown = 3;
                        },
                    }
                },
                .cancel => {
                    result_ui.core.text = "Login Aborted!";
                    try result_ui.bake();
                    login_accepted = true;
                    countdown = 3;
                },
            };
            if (countdown > 0) {
                hint.draw();
                countdown -= ray.GetFrameTime();
            }
            ui.draw();
        }
    }
}
