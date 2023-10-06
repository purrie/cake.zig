const std = @import("std");
const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const LoginForm = struct {
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
            .UiEvent = WidgetAction,
            .Behavior = cake.behaviors.BuiltinBehaviors(WidgetAction),
        },
        12
    );

    const font_size : f32 = 20;
    const margin : f32 = 8;

    interface : Form = .{ .theme = cake.theme_light },
    area : cake.Rectangle,
    login_buffer : [9]u8 = [_]u8{0} ** 9,
    password_buffer : [9]u8 = [_]u8{0} ** 9,

    const accept_label = "Accept";
    const cancel_label = "Cancel";
    const login_label = "Login:";
    const password_label = "Password:";

    pub fn uiLayout (self : *@This()) ! void {
        const ui = self.interface.layout();
        var area = self.area;
        try ui.addPlainWidget(area, .{ .background = .{} });
        area.shrinkBy(@splat(3));
        try ui.addPlainWidget(area, .{ .frame = .{ .thickness = 2 } });

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
            .{ .text_input = .{} },
            .{ .theme = .highlight }
        );
        areas[0].move(.{ 0, -(margin + font_size) });
        try ui.addPlainWidget(
            areas[0],
            .{ .label = .{ .text = login_label[0..], .size = font_size } }
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
            .{ .text_input = .{} },
            .{ .theme = .highlight }
        );
        areas[1].move(.{ 0, -(margin + font_size) });
        try ui.addPlainWidget(
            areas[1],
            .{ .label = .{ .text = password_label[0..], .size = font_size } }
        );

        var buttons = button_line.splitVerticalPercent(2, 0.1);
        buttons[0].shrinkByPercent(.{ 0.4, 0.1 });
        try ui.addWidget(
            buttons[0],
            .{ .display = .{ .text = accept_label, .size = font_size } },
            .{ .button = .{ .event = .accept } },
            .{ .theme = .interactive }
        );

        buttons[1].shrinkByPercent(.{ 0.4, 0.1 });
        try ui.addWidget(
            buttons[1],
            .{ .display = .{ .text = cancel_label, .size = font_size } },
            .{ .button = .{ .event = .cancel } },
            .{ .theme = .interactive }
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

    pub fn update (self : *@This()) ! ?WidgetAction {
        const cursor = ray.GetMousePosition();
        self.interface.setPointerPosition(@bitCast(cursor));

        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            try self.interface.sendPointerEvent(.{ .press = .left });
        }
        if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_LEFT)) {
            try self.interface.sendPointerEvent(.{ .lift = .left });
        }
        if (cake.backend.input.keyboardEvent()) |ev| {
            try self.interface.sendKeyboardEvent(ev);
        }
        return self.interface.popEvent();
    }
};


const TextUi = struct {
    const Ui = cake.FixedUi(.{.Widget = cake.widgets.TextDisplay}, 1);
    interface : Ui = .{ .theme = cake.theme_light },
    area : cake.Rectangle,

    pub fn uiLayout (self : *@This(), ui : TextUi.LayoutContext) ! void {
        try ui.addPlainWidget(self.area, .{ .text = self.text });
    }
    pub fn setText (self : *@This(), text : []const u8) ! void {
        const ui = self.interface.layout();
        try ui.addPlainWidget(self.area, .{ .text = text });
    }
};

pub fn main() !void {
    ray.InitWindow(800, 600, "Login Form");
    defer ray.CloseWindow();

    var ui = LoginForm{
        .area = ar: {
            var area = cake.backend.view.windowArea();
            area.shrinkTo(.{300, 200});
            break :ar area;
        }
    };
    try ui.uiLayout();

    var result_ui = TextUi{
        .area = ar: {
            var scr = cake.backend.view.windowArea();
            scr.shrinkByPercent(.{0.5, 0.5});
            break :ar scr;
        }
    };
    var hint = TextUi{
        .area = ar: {
            var scr = cake.backend.view.windowArea();
            scr = scr.cutHorizontalPercent(-0.2, 0);
            scr.shrinkByPercent(.{ 0.3, 0.2 });
            break :ar scr;
        }
    };

    var login_accepted : bool = false;
    var countdown : f32 = 3;

    try hint.setText("login: cake, password: yummy");

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);
        if (login_accepted) {
            result_ui.interface.draw();
            countdown -= ray.GetFrameTime();
            if (countdown < 0) break;
        }
        else {
            if (try ui.update()) |ev| switch (ev) {
                .accept => {
                    switch (ui.validateLogin()) {
                        .accept => {
                            try result_ui.setText("Login Successful!");
                            login_accepted = true;
                        },
                        .wrong_login => {
                            try hint.setText("Incorrect Login, type: cake");
                        },
                        .wrong_password => {
                            try hint.setText("Incorrect Password, type: yummy");
                        },
                    }
                    countdown = 3;
                },
                .cancel => {
                    try result_ui.setText("Login Aborted!");
                    login_accepted = true;
                    countdown = 3;
                },
            };

            if (countdown > 0) {
                hint.interface.draw();
                countdown -= ray.GetFrameTime();
            }
            ui.interface.draw();
        }
    }
}
