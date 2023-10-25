const std = @import("std");
const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const LoginForm = struct {
    const WidgetAction = union (enum) {
        accept,
        cancel,
        login_change : struct { size : usize, cursor : usize },
        password_change : struct { size : usize, cursor : usize },

        pub fn loginChange (text : []const u8, cursor : usize, char : u21) ?WidgetAction {
            _ = char;
            return .{ .login_change = .{ .size = text.len, .cursor = cursor } };
        }
        pub fn passwordChange (text : []const u8, cursor : usize, char : u21) ?WidgetAction {
            _ = char;
            return .{ .password_change = .{ .size = text.len, .cursor = cursor } };
        }
    };
    const FormResult = enum {
        accept,
        cancel,
        wrong_login,
        wrong_password,
    };
    const Identity = enum {
        login,
        password,
    };
    const Form = cake.FixedUi(
        .{
            .UiEvent = WidgetAction,
            .Behavior = cake.behaviors.BuiltinBehaviors(WidgetAction),
            .WidgetIdentity = Identity,
        },
        12
    );

    const font_size : f32 = 20;
    const margin : f32 = 8;

    interface : Form = .{ .theme = cake.theme_light },
    area : cake.Rectangle,

    cursor : usize = 0,
    login_len : usize = 0,
    password_len : usize = 0,

    login_buffer : [9]u8 = [_]u8{0} ** 9,
    password_buffer : [9]u8 = [_]u8{0} ** 9,

    const accept_label = "Accept";
    const cancel_label = "Cancel";
    const login_label = "Login:";
    const password_label = "Password:";
    const invalid_user_label = "User not found!";

    pub fn uiLayout (self : *@This()) ! void {
        const ui = self.interface.layout();
        var area = self.area;
        try ui.addPlainWidget(area, .{ .background = .{} });
        area.shrinkBy(@splat(3));
        try ui.addPlainWidget(area, .{ .frame = .{ .thickness = 2 } });

        area.shrinkBy(@splat(8));
        var button_line = area.cutHorizontalPercent(-0.2, 0.1);

        area.squishHeightByPercent(0.2);
        var areas = area.splitHorizontalPercent(2, 0.1);
        areas[0].shrinkTo(.{areas[0].size[0] - margin, font_size + margin});

        try ui.addWidget(
            areas[0],
            .{
                .text_input = .{
                    .text = self.login_buffer[0..self.login_len],
                    .cursor = self.cursor,
                    .size = font_size,
                }
            },
            .{ .text_input = .{ .capacity = 9, .onInput = &WidgetAction.loginChange, .onDelete = &WidgetAction.loginChange } },
            .{ .theme = .highlight, .identity = .login }
        );
        areas[0].move(.{ 0, -(margin + font_size) });
        try ui.addPlainWidget(
            areas[0],
            .{ .label = .{ .text = login_label[0..], .size = font_size } }
        );
        if (self.login_len > 0 and std.mem.eql(u8, self.login_buffer[0..self.login_len], "cake") == false) {
            const warn_width = ui.measureText(invalid_user_label, font_size);
            areas[0].squishWidthTo(warn_width);
            try ui.addRichWidget(
                areas[0],
                .{ .label = .{ .text = invalid_user_label[0..], .size = font_size  }},
                .{ .theme = .danger }
            );
        }

        areas[1].shrinkTo(.{ areas[1].size[0] - margin, font_size + margin });
        try ui.addWidget(
            areas[1],
            .{
                .text_input = .{
                    .text = self.password_buffer[0..self.password_len],
                    .cursor = self.cursor,
                    .size = font_size,
                }
            },
            .{ .text_input = .{ .capacity = 9, .onInput = &WidgetAction.passwordChange, .onDelete = &WidgetAction.passwordChange } },
            .{ .theme = .highlight, .identity = .password }
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
        const login = self.login_buffer[0..self.login_len];
        const pass = self.password_buffer[0..self.password_len];
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

    pub fn update (self : *@This()) ! ?FormResult {
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
        if (self.interface.popEvent()) |ev| {
            switch (ev) {
                .login_change => |diff| {
                    self.login_len = diff.size;
                    self.cursor = diff.cursor;
                    try self.uiLayout();
                },
                .password_change => |diff| {
                    self.password_len = diff.size;
                    self.cursor = diff.cursor;
                },
                .accept => return self.validateLogin(),
                .cancel => return .cancel,
            }
        }
        return null;
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
                    try result_ui.setText("Login Successful!");
                    login_accepted = true;
                    countdown = 3;
                },
                .wrong_login => {
                    try hint.setText("Incorrect Login, type: cake");
                    countdown = 3;
                },
                .wrong_password => {
                    try hint.setText("Incorrect Password, type: yummy");
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
