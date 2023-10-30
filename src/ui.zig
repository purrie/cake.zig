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
                        self.ui.focus = &self.ui.widgets[self.ui.len];
                    }
                }
                if (self.active) |a| {
                    if (config.identity == a) {
                        self.ui.active = &self.ui.widgets[self.ui.len];
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
                return cake.backend.measureText(text, font_size);
            }
            pub fn windowArea (self : LayoutContext) Rectangle {
                _ = self;
                return cake.backend.windowArea();
            }
        };

        theme : context.ColorPalette,

        widgets  : [size]Widget = undefined,

        pointer : ?Vector = null,
        len    : usize = 0,
        hover  : ?*Widget = null,
        focus  : ?*Widget = null,
        active : ?*Widget = null,
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
                .focus = if (self.focus) |f| f.meta.identity else null,
                .active = if (self.active) |a| a.meta.identity else null,
            };
        }
        pub fn setPointerPosition (self : *Ui, position : ?Vector) void {
            self.pointer = position;
            if (position) |pos| {
                if (self.hover) |hov| {
                    if (hov.interface.containsPoint(pos)) {
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
                    self.hover = widget;
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
                const state = self.widgetState(widget);
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
                    .isActive = &isActive,
                    .sendEvent = &sendEvent,
                }
            };

            for (1..self.len + 1) |backwalk| {
                const idx = self.len - backwalk;
                const widget = &self.widgets[idx];
                if (widget.interface.containsPoint(cursor) == false) {
                    continue;
                }
                const behavior_context = types.BehaviorContext{
                    .position = cursor,
                    .pointer = pointer,
                    .keyboard = keyboard,
                };
                const result = try widget.interface.inputEvent(ui, behavior_context);
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
                    .isActive = &isActive,
                    .sendEvent = &sendEvent,
                }
            };

            for (1..self.len + 1) |backwalk| {
                const idx = self.len - backwalk;
                var widget = &self.widgets[idx];
                if (widget.interface.containsPoint(pointer) == false) {
                    continue;
                }
                const state = self.widgetState(widget);
                const result = try widget.interface.pointerEvent(ui, pointer, event, state);
                switch (result) {
                    .activated => {
                        self.active = widget;
                        self.focus = widget;
                        return;
                    },
                    .deactivated => {
                        self.active = null;
                        return;
                    },
                    .focused => {
                        if (self.active != widget) {
                            self.active = null;
                        }
                        self.focus = widget;
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
                        .isActive = &isActive,
                        .sendEvent = &sendEvent,
                    }
                };
                const state = self.widgetState(focus);
                try focus.interface.keyboardEvent(ui, event, state);
            }
        }
        pub fn popEvent (self : *Ui) ?context.Event {
            defer self.event = null;
            return self.event;
        }
        pub fn getHoveredWidget (self : *Ui) ?*Widget {
            return self.hover;
        }
        pub fn getFocusedWidget (self : *Ui) ?*Widget {
            return self.focus;
        }
        pub fn getActiveWidget (self : *Ui) ?*Widget {
            return self.active;
        }
        pub fn getWidget (self : *Ui, id : context.Identity) ?*Widget {
            for (self.widgets[0..self.len]) |*w| {
                if (w.meta.identity == id)
                    return w;
            }
            return null;
        }

        fn widgetState (self : *const Ui, widget : *const Widget) DrawState {
            return if (widget.interface.isInteractive()) flt: {
                const over = self.hover == widget;
                break :flt .{
                    .focus = widget == self.focus,
                    .active = widget == self.active,
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
        fn isActive (ptr : *const anyopaque, widget_interface_ptr : *const anyopaque) bool {
            const self : *const Ui = @ptrCast(@alignCast(ptr));
            const active = self.active orelse return false;
            return active.interface.context == widget_interface_ptr;
        }
    };
}
