const types = @import("types.zig");

const EventResult = types.EventResult;
const PointerEvent = types.PointerEvent;
const KeyboardEvent = types.KeyboardEvent;
const BehaviorContext = types.BehaviorContext;
const DrawingContext = types.DrawingContext;
const Colors = types.ColorScheme;
const State = types.WidgetState;

/// Interface into Widget functionality
pub const Widget = struct {
    context : *anyopaque,
    vtable : struct {
        draw          : ?*const fn (*const anyopaque, ?@Vector(2, f32), Colors, State) void = null,
        pointerEvent  : ?*const fn (*anyopaque, Behavior, @Vector(2, f32), PointerEvent, State)  anyerror ! EventResult = null,
        keyboardEvent : ?*const fn (*anyopaque, Behavior, KeyboardEvent, State) anyerror ! void = null,
        inputEvent    : ?*const fn (*anyopaque, Behavior, @Vector(2, f32), PointerEvent, KeyboardEvent, State) anyerror ! EventResult = null,
        contains      : *const fn (*const anyopaque, @Vector(2, f32)) bool,
    },
    pub fn draw (self : @This(), pointer : ?@Vector(2, f32), colors : Colors, state : State) void {
        if (self.vtable.draw) |doDraw| {
            doDraw(self.context, pointer, colors, state);
        }
    }
    pub fn pointerEvent (self : @This(), ui : Ui, cursor : @Vector(2, f32), event : PointerEvent, state : State) anyerror!EventResult {
        if (self.vtable.pointerEvent) |doPointer| {
            return doPointer(self.context, .{ .context = self.context, .ui = ui }, cursor, event, state);
        }
        else {
            return .ignored;
        }
    }
    pub fn keyboardEvent (self : @This(), ui : Ui, event : KeyboardEvent, state : State) anyerror!void {
        if (self.vtable.keyboardEvent) |doKeyboard| {
            try doKeyboard(self.context, .{ .context = self.context, .ui = ui }, event, state);
        }
    }
    pub fn inputEvent (
        self    :  @This(),
        ui      : Ui,
        pointer : @Vector(2, f32),
        p_event : PointerEvent,
        k_event : KeyboardEvent,
        state   : State,
    ) anyerror!EventResult {
        if (self.vtable.inputEvent) |doInput| {
            return doInput(
                self.context,
                .{ .context = self.context, .ui = ui },
                pointer,
                p_event,
                k_event,
                state
            );
        }
        else {
            return .ignored;
        }
    }
    pub fn isInteractive (self : @This()) bool {
        return self.vtable.inputEvent != null or
            self.vtable.keyboardEvent != null or
            self.vtable.pointerEvent != null;
    }
    pub fn containsPoint (self : @This(), point : @Vector(2, f32)) bool {
        return self.vtable.contains(self.context, point);
    }
};

/// Raw interface into Ui functionality
pub const Ui = struct {
    context : *anyopaque,
    vtable : struct {
        sendEvent : *const fn (*anyopaque, *const anyopaque) void,
        isActive : *const fn (*const anyopaque, *const anyopaque) bool,
    },

    /// Sends event to the Ui.
    /// Event is sent by type erased pointer for polymorphic reasons,
    /// user is responsible for ensuring the correct event type is sent
    pub fn sendEvent (self : @This(), event_ptr : *const anyopaque) void {
        self.vtable.sendEvent(self.context, event_ptr);
    }
    /// Tests whatever the widget is currently active
    /// The widget pointer is type erased for polymorphic reason
    /// The UI will compare it against widget pointer, not behavior pointer
    pub fn isActive (self : @This(), widget_ptr : *const anyopaque) bool {
        return self.vtable.isActive(self.context, widget_ptr);
    }
};

/// Interface intended to be provided to Widgets as a wrapper around Ui interface
pub const Behavior = struct {
    context : *const anyopaque,
    ui : Ui,

    /// Tests whatever the widget is currently active
    pub fn isActive (self : @This()) bool {
        return self.ui.isActive(self.context);
    }
    /// Sends event to the Ui.
    /// Event is sent by type erased pointer for polymorphic reasons,
    /// user is responsible for ensuring the correct event type is sent
    pub fn sendEvent (self : @This(), event_ptr : *const anyopaque) void {
        self.ui.sendEvent(event_ptr);
    }
};
