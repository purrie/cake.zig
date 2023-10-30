const std = @import("std");
const cake = @import("cake.zig");
const types = @import("types.zig");
const text_fn = @import("text.zig");
const renderer = cake.backend;
const interface = @import("interface.zig");

const Rectangle = @import("Rectangle.zig");
const Context = types.DrawingContext;
const EventResult = types.EventResult;
const PointerEvent = types.PointerEvent;
const KeyboardEvent = types.KeyboardEvent;
const DrawingContext = types.DrawingContext;
const PointerContext = types.PointerContext;
const KeyboardContext = types.KeyboardContext;
const BehaviorContext = types.BehaviorContext;
const Ui = interface.Behavior;
const Interface = interface.Widget;
const Colors = types.ColorScheme;
const State = types.WidgetState;

/// Creates an interactive user interface element
/// Use Decor for non-interactive elements
pub fn Widget (
    comptime Data : type,
    comptime Viewer : type,
    comptime Behavior : type
) type {
    const draw_has_state = comptime isMethod("draw")(Viewer);
    const ViewerType = if (draw_has_state) Viewer else void;

    const act_has_state = comptime
        isMethod("keyboardEvent")(Behavior) or
        isMethod("pointerEvent")(Behavior) or
        isMethod("inputEvent")(Behavior);

    const BehaviorType = if (act_has_state) Behavior else void;

    if (@hasDecl(Viewer, "validate")) {
        if (Viewer.validate(Data) == false) {
            @compileError("Viewer and Data are not compatible");
        }
    }
    if (@hasDecl(Behavior, "validate")) {
        if (Behavior.validate(Data) == false) {
            @compileError("Behavior and Data are not compatible");
        }
    }

    return struct {
        area : Rectangle = .{},
        state : types.WidgetInteractionState = .normal,
        data : Data,
        viewer : ViewerType = undefined,
        behavior : BehaviorType = undefined,

        fn drawEvent (ptr : *const anyopaque, pointer : ?@Vector(2, f32), colors : Colors, state : State) void {
            const self : *const @This() = @ptrCast(@alignCast(ptr));
            if (self.state == .hidden) return;

            const data = if (@typeInfo(Data) == .Pointer)
                self.data else &self.data;

            var st = state;
            st.inactive = self.state == .inactive;

            const ctx = DrawingContext {
                .area = self.area,
                .pointer = pointer,
                .state = st,
                .colors = colors,
            };

            if (comptime isMethod("draw")(Viewer)) {
                self.viewer.draw(data, ctx);
            }
            else {
                Viewer.draw(data, ctx);
            }
        }
        fn pointerEvent (ptr : *anyopaque, ui : Ui, pointer : @Vector(2, f32), event : PointerEvent, state : State) anyerror ! EventResult {
            if (comptime isContainer(Behavior) and @hasDecl(Behavior, "pointerEvent")) {
                const self : *@This() = @ptrCast(@alignCast(ptr));
                if (self.state != .normal) return .ignored;

                var data = if (@typeInfo(Data) == .Pointer)
                    self.data else &self.data;

                const context = PointerContext {
                    .area = self.area,
                    .pointer = pointer,
                    .event = event,
                    .state = state,
                    .ui = ui,
                };

                if (comptime isMethod("pointerEvent")(Behavior)) {
                    return self.behavior.pointerEvent(data, context);
                }
                else {
                    return Behavior.pointerEvent(data, context);
                }
            }
            else {
                return error.NoPointerHandler;
            }
        }
        fn keyboardEvent (ptr : *anyopaque, ui : Ui, event : KeyboardEvent, state : State) anyerror ! void {
            if (comptime isContainer(Behavior) and @hasDecl(Behavior, "keyboardEvent")) {
                const self : *@This() = @ptrCast(@alignCast(ptr));
                if (self.state != .normal) return;

                var data = if (@typeInfo(Data) == .Pointer)
                    self.data else &self.data;

                const context = KeyboardContext {
                    .area = self.area,
                    .event = event,
                    .state = state,
                    .ui = ui,
                };

                if (comptime isMethod("keyboardEvent")(Behavior)) {
                    try self.behavior.keyboardEvent(data, context);
                }
                else {
                    try Behavior.keyboardEvent(data, context);
                }
            }
            else {
                return error.NoKeyboardHandler;
            }
        }
        fn inputEvent (
            ptr : *anyopaque,
            ui : Ui,
            pointer : @Vector(2, f32),
            p_event : PointerEvent,
            k_event : KeyboardEvent,
            state   : State,
        ) anyerror ! EventResult {
            const self : *@This() = @ptrCast(@alignCast(ptr));
            if (self.state != .normal) return .ignored;
            if (comptime isContainer(Behavior) and @hasDecl(Behavior, "inputEvent")) {

                var data = if (@typeInfo(Data) == .Pointer) self.data else &self.data;

                const context = BehaviorContext {
                    .area = self.area,
                    .keyboard_event = k_event,
                    .pointer_event = p_event,
                    .pointer_position = pointer,
                    .state = state,
                    .ui = ui,
                };

                if (comptime isMethod("inputEvent")(Behavior)) {
                    return self.behavior.inputEvent(data, context);
                }
                else {
                    return Behavior.inputEvent(data, context);
                }
            }
            else {
                var err = false;
                keyboardEvent(ptr, ui, k_event, state) catch |e| {
                    switch (e) {
                        error.NoKeyboardHandler => err = true,
                        else => return e,
                    }
                };
                const result = pointerEvent(ptr, ui, pointer, p_event, state) catch |e| {
                    switch (e) {
                        error.NoPointerHandler => if (err) return error.NoInputHandler
                            else return .processed,
                        else => return e,
                    }
                };
                return result;
            }
        }
        fn containsTest (ptr : *const anyopaque, point : @Vector(2, f32)) bool {
            const self : *const @This() = @ptrCast(@alignCast(ptr));
            return self.area.contains(point);
        }
        pub fn getInterface (self : *@This()) Interface {
            return .{
                .context = self,
                .vtable = .{
                    .draw = &drawEvent,
                    .pointerEvent = &pointerEvent,
                    .keyboardEvent = &keyboardEvent,
                    .inputEvent = &inputEvent,
                    .contains = &containsTest,
                }
            };
        }
    };
}

pub fn Decor (
    comptime Data : type,
    comptime Viewer : type,
) type {
    const draw_has_state = comptime isMethod("draw")(Viewer);
    const ViewerType = if (draw_has_state) Viewer else void;

    if (@hasDecl(Viewer, "validate")) {
        if (Viewer.validate(Data) == false) {
            @compileError("Viewer and Data are not compatible");
        }
    }
    return struct {
        area : Rectangle = .{},
        hidden : bool = false,
        data : Data,
        viewer : ViewerType = undefined,

        fn drawEvent (ptr : *const anyopaque, pointer : ?@Vector(2, f32), colors : Colors, state : State) void {
            const self : *const @This() = @ptrCast(@alignCast(ptr));
            if (self.hidden) return;

            const data = if (@typeInfo(Data) == .Pointer)
                self.data else &self.data;

            const context = DrawingContext {
                .area = self.area,
                .colors = colors,
                .pointer = pointer,
                .state = state,
            };

            if (comptime isMethod("draw")(Viewer)) {
                self.viewer.draw(data, context);
            }
            else {
                Viewer.draw(data, context);
            }
        }
        fn containsTest (ptr : *const anyopaque, point : @Vector(2, f32)) bool {
            const self : *const @This() = @ptrCast(@alignCast(ptr));
            return self.area.contains(point);
        }
        pub fn getInterface (self : *@This()) Interface {
            return .{
                .context = self,
                .vtable = .{
                    .draw = &drawEvent,
                    .contains = &containsTest,
                }
            };
        }
    };
}

const isContainer = std.meta.trait.isContainer;
const TraitFn = std.meta.trait.TraitFn;

pub fn isMethod(comptime name: []const u8) TraitFn {
    const Closure = struct {
        pub fn trait (comptime T: type) bool {
            if (!comptime isContainer(T)) return false;
            if (!comptime @hasDecl(T, name)) return false;
            const DeclType = @TypeOf(@field(T, name));
            switch (@typeInfo(DeclType)) {
                .Fn => |f| {
                    if (f.params.len == 0) return false;
                    const Type = f.params[0].type orelse return false;
                    switch (@typeInfo(Type)) {
                        .Pointer => |ptr| {
                            return ptr.child == T and ptr.size == .One;
                        },
                        else => return Type == T,
                    }
                },
                else => return false,
            }
        }
    };
    return Closure.trait;
}

test "isMethod" {
    const TestStruct = struct {
        pub fn firstFn(data: anytype) void { _ = data; }
        pub fn secondFn(self: @This()) void { _ = self; }
        pub fn thirdFn(self: *const @This()) void { _ = self; }
        fn fourthFn(ar: []@This()) void { _ = ar; }
        fn fifthFn(self: *@This()) void { _ = self; }
        fn sixthFn() void {}
    };
    const expect = std.testing.expect;

    try expect(isMethod("firstFn")(TestStruct) == false);
    try expect(isMethod("secondFn")(TestStruct));
    try expect(isMethod("thirdFn")(TestStruct));
    try expect(isMethod("fourthFn")(TestStruct) == false);
    try expect(isMethod("fifthFn")(TestStruct));
    try expect(isMethod("sixthFn")(TestStruct) == false);
}
