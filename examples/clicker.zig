const std = @import("std");
const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

const Rectangle = cake.Rectangle;
const font_size : f32 = 20;

pub fn main () !void {
    ray.InitWindow(1200, 600, "Clicker");
    defer ray.CloseWindow();

    ray.SetTargetFPS(30);

    var resources = Resources{};
    var improvements = Resources{};
    var purchase_costs = Resources{
        .cookies = 3,
        .cakes = 3,
        .pies = 3,
        .tarts = 3,
    };
    var next_purchase_costs = Resources{
        .cookies = 4,
        .cakes = 4,
        .pies = 4,
        .tarts = 4,
    };

    var resource_bar = ResourceBar{};
    try resource_bar.connect();
    resource_bar.updateLayout(&resources, &improvements);

    var clicker = BakeButton{};
    clicker.uiLayout();
    try clicker.connect();

    var purchasers = PurchaseButtons{
        .resources = &resources,
        .costs = &purchase_costs,
        .next_costs = &next_purchase_costs,
        .improvements = &improvements,
    };
    purchasers.uiLayout();
    try purchasers.connect();

    var warning = WarningWindow{};
    warning.uiLayout();
    try warning.connect();

    var tooltip = Tooltip{};
    try tooltip.connect();

    var rebake = false;
    var show_tooltip = false;
    var turn : usize = 0;

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        const mouse = @as(cake.Vector, @bitCast(ray.GetMousePosition()));

        if (clicker.click(mouse)) {
            resources.cookies += 1;
            rebake = true;
        }
        if (purchasers.update(mouse) catch |err| p: {
            switch (err) {
                error.cookies => try warning.warn("Not enough Cookies"),
                error.cakes => try warning.warn("Not enough Cakes"),
                error.pies => try warning.warn("Not enough Pies"),
                else => unreachable,
            }
            break :p false;
        }) {
            rebake = true;
        }
        var tip = tooltip.writer();
        if (clicker.getTooltip(tip)) {
            show_tooltip = true;
        }
        else if (purchasers.getTooltip(tip)) {
            show_tooltip = true;
        }

        if (turn > 90) {
            resources.addResources(improvements);
            turn = 0;
            rebake = true;
        }
        turn += 1;

        warning.tickDown();
        if (rebake) {
            rebake = false;
            resource_bar.updateLayout(&resources, &improvements);
        }

        ray.ClearBackground(ray.BLACK);
        resource_bar.draw();
        clicker.draw();
        purchasers.draw();
        warning.draw();
        if (show_tooltip) {
            show_tooltip = false;
            try tooltip.enableTooltip(mouse);
            tooltip.draw();
        }
    }
}

// Game Code ------------------------------------------------------------------
const Resources = struct {
    cookies : usize = 0,
    cakes : usize = 0,
    pies : usize = 0,
    tarts : usize = 0,

    fn addResources (resources : *Resources, count : Resources) void {
        resources.cookies += count.cookies;
        resources.cakes += count.cakes;
        resources.pies += count.pies;
        resources.tarts += count.tarts;
    }
};
fn purchaseUpgrade (money : *usize, cost : *usize, next_cost : *usize) bool {
    if (money.* < cost.*) return false;
    money.* = money.* - cost.*;
    const next = cost.* + next_cost.*;
    cost.* = next_cost.*;
    next_cost.* = next;
    return true;
}

// Ui Code --------------------------------------------------------------------
const PastryType = enum {
    cookies,
    cakes,
    pies,
    tarts,
};
const SingleTheme = enum {
    normal
};

const Tooltip = struct {
    const Ui = cake.FixedUi(.{}, 1);
    const Stream = std.io.FixedBufferStream([]u8);
    const Label = cake.widgets.Decor(cake.contains.FixedStringBuffer(128), cake.looks_like.text_display);

    label : Label = .{ .data = .{ .font_size = font_size } },
    ui : Ui = .{ .theme = cake.theme_light },
    stream : Stream = undefined,

    pub fn connect (self : *@This()) ! void {
        var ui = self.ui.layout();
        try ui.addPlainWidget(self.label.getInterface());
    }
    pub fn writer (self : *@This()) Stream.Writer {
        self.stream = .{ .buffer = self.label.data.text[0..], .pos = 0 };
        return self.stream.writer();
    }
    pub fn enableTooltip(self : *@This(), position : cake.Vector) ! void {
        if (self.stream.pos == 0) return error.NoTooltip;
        const string = self.label.data.text[0..self.stream.pos];
        const size = cake.backend.measureText(string, font_size);
        const screen = cake.backend.windowArea();
        var tooltip = cake.Rectangle{
            .position = position,
            .size = .{ size + font_size, font_size * 2 }
        };
        tooltip.clampInsideOf(screen);
        self.label.area = tooltip;
        self.label.data.len = self.stream.pos;
    }
    pub fn draw (self : *@This()) void {
        self.ui.draw();
    }
};
const ResourceBar = struct {
    const Ui = cake.FixedUi(.{}, 9);
    const Background = cake.widgets.Decor(void, cake.looks_like.background);
    const Label = cake.widgets.Decor(cake.contains.FixedStringBuffer(buffer_size), cake.looks_like.label);
    const buffer_size = 20;
    const label_spacing = 16;

    interface : Ui = Ui{ .theme = cake.theme_light },

    background : Background = .{ .data = {} },

    cookies : Label = .{ .data = .{ .font_size = font_size } },
    cakes   : Label = .{ .data = .{ .font_size = font_size } },
    pies    : Label = .{ .data = .{ .font_size = font_size } },
    tarts   : Label = .{ .data = .{ .font_size = font_size } },

    baker_cookie : Label = .{ .data = .{ .font_size = font_size } },
    baker_cake   : Label = .{ .data = .{ .font_size = font_size } },
    baker_pie    : Label = .{ .data = .{ .font_size = font_size } },
    baker_tart   : Label = .{ .data = .{ .font_size = font_size } },

    pub fn connect (self : *@This()) ! void {
        const ui = self.interface.layout();
        try ui.addPlainWidget(self.background.getInterface());
        try ui.addPlainWidget(self.cookies.getInterface());
        try ui.addPlainWidget(self.cakes.getInterface());
        try ui.addPlainWidget(self.pies.getInterface());
        try ui.addPlainWidget(self.tarts.getInterface());
        try ui.addPlainWidget(self.baker_cookie.getInterface());
        try ui.addPlainWidget(self.baker_cake.getInterface());
        try ui.addPlainWidget(self.baker_pie.getInterface());
        try ui.addPlainWidget(self.baker_tart.getInterface());
    }

    pub fn updateLayout (self : *@This(), resources : *const Resources, improvements : *const Resources) void {
        var screen = cake.backend.windowArea();
        const measureText = cake.backend.measureText;
        screen = screen.cutHorizontal(font_size + 8, 0);

        self.background.area = screen;
        screen.shrinkBy(@splat(4));

        // Resource counters
        {
            const cookie_value = std.fmt.bufPrint(
                self.cookies.data.text[0..],
                "Cookies: {d}",
                .{resources.cookies}
            ) catch "inf";
            self.cookies.data.len = cookie_value.len;
            self.cookies.area = screen.cutVertical(
                measureText(self.cookies.data.getString(), font_size),
                label_spacing,
            );

            const cakes_value = std.fmt.bufPrint(
                self.cakes.data.text[0..],
                "Cakes: {d}",
                .{ resources.cakes }
            ) catch "inf";
            self.cakes.data.len = cakes_value.len;
            self.cakes.area = screen.cutVertical(
                measureText(cakes_value, font_size),
                label_spacing
            );

            const pies_value = std.fmt.bufPrint(
                self.pies.data.text[0..],
                "Pies: {d}",
                .{ resources.pies }
            ) catch "inf";
            self.pies.data.len = pies_value.len;
            self.pies.area = screen.cutVertical(
                measureText(pies_value, font_size),
                label_spacing
            );

            const tart_value = std.fmt.bufPrintZ(
                self.tarts.data.text[0..],
                "Tarts: {d}",
                .{ resources.tarts }
            ) catch "inf";
            self.tarts.data.len = tart_value.len;
            self.tarts.area = screen.cutVertical(
                measureText(tart_value, font_size),
                label_spacing
            );
        }
        // Improvements counters
        {
            const tart_bakers = std.fmt.bufPrint(
                self.baker_tart.data.text[0..],
                "Tart Bakers: {d}", .{ improvements.tarts }
            ) catch "inf";
            self.baker_tart.data.len = tart_bakers.len;
            self.baker_tart.area = screen.cutVertical(
                -measureText(tart_bakers, font_size),
                label_spacing
            );

            const pie_bakers = std.fmt.bufPrint(
                self.baker_pie.data.text[0..],
                "Pie Bakers: {d}", .{ improvements.pies }
            ) catch "inf";
            self.baker_pie.data.len = pie_bakers.len;
            self.baker_pie.area = screen.cutVertical(
                -measureText(pie_bakers, font_size),
                label_spacing
            );

            const cake_bakers = std.fmt.bufPrint(
                self.baker_cake.data.text[0..],
                "Cake Bakers: {d}", .{ improvements.cakes }
            ) catch "inf";
            self.baker_cake.data.len = cake_bakers.len;
            self.baker_cake.area = screen.cutVertical(
                -measureText(cake_bakers, font_size),
                label_spacing
            );

            const cookie_bakers = std.fmt.bufPrint(
                self.baker_cookie.data.text[0..],
                "Cookie Bakers: {d}", .{ improvements.cookies }
            ) catch "inf";
            self.baker_cookie.data.len = cookie_bakers.len;
            self.baker_cookie.area = screen.cutVertical(
                -measureText( cookie_bakers, font_size ),
                label_spacing
            );
        }
    }
    pub fn draw (self : *const @This()) void {
        self.interface.draw();
    }
};
const BakeButton = struct {
    const BakeEvent = enum {
        bake,
    };
    const Ui = cake.FixedUi(.{.Event = BakeEvent,}, 1);
    const Button = cake.widgets.Widget(cake.contains.Text, cake.looks_like.text_display, cake.acts_like.Button(BakeEvent));
    interface : Ui = Ui{ .theme = cake.theme_light },

    label : Button = .{
        .data = .{ .text = "Bake", .font_size = font_size },
        .behavior = .{ .event = .bake }
    },

    pub fn connect (self : *@This()) ! void {
        const ui = self.interface.layout();
        try ui.addPlainWidget(self.label.getInterface());
    }

    pub fn uiLayout (self : *@This()) void {
        const ui = self.interface.layout();
        var location = ui.windowArea();
        location = location.cutVerticalPercent(0.5, 0);
        const size = ui.measureText(self.label.data.text, font_size);
        location.shrinkTo(@splat(size * 2));
        self.label.area = location;
    }
    pub fn click (self : *@This(), mouse : cake.Vector) bool {
        self.interface.setPointerPosition(mouse);
        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            self.interface.sendPointerEvent(.{ .press = .left }) catch {};
        }
        if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_LEFT)) {
            self.interface.sendPointerEvent(.{ .lift = .left }) catch {};
        }
        return self.interface.popEvent() != null;
    }
    pub fn draw (self : *const @This()) void {
        self.interface.draw();
    }
    pub fn getTooltip (self : *@This(), writer : anytype) bool {
        if (self.interface.getHoveredWidget() != null) {
            writer.print("Click to bake a cookie", .{}) catch unreachable;
            return true;
        }
        return false;
    }
};
const PurchaseButtons = struct {
    const Ui = cake.FixedUi(.{ .Identity = PastryType, .Event = PastryType }, 5);
    const Background = cake.widgets.Decor(void, cake.looks_like.background);
    const Button = cake.widgets.Widget(
        cake.contains.Text,
        cake.looks_like.text_display,
        cake.acts_like.Button(PastryType),
    );

    background : Background = .{ .data = {} },
    cookie : Button = .{
        .data = .{ .text = "Hire Cookie Baker", .font_size = font_size },
        .behavior = .{ .event = .cookies },
    },
    cakes : Button = .{
        .data = .{ .text = "Hire Cake Baker", .font_size = font_size },
        .behavior = .{ .event = .cakes },
    },
    pies : Button = .{
        .data = .{ .text = "Hire Pie Baker", .font_size = font_size },
        .behavior = .{ .event = .pies },
    },
    tarts : Button = .{
        .data = .{ .text = "Hire Tart Baker", .font_size = font_size },
        .behavior = .{ .event = .tarts },
    },

    interface : Ui = Ui { .theme = cake.theme_light },
    resources : *Resources,
    costs : *Resources,
    next_costs : *Resources,
    improvements : *Resources,

    pub fn connect (self : *@This()) ! void {
        const ui = self.interface.layout();
        try ui.addPlainWidget(self.background.getInterface());

        try ui.addWidget(self.cookie.getInterface(), .{ .theme = .interactive, .identity = .cookies });
        try ui.addWidget(self.cakes.getInterface(),  .{ .theme = .interactive, .identity = .cakes });
        try ui.addWidget(self.pies.getInterface(),   .{ .theme = .interactive, .identity = .pies });
        try ui.addWidget(self.tarts.getInterface(),  .{ .theme = .interactive, .identity = .tarts });
    }
    pub fn uiLayout (self : *@This()) void {
        const measureText = cake.backend.measureText;

        const cookie_size = measureText(self.cookie.data.text , font_size);
        const cake_size   = measureText(self.cakes.data.text  , font_size);
        const pie_size    = measureText(self.pies.data.text   , font_size);
        const tart_size   = measureText(self.tarts.data.text  , font_size);

        const max_width   = @max(@max(cookie_size, cake_size), @max(pie_size, tart_size));
        const button_size = font_size + 16;
        const spacing     = font_size * 0.5;

        var location = cake.backend.windowArea();
        location = location.cutVerticalPercent(-0.5, 0);
        location.shrinkTo(.{ max_width + 16, button_size * 4 + spacing * 5 });

        self.background.area = location;

        location.shrinkWidthTo(max_width + 8);
        location.size[1] = button_size;
        location.move(.{ 0, spacing });

        self.cookie.area = location;

        location.move(.{ 0, button_size + spacing });
        self.cakes.area = location;

        location.move(.{ 0, button_size + spacing });
        self.pies.area = location;

        location.move(.{ 0, button_size + spacing });
        self.tarts.area = location;
    }

    pub fn update (self : *@This(), mouse : cake.Vector) ! bool {
        self.interface.setPointerPosition(mouse);
        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            try self.interface.sendPointerEvent(.{ .press = .left });
        }
        if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_LEFT)) {
            try self.interface.sendPointerEvent(.{ .lift = .left });
        }
        if (self.interface.popEvent()) |ev| {
            var ptr = switch (ev) {
                .cookies => .{
                    &self.resources.cookies,
                    &self.costs.cookies,
                    &self.next_costs.cookies,
                    &self.improvements.cookies,
                    error.cookies
                },
                .cakes => .{
                    &self.resources.cookies,
                    &self.costs.cakes,
                    &self.next_costs.cakes,
                    &self.improvements.cakes,
                    error.cookies
                },
                .pies => .{
                    &self.resources.cakes,
                    &self.costs.pies,
                    &self.next_costs.pies,
                    &self.improvements.pies,
                    error.cakes
                },
                .tarts => .{
                    &self.resources.pies,
                    &self.costs.tarts,
                    &self.next_costs.tarts,
                    &self.improvements.tarts,
                    error.pies
                },
            };
            const result = purchaseUpgrade(
                ptr[0],
                ptr[1],
                ptr[2],
            );
            if (result) {
                ptr[3].* += 1;
                return true;
            }
            else {
                return ptr[4];
            }
        }
        return false;
    }
    pub fn draw (self : *const @This()) void {
        self.interface.draw();
    }
    pub fn getTooltip (self : *@This(), writer : anytype) bool {
        if (self.interface.getHoveredWidget()) |wid| {
            if (wid.meta.identity) |id| {
                const cost = switch (id) {
                    .cookies => self.costs.cookies,
                    .cakes => self.costs.cakes,
                    .pies => self.costs.pies,
                    .tarts => self.costs.tarts,
                };
                writer.print("Cost: {d}", .{cost}) catch unreachable;
                return true;
            }
        }
        return false;
    }
};
const WarningWindow = struct {
    const Ui = cake.FixedUi(
        .{
            .Theme = SingleTheme,
            .ColorPalette = cake.FixedPalette(SingleTheme),
        },
        1
    );
    const Label = cake.widgets.Decor(cake.contains.Text, cake.looks_like.text_display);
    const reset_timer = 3;

    interface : Ui = .{
        .theme = .{
            .schemes = [_]cake.ColorScheme{
                cake.ColorScheme.contrastingBase(.{ .r = 140, .g = 100, .b = 100 })
            }
        }
    },
    text : Label = .{ .data = .{ .text = "", .font_size = font_size }},
    timer : f32 = -1,
    window : ?*WarningWindow = null,

    pub fn connect (self : *@This()) ! void {
        var ui = self.interface.layout();
        try ui.addPlainWidget(self.text.getInterface());
    }
    pub fn uiLayout (self : *@This()) void {
        var screen = cake.backend.windowArea();
        screen = screen.cutHorizontalPercent(-0.2, 0);
        screen.shrinkBy(@splat(10));
        self.text.area = screen;
    }
    pub fn draw (self : *const @This()) void {
        if (self.timer > 0) {
            self.interface.draw();
        }
    }

    pub fn tickDown (self : *@This()) void {
        self.timer -= ray.GetFrameTime();
    }
    pub fn warn (self : *@This(), warning : []const u8) ! void {
        self.timer = reset_timer;
        self.text.data.text = warning;
    }
};
