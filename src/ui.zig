const std = @import("std");
const cake = @import("cake.zig");
const types = @import("types.zig");
const style = @import("style.zig");
const widgets = cake.widgets;
const log = std.log.scoped(.cake);

const Rectangle = @import("Rectangle.zig");
const Size = types.Size;
const Vector = types.Vector;
const DrawState = types.DrawState;
const ColorScheme = types.ColorScheme;
const KeyboardEvent = types.KeyboardEvent;

pub const Context = struct {
    Widget   : type = widgets.BuiltinWidgets,
    Behavior : type = void,

    WidgetTheme    : type = style.DefaultTheme,
    UiColorPalette : type = style.DefaultPalette,

    WidgetIdentity : type = void,
    UiEvent        : type = void,
    UserData       : type = void,
};

pub fn FixedUi (
    comptime context : Context,
    comptime size : usize,
) type {
    const default_widget_theme = if (@hasDecl(context.WidgetTheme, "default"))
        context.WidgetTheme.default()
    else
        switch (@typeInfo(context.WidgetTheme)) {
            .Enum => |en| ret: {
                break :ret @as(context.WidgetTheme, @enumFromInt(en.fields[0].value));
            },
            .Struct => |st| ret: {
                for (st.fields) |f| {
                    if (f.default_value == null) {
                        @compileError("Widget Theme struct must either give all fields default value or have .default() function");
                    }
                }
                break :ret context.WidgetTheme{};
            },
            else => @compileError("Widget Theme must be a supported type or have .default() function to produce default value"),
        };

    return struct {
        const Ui = @This();
        pub const Widget = struct {
            pub const Metadata = struct {
                theme : context.WidgetTheme = default_widget_theme,
                identity : ?context.WidgetIdentity = null,
                user_data : ?context.UserData = null,
            };

            area : Rectangle,
            look : context.Widget,
            behavior : ?context.Behavior = null,
            meta : Metadata = .{},
        };
        pub const UiContext = context;
        pub const LayoutContext = struct {
            ui : *Ui,
            focus : ?context.WidgetIdentity,
            active : ?context.WidgetIdentity,

            pub fn addWidget (
                self : LayoutContext,
                area : Rectangle,
                widget : context.Widget,
                behavior : context.Behavior,
                config : Widget.Metadata,
            ) ! void {
                if (self.ui.len >= size) return error.OutOfMemory;
                try validateBehaviors(&widget, &behavior);
                self.ui.widgets[self.ui.len] = Widget{
                    .behavior = behavior,
                    .look = widget,
                    .meta = config,
                    .area = area,
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
                area : Rectangle,
                widget : context.Widget,
            ) ! void {
                if (self.ui.len >= size) return error.OutOfMemory;
                self.ui.widgets[self.ui.len] = Widget{
                    .look = widget,
                    .area = area,
                };
                self.ui.len += 1;
            }
            pub fn addRichWidget (
                self : LayoutContext,
                area : Rectangle,
                widget : context.Widget,
                config : Widget.Metadata,
            ) ! void {
                if (self.ui.len >= size) return error.OutOfMemory;
                self.ui.widgets[self.ui.len] = Widget{
                    .look = widget,
                    .area = area,
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
            pub fn addBehavingWidget (
                self : LayoutContext,
                area : Rectangle,
                widget : context.Widget,
                behavior : context.Behavior,
            ) ! void {
                if (self.ui.len >= size) return error.OutOfMemory;
                try validateBehaviors(&widget, &behavior);
                self.ui.widgets[self.ui.len] = Widget{
                    .look = widget,
                    .area = area,
                    .behavior = behavior,
                };
                self.ui.len += 1;
            }
            pub fn measureText (self : LayoutContext, text : []const u8, font_size : f32) f32 {
                _ = self;
                return cake.backend.view.measureText(text, font_size);
            }
            pub fn windowArea (self : LayoutContext) Rectangle {
                _ = self;
                return cake.backend.view.windowArea();
            }
        };

        theme : context.UiColorPalette,

        widgets  : [size]Widget = undefined,

        pointer : ?Vector = null,
        len    : usize = 0,
        hover  : ?*Widget = null,
        focus  : ?*Widget = null,
        active : ?*Widget = null,
        event  : ?context.UiEvent = null,

        pub fn init (theme : context.UiColorPalette) Ui {
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
                for (1..self.len + 1) |backwalk| {
                    const idx = self.len - backwalk;
                    var widget = &self.widgets[idx];

                    if (widget.behavior == null) {
                        continue;
                    }
                    if (widget.area.contains(pos) == false) {
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
                handleDrawingWidget(self, &self.widgets[i]);
            }
        }
        pub fn sendInputEvent (self : *Ui, pointer : types.PointerEvent, keyboard : KeyboardEvent) ! void {
            if (self.pointer == null) return;

            for (1..self.len + 1) |backwalk| {
                const idx = self.len - backwalk;
                const meta = &self.metadata[idx];
                if (meta.interaction == null and meta.can_focus == false) {
                    continue;
                }
                if (self.zones[idx].contains(self.pointer.?) == false) {
                    continue;
                }

                const result = try handleInputEvent(
                    self,
                    &self.widgets[idx].behavior,
                    &self.widgets[idx].look,
                    types.BehaviorContext{
                        .area = self.widgets[idx].area,
                        .position = self.pointer,
                        .pointer = pointer,
                        .keyboard = keyboard,
                    },
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
            if (self.pointer == null) return;

            for (1..self.len + 1) |backwalk| {
                const idx = self.len - backwalk;
                var widget = &self.widgets[idx];
                if (widget.behavior == null) {
                    continue;
                }
                if (widget.area.contains(self.pointer.?) == false) {
                    continue;
                }

                const result = try handlePointerEvent(
                    self,
                    &widget.behavior.?,
                    &widget.look,
                    types.PointerContext{
                        .area = widget.area,
                        .position = self.pointer.?,
                        .pointer = event,
                    }
                );
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
                if (focus.behavior) |*beh| {
                    const keyboard = types.KeyboardContext{
                        .area = focus.area,
                        .keyboard = event,
                    };
                    try handleKeyboardEvent(self, beh, &focus.look, keyboard);
                }
            }
        }
        pub fn popEvent (self : *Ui) ?context.UiEvent {
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
        pub fn getWidget (self : *Ui, id : context.WidgetIdentity) ?*Widget {
            for (self.widgets[0..self.len]) |*w| {
                if (w.meta.identity == id)
                    return w;
            }
            return null;
        }
        pub fn isFocused (self : *Ui, behavior : *anyopaque) bool {
            const focus = self.focus orelse return false;
            if (focus.behavior == null) return false;
            const beh : *anyopaque = &focus.behavior.?;

            const ptr : usize = @intFromPtr(beh);
            const end : usize = @max(1, @sizeOf(context.Behavior)) + ptr;
            const bep : usize = @intFromPtr(behavior);
            return bep >= ptr and bep < end;
        }
        pub fn isActive (self : *Ui, behavior : *anyopaque) bool {
            const active = self.active orelse return false;
            if (active.behavior == null) return false;
            const beh : *anyopaque = &active.behavior.?;

            const ptr : usize = @intFromPtr(beh);
            const end : usize = @max(1, @sizeOf(context.Behavior)) + ptr;
            const bep : usize = @intFromPtr(behavior);
            return bep >= ptr and bep < end;
        }
    };
}

/// Handles drawing a widget, calculating its state, colors and other context information
pub fn handleDrawingWidget (ui : anytype, widget : anytype) void {
    if (@typeInfo(@TypeOf(widget)) != .Pointer) @compileError("Widget must be passed by pointer");

    const over = ui.hover == widget;

    var draw_filter = DrawState{
        .focus = widget == ui.focus,
        .active = widget == ui.active,
        .hover = over,
        .normal = !over,
    };

    if (widget.behavior == null) {
        draw_filter = .{
            .focus = false,
            .hover = false,
            .active = false
        };
    }
    const ui_context = @TypeOf(ui.*).UiContext;
    const colors = if (@hasDecl(ui_context.WidgetTheme, "getColorScheme")) col: {
        if (@typeInfo(ui_context.UiColorPalette) == .Pointer)
            break :col widget.meta.theme.getColorScheme(ui.theme)
        else
            break :col widget.meta.theme.getColorScheme(&ui.theme);
    } else col: {
        break :col ui.theme.getColors(widget.meta.theme);
    };
    const context = types.DrawingContext{
        .area = widget.area,
        .colors = colors,
        .state = draw_filter,
        .position = ui.pointer,
    };
    drawWidget(widget, &widget.look, context);
}
/// This function is used to unwrap the widget from inside of an union to call its draw function with provided context
pub fn drawWidget (meta : anytype, widget : anytype, context : types.DrawingContext) void {
    const info = @typeInfo(@TypeOf(widget));

    if (info != .Pointer and info.Pointer.size != .One) @compileError("Widget needs to be a pointer");

    const widget_info = @typeInfo(info.Pointer.child);
    switch (widget_info) {
        .Struct => {
            widget.draw(meta, context);
        },
        .Union => |wid| {
            if (wid.tag_type == null) @compileError("Widget union needs to be tagged");
            switch (widget.*) {
                inline else => |*w| {
                    drawWidget(meta, w, context);
                }
            }
        },
        else => {
            @compileError("Unsupported widget type");
        }
    }
}

/// Recursively unwraps the widget from inside union type and call its InputEvent function
fn handleInputEvent (ui : anytype, behavior : anytype, look : anytype, event : types.BehaviorContext) ! cake.EventResult {
    const behavior_info = @typeInfo(@TypeOf(behavior));

    switch (behavior_info) {
        .Pointer => |ptr| {
            switch (@typeInfo(ptr.child)) {
                .Struct => {
                    const look_info = @typeInfo(@TypeOf(look));
                    switch (look_info) {
                        .Pointer => |lptr| {
                            switch (@typeInfo(lptr.child)) {
                                .Struct => {
                                    if (@hasDecl(ptr.child, "inputEvent")) {
                                        return behavior.inputEvent(ui, look, event);
                                    }
                                    else {
                                        return error.NoInputHandler;
                                    }
                                },
                                .Union => |uni| {
                                    if (uni.tag_type == null) @compileError("Look union must be tagged");
                                    switch (look.*) {
                                        inline else => |*lo| {
                                            return handleInputEvent(ui, behavior, lo, event);
                                        }
                                    }
                                },
                                else => @compileError("Look type is not supported, use union or struct"),
                            }
                        },
                        else => @compileError("Look must be passed by pointer"),
                    }
                },
                .Union => |uni| {
                    if (uni.tag_type == null) @compileError("Behavior union must be tagged");
                    switch (behavior.*) {
                        inline else => |*beh| {
                            return handleInputEvent(ui, beh, look, event);
                        }
                    }
                },
                else => @compileError("Behavior type is not supported, use union or struct instead of " ++ @typeName(ptr.child)),
            }
        },
        else => @compileError("Behavior must be passed by pointer"),
    }
}
/// Handles properly passing event to behavior.
/// The function first unwraps behavior and look from unions and passes actual data to the behavior handler
fn handlePointerEvent (ui : anytype, behavior : anytype, look : anytype, event : types.PointerContext) ! cake.EventResult {
    const behavior_info = @typeInfo(@TypeOf(behavior));

    switch (behavior_info) {
        .Pointer => |ptr| {
            switch (@typeInfo(ptr.child)) {
                .Struct => {
                    const look_info = @typeInfo(@TypeOf(look));
                    switch (look_info) {
                        .Pointer => |lptr| {
                            switch (@typeInfo(lptr.child)) {
                                .Struct => {
                                    if (@hasDecl(ptr.child, "pointerEvent")) {
                                        return behavior.pointerEvent(ui, look, event);
                                    }
                                    else {
                                        return error.NoPointerHandler;
                                    }
                                },
                                .Union => |uni| {
                                    if (uni.tag_type == null) @compileError("Look union must be tagged");
                                    switch (look.*) {
                                        inline else => |*lo| {
                                            return handlePointerEvent(ui, behavior, lo, event);
                                        }
                                    }
                                },
                                else => @compileError("Look type is not supported, use union or struct"),
                            }
                        },
                        else => @compileError("Look must be passed by pointer"),
                    }
                },
                .Union => |uni| {
                    if (uni.tag_type == null) @compileError("Behavior union must be tagged");
                    switch (behavior.*) {
                        inline else => |*beh| {
                            return handlePointerEvent(ui, beh, look, event);
                        }
                    }
                },
                else => @compileError("Behavior type is not supported, use union or struct instead of " ++ @typeName(ptr.child)),
            }
        },
        else => @compileError("Behavior must be passed by pointer"),
    }
}
/// Handles unwrapping widget behaviors from unions to call on the keyboardEvent handler with provided context
fn handleKeyboardEvent (ui : anytype, behavior : anytype, look : anytype, event : types.KeyboardContext) ! void {
    switch (@typeInfo(@TypeOf(behavior))) {
        .Pointer => |bptr| {
            switch (@typeInfo(bptr.child)) {
                .Struct => switch(@typeInfo(@TypeOf(look))) {
                    .Pointer => |lptr| switch (@typeInfo(lptr.child)) {
                        .Struct => {
                            if (@hasDecl(bptr.child, "keyboardEvent")) {
                                return behavior.keyboardEvent(ui, look, event);
                            }
                            else {
                                return error.NoKeyboardHandler;
                            }
                        },
                        .Union => |uni| {
                            if (uni.tag_type == null) @compileError("Look union needs to be tagged");
                            switch (look.*) {
                                inline else => |*l| {
                                    return handleKeyboardEvent(ui, behavior, l, event);
                                }
                            }
                        },
                        else => @compileError("Unsupported look type, must be a struct or union"),
                    },
                    else => @compileError("Look must be a pointer to handle keyboard events"),
                },
                .Union => |uni| {
                    if (uni.tag_type == null) @compileError("Behavior union needs to be tagged");
                    switch (behavior.*) {
                        inline else => |*wid| {
                            return handleKeyboardEvent(ui, wid, look, event);
                        }
                    }
                },
                else => @compileError("Unsupported behavior type, must be a struct or union"),
            }
        },
        else => {
            @compileError("Behavior must be a pointer to handle keyboard events");
        }
    }
}

/// Ensures the widget and behavior pair are compatible with each other, function recursively unwraps both from unions to pass the correct type to behavior validation function
fn validateBehaviors (widget : anytype, behavior : anytype) ! void {
    const behavior_info = @typeInfo(@TypeOf(behavior));

    switch (behavior_info) {
        .Pointer => |ptr| {
            switch (@typeInfo(ptr.child)) {
                .Union => {
                    switch (behavior.*) {
                        inline else => |*b| {
                            return validateBehaviors(widget, b);
                        }
                    }
                },
                .Struct => {
                    const widget_info = @typeInfo(@TypeOf(widget));
                    switch (widget_info) {
                        .Pointer => |w| {
                            switch (@typeInfo(w.child)) {
                                .Union => {
                                    switch (widget.*) {
                                        inline else => |*b| {
                                            return validateBehaviors(b, behavior);
                                        }
                                    }
                                },
                                .Struct => {
                                    const beh = @TypeOf(behavior.*);
                                    if (@hasDecl(beh, "validate")) {
                                        return beh.validate(w.child);
                                    }
                                },
                                else => @compileError("Unsupported widget type for validation"),
                            }
                        },
                        else => {
                            @compileError("Widget needs to be a pointer for validation");
                        }
                    }
                },
                .Void => {},
                else => @compileError("Unsupported behavior type for validation"),
            }
        },
        else => {
            @compileError("Behavior needs to be a pointer for validation");
        }
    }
}
