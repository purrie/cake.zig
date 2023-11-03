const std = @import("std");
const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const Bg    = cake.premade.Background;
const Frame = cake.premade.Frame;
const Label = cake.premade.Label;
const Display = cake.premade.Plaque;

const LoginForm = struct {
    const Form = cake.FixedUi(
        .{
            .Event = WidgetAction,
            .Identity = Identity,
        },
        12
    );
    const Input = cake.premade.FixedTextInput(255, WidgetAction);
    const Button = cake.premade.Button(WidgetAction);
    const Identity = enum {
        login, password
    };
    const WidgetAction = enum {
        accept,
        cancel,
        login_change,
        password_change,
    };
    const FormResult = enum {
        accept,
        cancel,
        wrong_login,
        wrong_password,
    };

    const font_size : f32 = 20;
    const margin : f32 = 8;

    interface : Form = .{ .theme = cake.theme_light },
    area : cake.Rectangle,

    background : Bg = Bg { .data = {} },
    login    : Input = Input { .data = .{}, .behavior = .{ .on_input = .login_change, .on_delete = .login_change }},
    password : Input = Input { .data = .{}, .behavior = .{ .on_input = .password_change, .on_delete = .password_change } },

    frame : Frame = Frame { .data = .{ .thickness = 4 } },

    login_label        : Label = Label { .data = .{ .text = "Login:", .font_size = font_size } },
    password_label     : Label = Label { .data = .{ .text = "Password:", .font_size = font_size } },
    invalid_user_label : Label = Label {
        .data = .{
            .text = "User not found!",
            .font_size = font_size
        },
        .hidden = true,
    },

    accept_button : Button = Button {.data = .{ .text = "Accept", .font_size = font_size },
                                     .behavior = .{ .event = .accept },
                                     .state = .inactive },
    cancel_button : Button = Button {.data = .{ .text = "Cancel", .font_size = font_size },
                                     .behavior = .{ .event = .cancel }},

    pub fn init (start_area : cake.Rectangle) @This() {
        var self = @This() {
            .area = start_area,
        };
        self.uiLayout();
        return self;
    }

    pub fn connect (self : *@This()) ! void {
        const ui = self.interface.layout();
        try ui.addPlainWidget(self.background.getInterface());
        try ui.addPlainWidget(self.frame.getInterface());
        try ui.addWidget(
            self.login.getInterface(),
            .{ .theme = .highlight, .identity = .login }
        );
        try ui.addPlainWidget(
            self.login_label.getInterface()
        );
        try ui.addWidget(
            self.invalid_user_label.getInterface(),
            .{ .theme = .danger }
        );
        try ui.addWidget(
            self.password.getInterface(),
            .{ .theme = .highlight, .identity = .password }
        );
        try ui.addPlainWidget(
            self.password_label.getInterface(),
        );
        try ui.addWidget(
            self.accept_button.getInterface(),
            .{ .theme = .interactive }
        );
        try ui.addWidget(
            self.cancel_button.getInterface(),
            .{ .theme = .interactive }
        );
    }
    pub fn uiLayout (self : *@This()) void {
        var area = self.area;
        self.background.area = area;
        area.shrinkBy(@splat(3));
        self.frame.area = area;

        area.shrinkBy(@splat(8));
        var button_line = area.cutHorizontalPercent(-0.2, 0.1);

        area.squishHeightByPercent(0.2);
        var areas = area.splitHorizontalPercent(2, 0.1);
        areas[0].shrinkTo(.{areas[0].size[0] - margin, font_size + margin});

        self.login.area = areas[0];
        areas[0].move(.{ 0, -(margin + font_size) });
        self.login_label.area = areas[0];
        const warn_width = cake.backend.measureText(self.invalid_user_label.data.text, font_size);
        areas[0].squishWidthTo(warn_width);
        self.invalid_user_label.area = areas[0];

        areas[1].shrinkTo(.{ areas[1].size[0] - margin, font_size + margin });
        self.password.area = areas[1];
        areas[1].move(.{ 0, -(margin + font_size) });
        self.password_label.area = areas[1];

        var buttons = button_line.splitVerticalPercent(2, 0.1);
        buttons[0].shrinkByPercent(.{ 0.4, 0.1 });
        self.accept_button.area = buttons[0];

        buttons[1].shrinkByPercent(.{ 0.4, 0.1 });
        self.cancel_button.area = buttons[1];
    }
    pub fn draw (self : *@This()) void {
        if (self.interface.len == 0) self.connect() catch unreachable;
        self.interface.draw();
    }
    pub fn validateLogin (self : *@This()) FormResult {
        const login = self.login.data.text[0..self.login.data.len];
        const pass = self.password.data.text[0..self.password.data.len];
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
                .login_change => {
                    const login = self.login.data.getString();
                    const pass = self.password.data.getString();
                    if (login.len == 0 or std.mem.eql(u8, login, "cake")) {
                        self.invalid_user_label.hidden = true;
                    }
                    else {
                        self.invalid_user_label.hidden = false;
                    }
                    if (login.len > 0 and pass.len > 0) {
                        self.accept_button.state = .normal;
                    }
                    else {
                        self.accept_button.state = .inactive;
                    }
                },
                .password_change => {
                    const login = self.login.data.getString();
                    const pass = self.password.data.getString();
                    if (login.len > 0 and pass.len > 0) {
                        self.accept_button.state = .normal;
                    }
                    else {
                        self.accept_button.state = .inactive;
                    }

                },
                .accept => return self.validateLogin(),
                .cancel => return .cancel,
            }
        }
        return null;
    }
};


const TextUi = struct {
    const Ui = cake.FixedUi(.{}, 1);
    interface : Ui = .{ .theme = cake.theme_light },

    label : Display,

    pub fn init (area : cake.Rectangle) @This() {
        return .{ .label = .{ .data = .{ .text = "", .font_size = 20 }, . area = area } };
    }
    pub fn connect (self : *@This()) ! void {
        const ui = self.interface.layout();
        try ui.addPlainWidget(self.label.getInterface());
    }
    pub fn setText (self : *@This(), text : []const u8) ! void {
        self.label.data.text = text;
    }
    pub fn draw (self : *@This()) void {
        if (self.interface.len == 0) self.connect() catch unreachable;
        self.interface.draw();
    }
};

pub fn main() !void {
    ray.InitWindow(800, 600, "Login Form");
    defer ray.CloseWindow();

    var ui = LoginForm.init(
        ar: {
            var area = cake.backend.windowArea();
            area.shrinkTo(.{300, 200});
            break :ar area;
        }
    );
    var result_ui = TextUi.init(
        ar: {
            var scr = cake.backend.windowArea();
            scr.shrinkByPercent(.{0.5, 0.5});
            break :ar scr;
        }
    );
    var hint = TextUi.init(
        ar: {
            var scr = cake.backend.windowArea();
            scr = scr.cutHorizontalPercent(-0.2, 0);
            scr.shrinkByPercent(.{ 0.3, 0.2 });
            break :ar scr;
        }
    );

    var login_accepted : bool = false;
    var countdown : f32 = 3;

    try hint.setText("login: cake, password: yummy");

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
                hint.draw();
                countdown -= ray.GetFrameTime();
            }
            ui.draw();
        }
    }
}
