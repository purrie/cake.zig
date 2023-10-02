const std = @import("std");
const cake = @import("main.zig");
const types = @import("types.zig");
const style = @import("style.zig");
const widgets = cake.widgets;
const log = std.log.scoped(.cake);

const Rectangle = @import("Rectangle.zig");
const Size = types.Size;
const Vector = types.Vector;
const DrawFilter = types.DrawFilter;
const ColorScheme = types.ColorScheme;
const KeyboardEvent = types.KeyboardEvent;

const assert = std.debug.assert;

pub const Context = struct {
    Core : type,
    renderer : type = cake.backend,

    Widget         : type = widgets.BuiltinWidgets,
    WidgetTheme    : type = style.DefaultTheme,
    UiColorPalette : type = style.DefaultPalette,

    WidgetIdentity : type = void,
    Interaction    : type = void,
    UiEvent        : type = void,

    /// whatever the framework should handle input events automatically when possible
    /// Framework will forward input events into widgets when those can process those themselves
    handle_input : bool = true,
};

pub fn FixedUi (
    comptime context : Context,
    comptime size : usize,
) type {
    return struct {
        const Ui = @This();
        pub const WidgetMetadata = @import("widget.zig").WidgetConfig (
            context.Interaction,
            context.WidgetTheme,
            context.WidgetIdentity,
        );
        pub const Context = context;
        pub const PointerEvent = types.PointerEvent(context.Widget, WidgetMetadata);
        pub const LayoutContext = struct {
            ui : *Ui,

            pub fn addWidget (
                self : LayoutContext,
                area : Rectangle,
                widget : context.Widget,
                config : WidgetMetadata
            ) ! void {
                if (self.ui.len >= size) return error.OutOfMemory;
                self.ui.widgets[self.ui.len] = widget;
                self.ui.metadata[self.ui.len] = config;
                self.ui.zones[self.ui.len] = area;
                self.ui.len += 1;
            }
            pub fn measureText (self : LayoutContext, text : context.renderer.String, font_size : f32) f32 {
                _ = self;
                return context.renderer.view.measureText(text, font_size);
            }
            pub fn windowArea (self : LayoutContext) Rectangle {
                _ = self;
                return context.renderer.view.windowArea();
            }
        };

        core  : context.Core,
        theme : context.UiColorPalette,

        widgets  : [size]context.Widget = undefined,
        zones    : [size]Rectangle = [_]Rectangle{.{}} ** size,
        metadata : [size]WidgetMetadata = [_]WidgetMetadata{.{}} ** size,

        pointer : ?Vector = null,
        len    : usize = 0,
        focus  : ?usize = null,
        active : ?usize = null,
        event  : ?context.UiEvent = null,

        pub fn init (core : context.Core, theme : context.UiColorPalette) Ui {
            return .{
                .core = core,
                .theme = theme,
            };
        }
        pub fn bake (self : *Ui) ! void {
            self.len = 0;
            try self.core.uiLayout(LayoutContext{ .ui = self });
        }
        pub fn setPointerPosition (self : *Ui, position : ?Vector) void {
            if (@hasDecl(context.Core, "pointerPositionChange")) {
                defer self.pointer = position;
                self.core.pointerPositionChange(self, self.pointer, position);
            }
            else {
                self.pointer = position;
            }
        }
        pub fn draw (self : *const Ui) void {
            for (0..self.len) |i| {
                const over = if (self.pointer) |pos| self.zones[i].contains(pos) else false;
                const meta = &self.metadata[i];

                var draw_filter : DrawFilter = .{
                    .focus = i == self.focus,
                    .active = i == self.active,
                    .hover = over,
                    .normal = !over,
                };

                if (draw_filter.isMismatch(meta.draw_filter)) continue;

                if (meta.interaction == null) {
                    draw_filter = .{
                        .focus = if (meta.can_focus) draw_filter.focus else false,
                        .hover = if (meta.can_focus) draw_filter.hover else false,
                        .active = false
                    };
                }

                const colors = if (@hasDecl(context.WidgetTheme, "getColorScheme")) col: {
                    if (@typeInfo(context.UiColorPalette) == .Pointer)
                        break :col meta.theme.getColorScheme(self.theme)
                    else
                        break :col meta.theme.getColorScheme(&self.theme);
                } else col: {
                    break :col self.theme.getColors(meta.theme);
                };

                const wid = &self.widgets[i];
                drawWidget(wid, self.zones[i], colors, draw_filter, context.renderer);
            }
        }
        pub fn sendInputEvent (self : *Ui, pointer : types.PointerEventKind, keyboard : KeyboardEvent) ! void {
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
                    &self.widgets[idx],
                    PointerEvent{
                        .widget = &self.widgets[idx],
                        .meta = meta,
                        .idx = idx,
                        .kind = pointer,
                    },
                    keyboard
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
        pub fn sendPointerEvent (self : *Ui, event : types.PointerEventKind) ! void {
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

                const result = try handlePointerEvent(
                    self,
                    &self.widgets[idx],
                    PointerEvent{
                        .widget = &self.widgets[idx],
                        .meta = meta,
                        .idx = idx,
                        .kind = event,
                    }
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
        pub fn sendKeyboardEvent (self : *Ui, event : KeyboardEvent) ! void {
            if (self.focus) |focus| {
                return handleKeyboardEvent(self, &self.widgets[focus], event);
            }
            else {
                return handleKeyboardEvent(self, null, event);
            }
        }
        pub fn popEvent (self : *Ui) ?context.UiEvent {
            defer self.event = null;
            return self.event;
        }
    };
}

fn drawWidget (widget : anytype, area : Rectangle, colors : ColorScheme, state : DrawFilter, comptime renderer : type) void {
    const info = @typeInfo(@TypeOf(widget));

    if (info != .Pointer and info.Pointer.size != .One) @compileError("Widget needs to be a pointer");

    const widget_info = @typeInfo(info.Pointer.child);
    switch (widget_info) {
        .Struct => {
            widget.draw(area, colors, state, renderer);
        },
        .Union => |wid| {
            if (wid.tag_type == null) @compileError("Widget union needs to be tagged");
            switch (widget.*) {
                inline else => |*w| {
                    drawWidget(w, area, colors, state, renderer);
                }
            }
        },
        else => {
            @compileError("Unsupported widget type");
        }
    }
}

fn handlePointerEvent (ui : anytype, widget : anytype, event : anytype) ! cake.EventResult {
    const UiType = @typeInfo(@TypeOf(ui)).Pointer.child;
    const Core = @TypeOf(ui.core);
    if (UiType.Context.handle_input == false) {
        if (@hasDecl(Core, "pointerEvent")) {
            return try ui.core.pointerEvent(ui, event);
        }
        else {
            log.err("Ui core of type {s} received unhandled pointer event", .{@typeName(Core)});
            return error.NoPointerEventHandler;
        }
    }
    else {
        const info = @typeInfo(@TypeOf(widget));

        if (info != .Pointer and info.Pointer.size != .One) @compileError("Widget must be a pointer");

        const widget_info = @typeInfo(info.Pointer.child);
        switch (widget_info) {
            .Struct => {
                if (@hasDecl(info.Pointer.child, "pointerEvent")) {
                    return try widget.pointerEvent(ui, event);
                }
                else {
                    if (@hasDecl(Core, "pointerEvent")) {
                        return try ui.core.pointerEvent(ui, event);
                    }
                    else {
                        log.err("Ui core of type {s} received unhandled pointer event", .{@typeName(Core)});
                        return error.NoPointerEventHandler;
                    }
                }
            },
            .Union => |uni| {
                if (uni.tag_type == null) @compileError("Widget union needs to be tagged");
                switch (widget.*) {
                    inline else => |*wid| {
                        return try handlePointerEvent(ui, wid, event);
                    }
                }
            },
            else => {
                return try ui.core.pointerEvent(ui, event);
            }
        }
    }
}
fn handleKeyboardEvent (ui : anytype, widget : anytype, event : KeyboardEvent) ! void {
    const UiType = @typeInfo(@TypeOf(ui)).Pointer.child;
    const Core = @TypeOf(ui.core);

    if (UiType.Context.handle_input == false) {
        if (@hasDecl(Core, "keyboardEvent")) {
            return ui.core.keyboardEvent(ui, event);
        }
        else {
            return error.NoKeyboardEventHandler;
        }
    }
    else {
        const info = @typeInfo(@TypeOf(widget));

        switch (info) {
            .Pointer => {
                const widget_info = @typeInfo(info.Pointer.child);
                switch (widget_info) {
                    .Struct => {
                        if (@hasDecl(info.Pointer.child, "keyboardEvent")) {
                            return try widget.keyboardEvent(ui, event);
                        }
                        else {
                            if (@hasDecl(Core, "keyboardEvent")) {
                                return try ui.core.keyboardEvent(ui, event);
                            }
                            else {
                                log.err("Ui core of type {s} received unhandled keyboard event", .{@typeName(Core)});
                                return error.NoPointerEventHandler;
                            }
                        }
                    },
                    .Union => |uni| {
                        if (uni.tag_type == null) @compileError("Widget union needs to be tagged");
                        switch (widget.*) {
                            inline else => |*wid| {
                                return try handleKeyboardEvent(ui, wid, event);
                            }
                        }
                    },
                    else => {
                        return try ui.core.keyboardEvent(ui, event);
                    }
                }
            },
            .Null => {
                if (@hasDecl(Core, "keyboardEvent")) {
                    return ui.core.keyboardEvent(ui, event);
                }
                else {
                    return error.NoKeyboardEventHandler;
                }
            },
            else => {
                @compileError("Widget must be a pointer or void to handle keyboard events");
            }
        }
    }
}
fn handleInputEvent (ui : anytype, widget : anytype, pointer : anytype, keyboard : anytype) ! cake.EventResult {
    const UiType = @typeInfo(@TypeOf(ui)).Pointer.child;
    const Core = @TypeOf(ui.core);

    if (UiType.Context.handle_input == false) {
        if (@hasDecl(Core, "inputEvent")) {
            return ui.core.inputEvent(ui, pointer, keyboard);
        }
        else {
            return error.NoInputEventHandler;
        }
    }
    else {
        const info = @typeInfo(@TypeOf(widget));

        switch (info) {
            .Pointer => {
                const widget_info = @typeInfo(info.Pointer.child);
                switch (widget_info) {
                    .Struct => {
                        if (@hasDecl(info.Pointer.child, "inputEvent")) {
                            return widget.inputEvent(ui, pointer, keyboard);
                        }
                        else {
                            if (@hasDecl(Core, "inputEvent")) {
                                return ui.core.inputEvent(ui, pointer, keyboard);
                            }
                            else {
                                return error.NoInputEventHandler;
                            }
                        }
                    },
                    .Union => |uni| {
                        if (uni.tag_type == null) @compileError("Widget union needs to be tagged");
                        switch (widget.*) {
                            inline else => |*wid| {
                                return handleInputEvent(ui, wid, pointer, keyboard);
                            }
                        }
                    },
                    else => {
                        return try ui.core.inputEvent(ui, pointer, keyboard);
                    }
                }
            },
            else => {
                @compileError("Widget must be a pointer or void to handle keyboard events");
            }
        }
    }
}
