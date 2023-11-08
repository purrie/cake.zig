const std = @import("std");
const cake = @import("cake.zig");
const types = @import("types.zig");
const style = @import("style.zig");
const widgets = cake.widgets;
const log = std.log.scoped(.cake);
const interface = @import("interface.zig");

const Rectangle = @import("Rectangle.zig");
const Size = types.Size;
const Vector = types.Vector;
const DrawState = types.WidgetState;
const ColorScheme = types.ColorScheme;
const KeyboardEvent = types.KeyboardEvent;

pub const UIContext = struct {
    Theme        : type = style.DefaultTheme,
    ColorPalette : type = style.DefaultPalette,

    Identity     : type = void,
    Event        : type = void,
};

pub fn UserInterface (comptime Renderer : type) type {
    return struct {
        pub fn FixedUi (
            comptime context : UIContext,
            comptime size : usize,
        ) type {
            const default_widget_theme = if (@hasDecl(context.Theme, "default"))
                context.Theme.default()
            else
                switch (@typeInfo(context.Theme)) {
                    .Enum => |en| ret: {
                        break :ret @as(context.Theme, @enumFromInt(en.fields[0].value));
                    },
                    .Struct => |st| ret: {
                        for (st.fields) |f| {
                            if (f.default_value == null) {
                                @compileError("Widget Theme struct must either give all fields default value or have .default() function");
                            }
                        }
                        break :ret context.Theme{};
                    },
                    else => @compileError("Widget Theme must be a supported type or have .default() function to produce default value"),
                };
            const WidgetIdentity = if (context.Identity == void)
                void else ?context.Identity;

            const default_identity = if (context.Identity == void)
                {} else null;

            return struct {
                const Ui = @This();
                pub const Context = context;
                pub const Widget = struct {
                    pub const Metadata = struct {
                        theme : context.Theme = default_widget_theme,
                        identity : WidgetIdentity = default_identity,
                    };

                    interface : interface.Widget,
                    meta : Metadata = .{},
                };
                pub const LayoutContext = struct {
                    ui : *Ui,
                    focus : ?context.Identity,
                    active : ?context.Identity,

                    pub fn addWidget (
                        self : LayoutContext,
                        widget : interface.Widget,
                        config : Widget.Metadata,
                    ) ! void {
                        if (self.ui.len >= size) return error.OutOfMemory;
                        self.ui.widgets[self.ui.len] = Widget{
                            .interface = widget,
                            .meta = config,
                        };
                        if (self.focus) |f| {
                            if (config.identity == f) {
                                self.ui.focus = self.ui.len;
                            }
                        }
                        if (self.active) |a| {
                            if (config.identity == a) {
                                self.ui.active = self.ui.len;
                            }
                        }
                        self.ui.len += 1;
                    }
                    pub fn addPlainWidget (
                        self : LayoutContext,
                        widget : interface.Widget,
                    ) ! void {
                        if (self.ui.len >= size) return error.OutOfMemory;
                        self.ui.widgets[self.ui.len] = Widget{
                            .interface = widget,
                        };
                        self.ui.len += 1;
                    }
                    pub fn measureText (self : LayoutContext, text : []const u8, font_size : f32) f32 {
                        _ = self;
                        return Renderer.measureText(text, font_size);
                    }
                    pub fn windowArea (self : LayoutContext) Rectangle {
                        _ = self;
                        return Renderer.windowArea();
                    }
                };

                theme : context.ColorPalette,

                widgets  : [size]Widget = undefined,

                pointer : ?Vector = null,
                len    : usize = 0,
                hover  : ?usize = null,
                focus  : ?usize = null,
                active : ?usize = null,
                event  : ?context.Event = null,

                pub fn init (theme : context.ColorPalette) Ui {
                    return .{
                        .theme = theme,
                    };
                }
                pub fn layout (self : *Ui) LayoutContext {
                    self.len = 0;
                    self.hover = null;
                    defer self.focus = null;
                    defer self.active = null;
                    return LayoutContext{
                        .ui = self,
                        .focus = if (self.focus) |f| self.widgets[f].meta.identity else null,
                        .active = if (self.active) |a| self.widgets[a].meta.identity else null,
                    };
                }
                pub fn setPointerPosition (self : *Ui, position : ?Vector) ! void {
                    defer self.pointer = position;
                    if (position) |pos| {
                        // handle drag mouse event
                        if (self.active) |act| evnt: {
                            const ptr = self.pointer orelse break :evnt;
                            if (@reduce(.And, ptr == pos)) break :evnt;
                            const ui = interface.Ui {
                                .context = self,
                                .vtable = .{
                                    .sendEvent = &sendEvent,
                                }
                            };
                            const widget = &self.widgets[act];
                            const state = self.widgetState(widget, act);
                            const result = try widget.interface.pointerEvent(ui, pos, .{ .drag = pos - ptr }, state);
                            switch (result) {
                                .activated => {},
                                .deactivated => self.active = null,
                                .focused => {},
                                .unfocused => {
                                    self.active = null;
                                    self.focus = null;
                                },
                                .processed => {},
                                .ignored => {},
                            }
                        }

                        // handle updating which widget has focus
                        if (self.hover) |hov| {
                            const widget = &self.widgets[hov];
                            if (widget.interface.containsPoint(pos)) {
                                return;
                            }
                        }
                        for (1..self.len + 1) |backwalk| {
                            const idx = self.len - backwalk;
                            var widget = &self.widgets[idx];

                            if (widget.interface.isInteractive() == false) {
                                continue;
                            }
                            if (widget.interface.containsPoint(pos) == false) {
                                continue;
                            }
                            self.hover = idx;
                            break;
                        } else {
                            self.hover = null;
                        }
                    }
                    else {
                        self.hover = null;
                    }
                }
                pub fn draw (self : *const Ui) void {
                    for (0..self.len) |i| {
                        const widget = &self.widgets[i];
                        const state = self.widgetState(widget, i);
                        const colors = if (@hasDecl(context.Theme, "getColorScheme")) col: {
                            if (@typeInfo(context.ColorPalette) == .Pointer)
                                break :col widget.meta.theme.getColorScheme(self.theme)
                            else
                                break :col widget.meta.theme.getColorScheme(&self.theme);
                        } else col: {
                            break :col self.theme.getColors(widget.meta.theme);
                        };
                        widget.interface.draw(self.pointer, colors, state);
                    }
                }
                pub fn sendInputEvent (self : *Ui, pointer : types.PointerEvent, keyboard : KeyboardEvent) ! void {
                    const cursor = self.pointer orelse return error.NoPointerPosition;
                    const ui = interface.Ui {
                        .context = self,
                        .vtable = .{
                            .sendEvent = &sendEvent,
                        }
                    };

                    for (1..self.len + 1) |backwalk| {
                        const idx = self.len - backwalk;
                        const widget = &self.widgets[idx];
                        if (widget.interface.containsPoint(cursor) == false) {
                            continue;
                        }
                        const state = self.widgetState(widget, idx);
                        const result = try widget.interface.inputEvent(
                            ui,
                            cursor,
                            pointer,
                            keyboard,
                            state
                        );
                        switch (result) {
                            .activated => {
                                self.active = idx;
                                self.focus = idx;
                                return;
                            },
                            .deactivated => {
                                self.active = null;
                                return;
                            },
                            .focused => {
                                if (self.active != idx) {
                                    self.active = null;
                                }
                                self.focus = idx;
                                return;
                            },
                            .unfocused => {
                                self.active = null;
                                self.focus = null;
                                return;
                            },
                            .processed => return,
                            .ignored => {},
                        }
                    }
                    self.active = null;
                    self.focus = null;
                }
                pub fn sendPointerEvent (self : *Ui, event : types.PointerEvent) ! void {
                    const pointer = self.pointer orelse return error.NoPointerPosition;
                    const ui = interface.Ui {
                        .context = self,
                        .vtable = .{
                            .sendEvent = &sendEvent,
                        }
                    };

                    for (1..self.len + 1) |backwalk| {
                        const idx = self.len - backwalk;
                        var widget = &self.widgets[idx];
                        if (widget.interface.containsPoint(pointer) == false) {
                            continue;
                        }
                        const state = self.widgetState(widget, idx);
                        const result = try widget.interface.pointerEvent(ui, pointer, event, state);
                        switch (result) {
                            .activated => {
                                self.active = idx;
                                self.focus = idx;
                                return;
                            },
                            .deactivated => {
                                self.active = null;
                                return;
                            },
                            .focused => {
                                if (self.active != idx) {
                                    self.active = null;
                                }
                                self.focus = idx;
                                return;
                            },
                            .unfocused => {
                                self.active = null;
                                self.focus = null;
                                return;
                            },
                            .processed => return,
                            .ignored => {},
                        }
                    }
                    self.active = null;
                    self.focus = null;
                }
                pub fn sendKeyboardEvent (self : *Ui, event : KeyboardEvent) ! void {
                    if (self.focus) |focus| {
                        const ui = interface.Ui {
                            .context = self,
                            .vtable = .{
                                .sendEvent = &sendEvent,
                            }
                        };
                        var widget = &self.widgets[focus];
                        const state = self.widgetState(widget, focus);
                        try widget.interface.keyboardEvent(ui, event, state);
                    }
                }
                pub fn popEvent (self : *Ui) ?context.Event {
                    defer self.event = null;
                    return self.event;
                }
                pub fn getHoveredWidget (self : *Ui) ?*Widget {
                    const idx = self.hover orelse return null;
                    return &self.widgets[idx];
                }
                pub fn getFocusedWidget (self : *Ui) ?*Widget {
                    const idx = self.focus orelse return null;
                    return &self.widgets[idx];
                }
                pub fn getActiveWidget (self : *Ui) ?*Widget {
                    const idx = self.active orelse return null;
                    return &self.widgets[idx];
                }
                pub fn getWidget (self : *Ui, id : context.Identity) ?*Widget {
                    for (self.widgets[0..self.len]) |*w| {
                        if (w.meta.identity == id)
                            return w;
                    }
                    return null;
                }

                fn widgetState (self : *const Ui, widget : *const Widget, idx : usize) DrawState {
                    return if (widget.interface.isInteractive()) flt: {
                        const over = self.hover == idx;
                        break :flt .{
                            .focus = idx == self.focus,
                            .active = idx == self.active,
                            .hover = over,
                            .normal = !over,
                        };
                    }
                    else flt: {
                        break :flt .{
                            .focus = false,
                            .hover = false,
                            .active = false
                        };
                    };
                }
                fn sendEvent (ptr : *anyopaque, event_ptr : *const anyopaque) void {
                    var self : *Ui = @ptrCast(@alignCast(ptr));
                    const event : *const context.Event = @ptrCast(@alignCast(event_ptr));
                    self.event = event.*;
                }
            };
        }

        pub fn DynamicUi ( comptime context : UIContext ) type {
            const default_widget_theme = if (@hasDecl(context.Theme, "default"))
                context.Theme.default()
            else
                switch (@typeInfo(context.Theme)) {
                    .Enum => |en| ret: {
                        break :ret @as(context.Theme, @enumFromInt(en.fields[0].value));
                    },
                    .Struct => |st| ret: {
                        for (st.fields) |f| {
                            if (f.default_value == null) {
                                @compileError("Widget Theme struct must either give all fields default value or have .default() function");
                            }
                        }
                        break :ret context.Theme{};
                    },
                    else => @compileError("Widget Theme must be a supported type or have .default() function to produce default value"),
                };
            const WidgetIdentity = if (context.Identity == void)
                void else ?context.Identity;

            const default_identity = if (context.Identity == void)
                {} else null;
            return struct {
                const Ui = @This();
                pub const Widget = struct {
                    pub const Metadata = struct {
                        theme : context.Theme = default_widget_theme,
                        identity : WidgetIdentity = default_identity,
                    };

                    interface : interface.Widget,
                    meta : Metadata = .{}
                };
                pub const WidgetList = std.ArrayList(Widget);
                pub const LayoutContext = struct {
                    ui : *Ui,
                    focus : ?context.Identity,
                    active : ?context.Identity,

                    pub fn addWidget (
                        self : LayoutContext,
                        widget : interface.Widget,
                        config : Widget.Metadata,
                    ) ! void {
                        var w = try self.ui.widgets.addOne();
                        w.* = Widget{
                            .interface = widget,
                            .meta = config,
                        };
                        if (self.focus) |f| {
                            if (config.identity == f) {
                                self.ui.focus = self.ui.widgets.items.len - 1;
                            }
                        }
                        if (self.active) |a| {
                            if (config.identity == a) {
                                self.ui.active = self.ui.widgets.items.len - 1;
                            }
                        }
                    }
                    pub fn addPlainWidget (
                        self : LayoutContext,
                        widget : interface.Widget,
                    ) ! void {
                        var w = try self.ui.widgets.addOne();
                        w.* = Widget{
                            .interface = widget,
                        };
                    }
                    pub fn measureText (self : LayoutContext, text : []const u8, font_size : f32) f32 {
                        _ = self;
                        return Renderer.measureText(text, font_size);
                    }
                    pub fn windowArea (self : LayoutContext) Rectangle {
                        _ = self;
                        return Renderer.windowArea();
                    }
                };

                theme : context.ColorPalette,
                allocator : std.mem.Allocator,

                widgets : WidgetList,

                pointer : ?Vector = null,
                hover  : ?usize = null,
                focus  : ?usize = null,
                active : ?usize = null,
                event  : ?context.Event = null,

                pub fn init (theme : context.ColorPalette, allocator : std.mem.Allocator) Ui {
                    return Ui {
                        .allocator = allocator,
                        .theme = theme,
                        .widgets = WidgetList.init(allocator),
                    };
                }
                pub fn deinit (self : *Ui) void {
                    self.widgets.deinit();
                    self.* = undefined;
                }
                pub fn layout (self : *Ui) LayoutContext {
                    const focus = if (self.focus) |f| self.widgets.items[f].meta.identity else null;
                    const active = if (self.active) |f| self.widgets.items[f].meta.identity else null;
                    self.widgets.clearRetainingCapacity();

                    self.hover = null;
                    self.focus = null;
                    self.active = null;
                    return LayoutContext {
                        .ui = self,
                        .focus = focus,
                        .active = active,
                    };
                }
                pub fn setPointerPosition (self : *Ui, position : ?Vector) ! void {
                    defer self.pointer = position;
                    if (position) |pos| {
                        // handle drag mouse event
                        if (self.active) |act| evnt: {
                            const ptr = self.pointer orelse break :evnt;
                            if (@reduce(.And, ptr == pos)) break :evnt;

                            const ui = interface.Ui {
                                .context = self,
                                .vtable = .{
                                    .sendEvent = &sendEvent,
                                }
                            };
                            const widget = &self.widgets.items[act];
                            const state = self.widgetState(widget, act);
                            const result = try widget.interface.pointerEvent(ui, pos, .{ .drag = pos - ptr }, state);
                            switch (result) {
                                .activated => {},
                                .deactivated => self.active = null,
                                .focused => {},
                                .unfocused => {
                                    self.active = null;
                                    self.focus = null;
                                },
                                .processed => {},
                                .ignored => {},
                            }
                        }

                        // handle updating which widget has focus
                        if (self.hover) |hov| {
                            const widget = &self.widgets.items[hov];
                            if (widget.interface.containsPoint(pos)) {
                                return;
                            }
                        }
                        for (1..self.widgets.items.len + 1) |backwalk| {
                            const idx = self.widgets.items.len - backwalk;
                            var widget = &self.widgets.items[idx];

                            if (widget.interface.isInteractive() == false) {
                                continue;
                            }
                            if (widget.interface.containsPoint(pos) == false) {
                                continue;
                            }
                            self.hover = backwalk;
                            break;
                        } else {
                            self.hover = null;
                        }
                    }
                    else {
                        self.hover = null;
                    }
                }
                pub fn draw (self : *const Ui) void {
                    for (self.widgets.items, 0..) |*widget, i| {
                        const state = self.widgetState(widget, i);
                        const colors = if (@hasDecl(context.Theme, "getColorScheme")) col: {
                            if (@typeInfo(context.ColorPalette) == .Pointer)
                                break :col widget.meta.theme.getColorScheme(self.theme)
                            else
                                break :col widget.meta.theme.getColorScheme(&self.theme);
                        } else col: {
                            break :col self.theme.getColors(widget.meta.theme);
                        };
                        widget.interface.draw(self.pointer, colors, state);
                    }
                }
                pub fn sendInputEvent (self : *Ui, pointer : types.PointerEvent, keyboard : KeyboardEvent) ! void {
                    const cursor = self.pointer orelse return error.NoPointerPosition;
                    const ui = interface.Ui {
                        .context = self,
                        .vtable = .{
                            .sendEvent = &sendEvent,
                        }
                    };

                    for (1..self.widgets.items.len + 1) |backwalk| {
                        const idx = self.len - backwalk;
                        const widget = &self.widgets.items[idx];
                        if (widget.interface.containsPoint(cursor) == false) {
                            continue;
                        }
                        const state = self.widgetState(widget, idx);
                        const result = try widget.interface.inputEvent(
                            ui,
                            cursor,
                            pointer,
                            keyboard,
                            state
                        );
                        switch (result) {
                            .activated => {
                                self.active = idx;
                                self.focus = idx;
                                return;
                            },
                            .deactivated => {
                                self.active = null;
                                return;
                            },
                            .focused => {
                                if (self.active != idx) {
                                    self.active = null;
                                }
                                self.focus = idx;
                                return;
                            },
                            .unfocused => {
                                self.active = null;
                                self.focus = null;
                                return;
                            },
                            .processed => return,
                            .ignored => {},
                        }
                    }
                    self.active = null;
                    self.focus = null;
                }
                pub fn sendPointerEvent (self : *Ui, event : types.PointerEvent) ! void {
                    const pointer = self.pointer orelse return error.NoPointerPosition;
                    const ui = interface.Ui {
                        .context = self,
                        .vtable = .{
                            .sendEvent = &sendEvent,
                        }
                    };

                    for (1..self.widgets.items.len + 1) |backwalk| {
                        const idx = self.widgets.items.len - backwalk;
                        var widget = &self.widgets.items[idx];
                        if (widget.interface.containsPoint(pointer) == false) {
                            continue;
                        }
                        const state = self.widgetState(widget, idx);
                        const result = try widget.interface.pointerEvent(ui, pointer, event, state);
                        switch (result) {
                            .activated => {
                                self.active = idx;
                                self.focus = idx;
                                return;
                            },
                            .deactivated => {
                                self.active = null;
                                return;
                            },
                            .focused => {
                                if (self.active != idx) {
                                    self.active = null;
                                }
                                self.focus = idx;
                                return;
                            },
                            .unfocused => {
                                self.active = null;
                                self.focus = null;
                                return;
                            },
                            .processed => return,
                            .ignored => {},
                        }
                    }
                    self.active = null;
                    self.focus = null;
                }
                pub fn sendKeyboardEvent (self : *Ui, event : KeyboardEvent) ! void {
                    if (self.focus) |focus| {
                        const ui = interface.Ui {
                            .context = self,
                            .vtable = .{
                                .sendEvent = &sendEvent,
                            }
                        };
                        const state = self.widgetState(focus);
                        var widget = &self.widgets.items[focus];
                        try widget.interface.keyboardEvent(ui, event, state);
                    }
                }
                pub fn popEvent (self : *Ui) ?context.Event {
                    defer self.event = null;
                    return self.event;
                }
                pub fn getHoveredWidget (self : *Ui) ?*Widget {
                    const idx = self.hover orelse return null;
                    return &self.widgets[idx];
                }
                pub fn getFocusedWidget (self : *Ui) ?*Widget {
                    const idx = self.focus orelse return null;
                    return &self.widgets[idx];
                }
                pub fn getActiveWidget (self : *Ui) ?*Widget {
                    const idx = self.active orelse return null;
                    return &self.widgets[idx];
                }
                pub fn getWidget (self : *Ui, id : context.Identity) ?*Widget {
                    for (self.widgets.items) |*w| {
                        if (w.meta.identity == id)
                            return w;
                    }
                    return null;
                }

                fn widgetState (self : *const Ui, widget : *const Widget, idx : usize) DrawState {
                    return if (widget.interface.isInteractive()) flt: {
                        const over = self.hover == idx;
                        break :flt .{
                            .focus = idx == self.focus,
                            .active = idx == self.active,
                            .hover = over,
                            .normal = !over,
                        };
                    }
                    else flt: {
                        break :flt .{
                            .focus = false,
                            .hover = false,
                            .active = false
                        };
                    };
                }
                fn sendEvent (ptr : *anyopaque, event_ptr : *const anyopaque) void {
                    var self : *Ui = @ptrCast(@alignCast(ptr));
                    const event : *const context.Event = @ptrCast(@alignCast(event_ptr));
                    self.event = event.*;
                }
            };
        }
    };
}
