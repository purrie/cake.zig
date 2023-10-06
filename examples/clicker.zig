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

    var resource_bar = ResourceBar{
        .resources = &resources,
        .improvements = &improvements,
    };
    var clicker = BakeButton{};
    var purchasers = PurchaseButtons{
        .resources = &resources,
        .costs = &purchase_costs,
        .next_costs = &next_purchase_costs,
        .improvements = &improvements,
    };
    var warning = WarningWindow{};
    var tooltip = Tooltip{};

    try resource_bar.uiLayout();
    try clicker.uiLayout();
    try purchasers.uiLayout();

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
                // error.tarts => try warning.warn("Not enough Tarts"),
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
            try resource_bar.uiLayout();
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
const BakeEvent = enum {
    bake,
};
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
    const Ui = cake.FixedUi(
        .{
            .Widget = cake.widgets.TextDisplay,
        }, 1
    );
    const Stream = std.io.FixedBufferStream([]u8);

    buffer : [30]u8 = undefined,
    ui : Ui = .{ .theme = cake.theme_light },
    stream : Stream = undefined,

    pub fn writer (self : *@This()) Stream.Writer {
        self.stream = .{ .buffer = self.buffer[0..], .pos = 0 };
        return self.stream.writer();
    }
    pub fn enableTooltip(self : *@This(), position : cake.Vector) ! void {
        if (self.stream.pos == 0) return error.NoTooltip;
        self.buffer[self.stream.pos] = 0;
        const string = self.buffer[0..self.stream.pos :0];
        var paint = self.ui.layout();
        const size = paint.measureText(string, font_size);
        const screen = paint.windowArea();
        var tooltip = cake.Rectangle{
            .position = position,
            .size = .{ size + font_size, font_size * 2 }
        };
        tooltip.clampInsideOf(screen);
        try paint.addPlainWidget(
            tooltip,
            .{ .text = string, .size = font_size }
        );
    }
    pub fn draw (self : *@This()) void {
        self.ui.draw();
    }
};
const ResourceBar = struct {
    const Ui = cake.FixedUi(.{}, 9);
    const buffer_size = 20;

    const label_spacing = 16;

    resources : *Resources,
    improvements : *Resources,
    interface : Ui = Ui{ .theme = cake.theme_light },


    cookie_buffer : [buffer_size]u8 = [_]u8{0} ** buffer_size,
    cakes_buffer  : [buffer_size]u8 = [_]u8{0} ** buffer_size,
    pies_buffer   : [buffer_size]u8 = [_]u8{0} ** buffer_size,
    tarts_buffer  : [buffer_size]u8 = [_]u8{0} ** buffer_size,

    cookie_baker_buffer : [buffer_size]u8 = [_]u8{0} ** buffer_size,
    cakes_baker_buffer  : [buffer_size]u8 = [_]u8{0} ** buffer_size,
    pies_baker_buffer   : [buffer_size]u8 = [_]u8{0} ** buffer_size,
    tarts_baker_buffer  : [buffer_size]u8 = [_]u8{0} ** buffer_size,

    pub fn uiLayout (self : *@This()) ! void {
        const ui = self.interface.layout();
        var screen = ui.windowArea();
        screen = screen.cutHorizontal(font_size + 8, 0);

        try ui.addPlainWidget(screen, .{ .background = .{} });
        screen.shrinkBy(@splat(4));

        // Resource counters
        {
            const cookie_value = std.fmt.bufPrintZ(
                self.cookie_buffer[0..],
                "Cookies: {d}",
                .{self.resources.cookies}
            ) catch "inf";
            try ui.addPlainWidget(
                screen.cutVertical(
                    ui.measureText(cookie_value, font_size),
                    label_spacing,
                ),
                .{ .label = .{ .text = cookie_value, .size = font_size }},
            );

            const cakes_value = std.fmt.bufPrintZ(
                self.cakes_buffer[0..],
                "Cakes: {d}",
                .{ self.resources.cakes }
            ) catch "inf";
            try ui.addPlainWidget(
                screen.cutVertical(
                    ui.measureText(cakes_value, font_size),
                    label_spacing
                ),
                .{ .label = .{ .text = cakes_value, .size = font_size } }
            );

            const pies_value = std.fmt.bufPrintZ(
                self.pies_buffer[0..],
                "Pies: {d}",
                .{ self.resources.pies }
            ) catch "inf";
            try ui.addPlainWidget(
                screen.cutVertical(
                    ui.measureText(pies_value, font_size),
                    label_spacing
                ),
                .{ .label = .{ .text = pies_value, .size = font_size } }
            );

            const tart_value = std.fmt.bufPrintZ(
                self.tarts_buffer[0..],
                "Tarts: {d}",
                .{ self.resources.tarts }
            ) catch "inf";
            try ui.addPlainWidget(
                screen.cutVertical(
                    ui.measureText(tart_value, font_size),
                    label_spacing
                ),
                .{ .label = .{ .text = tart_value, .size = font_size } }
            );
        }
        // Improvements counters
        {
            const tart_bakers = std.fmt.bufPrintZ(
                self.tarts_baker_buffer[0..],
                "Tart Bakers: {d}", .{ self.improvements.tarts }
            ) catch "inf";
            try ui.addPlainWidget(
                screen.cutVertical(
                    -ui.measureText(tart_bakers, font_size),
                    label_spacing
                ),
                .{ .label = .{ .text = tart_bakers, .size = font_size } }
            );
            const pie_bakers = std.fmt.bufPrintZ(
                self.pies_baker_buffer[0..],
                "Pie Bakers: {d}", .{ self.improvements.pies }
            ) catch "inf";
            try ui.addPlainWidget(
                screen.cutVertical(
                    -ui.measureText(pie_bakers, font_size),
                    label_spacing
                ),
                .{ .label = .{ .text = pie_bakers, .size = font_size } }
            );

            const cake_bakers = std.fmt.bufPrintZ(
                self.cakes_baker_buffer[0..],
                "Cake Bakers: {d}", .{ self.improvements.cakes }
            ) catch "inf";
            try ui.addPlainWidget(
                screen.cutVertical(
                    -ui.measureText(cake_bakers, font_size),
                    label_spacing
                ),
                .{ .label = .{ .text = cake_bakers, .size = font_size } }
            );

            const cookie_bakers = std.fmt.bufPrintZ(
                self.cookie_baker_buffer[0..],
                "Cookie Bakers: {d}", .{ self.improvements.cookies }
            ) catch "inf";
            try ui.addPlainWidget(
                screen.cutVertical(
                    -ui.measureText( cookie_bakers, font_size ),
                    label_spacing
                ),
                .{ .label = .{ .text = cookie_bakers, .size = font_size } }
            );
        }
    }
    pub fn draw (self : *const @This()) void {
        self.interface.draw();
    }
};
const BakeButton = struct {
    const Ui = cake.FixedUi(
        .{
            .Widget = cake.widgets.TextDisplay,
            .Behavior = cake.behaviors.Button(BakeEvent),
            .UiEvent = BakeEvent,
        },
        1
    );
    interface : Ui = Ui{ .theme = cake.theme_light },
    label : [:0]const u8 = "Bake",

    pub fn uiLayout (self : *@This()) ! void {
        const ui = self.interface.layout();
        var location = ui.windowArea();
        location = location.cutVerticalPercent(0.5, 0);
        const size = ui.measureText(self.label, font_size);
        location.shrinkTo(@splat(size * 2));

        try ui.addBehavingWidget(
            location,
            .{ .text = self.label, .size = font_size },
            .{ .event = .bake }
        );
    }
    pub fn click (self : *@This(), mouse : cake.Vector) bool {
        self.interface.setPointerPosition(mouse);
        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            try self.interface.sendPointerEvent(.{ .press = .left });
        }
        if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_LEFT)) {
            try self.interface.sendPointerEvent(.{ .lift = .left });
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
    const Ui = cake.FixedUi(
        .{
            .UiEvent = PastryType,
            .WidgetIdentity = PastryType,
            .Behavior = cake.behaviors.Button(PastryType),
        },
        5
    );
    const label_cookie = "Hire Cookie Baker";
    const label_cakes  = "Hire Cake Baker";
    const label_pies   = "Hire Pie Baker";
    const label_tarts  = "Hire Tart Baker";

    interface : Ui = Ui { .theme = cake.theme_light },
    resources : *Resources,
    costs : *Resources,
    next_costs : *Resources,
    improvements : *Resources,

    pub fn uiLayout (self : *@This()) ! void {
        const ui = self.interface.layout();

        const cookie_size = ui.measureText(label_cookie , font_size);
        const cake_size   = ui.measureText(label_cakes  , font_size);
        const pie_size    = ui.measureText(label_pies   , font_size);
        const tart_size   = ui.measureText(label_tarts  , font_size);

        const max_width   = @max(@max(cookie_size, cake_size), @max(pie_size, tart_size));
        const button_size = font_size + 16;
        const spacing     = font_size * 0.5;

        var location = ui.windowArea();
        location = location.cutVerticalPercent(-0.5, 0);
        location.shrinkTo(.{ max_width + 16, button_size * 4 + spacing * 5 });

        try ui.addPlainWidget(
            location,
            .{ .background = .{} }
        );

        location.shrinkWidthTo(max_width + 8);
        location.size[1] = button_size;
        location.move(.{ 0, spacing });

        try ui.addWidget(
            location,
            .{ .display = .{ .text = label_cookie, .size = font_size }},
            .{ .event = .cookies },
            .{ .theme = .interactive, .identity = .cookies }
        );

        location.move(.{ 0, button_size + spacing });
        try ui.addWidget(
            location,
            .{ .display = .{ .text = label_cakes, .size = font_size } },
            .{ .event = .cakes },
            .{ .theme = .interactive, .identity = .cakes }
        );

        location.move(.{ 0, button_size + spacing });
        try ui.addWidget(
            location,
            .{ .display = .{ .text = label_pies, .size = font_size } },
            .{ .event = .pies },
            .{ .theme = .interactive, .identity = .pies }
        );

        location.move(.{ 0, button_size + spacing });
        try ui.addWidget(
            location,
            .{ .display = .{ .text = label_tarts, .size = font_size } },
            .{ .event = .tarts },
            .{ .theme = .interactive, .identity = .tarts }
        );
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
            .WidgetTheme = SingleTheme,
            .UiColorPalette = cake.FixedPallete(SingleTheme),
            .Widget = cake.widgets.TextDisplay,
        },
        1
    );
    const reset_timer = 3;

    interface : Ui = .{
        .theme = .{
            .schemes = [_]cake.ColorScheme{
                cake.ColorScheme.contrastingBase(.{ .r = 140, .g = 100, .b = 100 })
            }
        }
    },
    text : [:0]const u8 = "",
    timer : f32 = -1,
    window : ?*WarningWindow = null,

    pub fn uiLayout (self : *@This()) ! void {
        var ui = self.interface.layout();
        var screen = ui.windowArea();
        screen = screen.cutHorizontalPercent(-0.2, 0);
        screen.shrinkBy(@splat(10));
        try ui.addPlainWidget(screen, .{ .text = self.text, .size = font_size });
    }
    pub fn draw (self : *const @This()) void {
        if (self.timer > 0) {
            self.interface.draw();
        }
    }

    pub fn tickDown (self : *@This()) void {
        self.timer -= ray.GetFrameTime();
    }
    pub fn warn (self : *@This(), warning : [:0]const u8) ! void {
        self.timer = reset_timer;
        self.text = warning;
        try self.uiLayout();
    }
};
