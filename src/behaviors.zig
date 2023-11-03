const std = @import("std");
const cake = @import("cake.zig");
const types = @import("types.zig");
const text_fn = @import("text.zig");
const interface = @import("interface.zig");

const isMethod = @import("widgets.zig").isMethod;

const Rectangle = cake.Rectangle;
const InputContext = types.BehaviorContext;
const KeyboardContext = types.KeyboardContext;
const PointerContext = types.PointerContext;
const Ui = interface.Behavior;

/// Buttons produce given event in host Ui when they're clicked and released
pub fn Button (comptime Event : type) type {
    return struct {
        event : Event,

        pub fn pointerEvent (self : *@This(), data : anytype, event : PointerContext) ! cake.EventResult {
            _ = data;
            switch (event.event) {
                .press => {
                    return .activated;
                },
                .lift => {
                    if (event.ui.isActive()) {
                        event.ui.sendEvent(&self.event);
                    }
                    return .deactivated;
                },
                else => return .processed,
            }
        }
    };
}

/// Handles single line keyboard input
/// it expects the data to have a way to obtain text string
///   this can be in from of getString fn
///   or 'text' field that can be []u8, []const u8 or [_]u8 with accompanying 'len' field
///   if the 'text' is a slice then data should also have 'capacity' field
/// Data should also have getCursor and setCursor fns or cursor field,
///   in absence of those the logic assumes the cursor is always at the end
/// 'margin' field or 'getMargin' is optional and used for pointer event  to set cursor location
/// 'font_size' or 'size' fields or 'getFontSize' fn is used similarly as 'margin'
///   absence of it will turn off pointer event setting cursor location functionality
pub fn TextInput (comptime Event : type) type {
    const event_present = @typeInfo(Event) != .Void;
    const default = if (event_present)
        null else {};
    const EventType = if (event_present)
        ?Event else void;

    return struct {
        last_input : ?u21 = null,

        on_input : EventType = default,
        on_delete : EventType = default,
        on_cursor_move : EventType = default,

        pub fn validate (comptime Data : type) bool {
            const has_text = @hasField(Data, "text") or
                @hasDecl(Data, "getString");

            return has_text;
        }
        pub fn keyboardEvent (self : *@This(), data : anytype, event : KeyboardContext) ! void {
            const Data = switch(@typeInfo(@TypeOf(data))) {
                .Pointer => |ptr| ptr.child,
                else => @TypeOf(data),
            };
            const has_text = @hasField(Data, "text") or
                @hasDecl(Data, "getString");

            if (has_text) {
                self.last_input = null;
                var text = if (@hasDecl(Data, "getMutString")) txt: {
                    if (comptime isMethod("getMutString")(Data)) {
                        break :txt data.getMutString();
                    }
                    else {
                        break :txt Data.getMutString();
                    }
                }
                else if (@hasField(Data, "text"))
                    switch (@typeInfo(@TypeOf(data.text))) {
                        .Pointer => |ptr| slc: {
                            if (ptr.size == .One) @compileError("Text Input can't work on single item pointers for text");
                            if (ptr.sentinel != null) @compileError("Text Input does not support sentinel guarded strings");
                            if (ptr.child != u8) @compileError("Text Input expects 'text' field to be a []u8 type");
                            if (ptr.is_const)
                                break :slc @constCast(data.text)
                            else
                                break :slc data.text;

                        },
                        .Array => |ar| slc: {
                            if (@hasField(Data, "len") == false) @compileError("Field text in data is an array and Text Input expects accompanying 'len' field to denote the actual string length");
                            if (ar.child != u8) @compileError("Text input expects 'text' array to be [_]u8 type");
                            const len = @min(data.len, ar.len);
                            break :slc data.text[0..len];
                        },
                        else => @compileError("Text Input expected data field 'text' to be either a slice or array"),
                }
                else @compileError("Text Input behavior could not find a way to get string text from data, expected to find getString function or text field");

                const capacity = if (@hasDecl(Data, "getCapacity")) cap: {
                    if (comptime isMethod("getCapacity")(Data)) {
                        break :cap data.getCapacity();
                    }
                    else {
                        break :cap Data.getCapacity();
                    }
                }
                else if (@hasField(Data, "capacity"))
                    data.capacity
                else if (@hasField(Data, "text")) l: {
                    switch (@typeInfo(@TypeOf(data.text))) {
                        .Array => |ar| {
                            break :l ar.len;
                        },
                        else => @compileError("Text Input could not find capacity of the text array"),
                    }
                }
                else @compileError("Text Input behavior could not find a way to obtain capacity for the string, expected 'getCapacity' function or 'capacity' field");

                var cursor = if (@hasDecl(Data, "getCursor")) crs: {
                    if (comptime isMethod("getCursor")(Data)) {
                        break :crs data.getCursor();
                    }
                    else {
                        break :crs Data.getCursor();
                    }

                }
                else if (@hasField(Data, "cursor"))
                    data.cursor
                else text.len;

                if (event.event.character) |char| chr: {
                    const diff = text_fn.inputTextUnicode(
                        text,
                        capacity,
                        cursor,
                        char
                    ) catch |err| switch (err) {
                        error.OutOfMemory => return,
                        error.InvalidCharacter => break :chr,
                        else => return err,
                    };
                    if (diff == 0) {
                        return;
                    }
                    if (@hasDecl(Data, "setCursor")) {
                        if (comptime isMethod("setCursor")(Data)) {
                            data.setCursor(cursor + diff);
                        }
                        else {
                            Data.setCursor(cursor + diff);
                        }
                    }
                    else if (@hasField(Data, "cursor")) {
                        data.cursor += diff;
                    }

                    const len = text.len + diff;
                    if (@hasDecl(Data, "setStringLength")) {
                        if (comptime isMethod("setStringLength")(Data)) {
                            data.setStringLength(len);
                        }
                        else {
                            Data.SetStringLength(len);
                        }
                    }
                    else if (@hasField(Data, "text")) {
                        switch (@typeInfo(@TypeOf(data.text))) {
                            .Pointer => {
                                data.text = data.text.ptr[0..len];
                            },
                            .Array => {
                                data.len = len;
                            },
                            else => @compileError("Text Input expects the text field to be either a slice or array"),
                        }
                    }
                    else @compileError("Text Input could not find a way to update the text string");

                    if (event_present) {
                        if (self.on_input) |ie| {
                            self.last_input = char;
                            event.ui.sendEvent(&ie);
                        }
                    }
                    return;
                }
                if (event.event.keycode) |key| {
                    const input = cake.backend.input;
                    if (input.isBackspace(key)) {
                        if (cursor == 0) return;
                        const deletion = text_fn.deleteCharBeforeUnicode(text, cursor) orelse return;
                        if (@hasDecl(Data, "setCursor")) {
                            if (comptime isMethod("setCursor")(Data)) {
                                data.setCursor(cursor - deletion.size_diff);
                            }
                            else {
                                Data.setCursor(cursor - deletion.size_diff);
                            }
                        }
                        else if (@hasField(Data, "cursor")) {
                            data.cursor -= deletion.size_diff;
                        }

                        if (@hasDecl(Data, "setStringLength")) {
                            if (comptime isMethod("setStringLength")(Data)) {
                                data.setStringLength(deletion.new_size);
                            }
                            else {
                                Data.setStringLength(deletion.new_size);
                            }
                        }
                        else if (@hasField(Data, "text")) {
                            switch (@typeInfo(@TypeOf(data.text))) {
                                .Pointer => {
                                    data.text = data.text.ptr[0..deletion.new_size];
                                },
                                .Array => {
                                    data.len = deletion.new_size;
                                },
                                else => @compileError("Text Input expects the text field to be either a slice or array"),
                            }
                        }
                        self.last_input = deletion.deleted;
                        if (event_present) {
                            if (self.on_delete) |ev| {
                                event.ui.sendEvent(&ev);
                            }
                        }
                    }
                    if (@hasDecl(Data, "setCursor") or @hasField(Data, "cursor")) {
                        if (input.isNavLeft(key)) {
                            text_fn.moveCursorCharBackward(text, &cursor);
                            if (@hasDecl(Data, "setCursor")) {
                                if (comptime isMethod("setCursor")(Data)) {
                                    data.setCursor(cursor);
                                }
                                else {
                                    Data.setCursor(cursor);
                                }
                            }
                            else data.cursor = cursor;

                            if (event_present) {
                                if (self.on_cursor_move) |cme| {
                                    event.ui.sendEvent(&cme);
                                }
                            }
                        }
                        else if (input.isNavRight(key)) {
                            text_fn.moveCursorCharForward(text, &cursor);
                            if (@hasDecl(Data, "setCursor")) {
                                if (comptime isMethod("setCursor")(Data)) {
                                    data.setCursor(cursor);
                                }
                                else {
                                    Data.setCursor(cursor);
                                }
                            }
                            else data.cursor = cursor;

                            if (event_present) {
                                if (self.on_cursor_move) |cme| {
                                    event.ui.sendEvent(&cme);
                                }
                            }
                        }
                    }
                }
            }
            else {
                return error.UnsupportedBehaviorData;
            }
        }
        pub fn pointerEvent (self : *@This(), data : anytype, event : PointerContext) ! cake.EventResult {
            _ = self;
            const Data = switch(@typeInfo(@TypeOf(data))) {
                .Pointer => |ptr| ptr.child,
                else => @TypeOf(data),
            };

            const has_text = @hasField(Data, "text") or
                @hasDecl(Data, "getString");

            const has_size = @hasField(Data, "size") or
                @hasDecl(Data, "getFontSize") or
                @hasField(Data, "font_size");

            const has_cursor = @hasDecl(Data, "getCursor") or
                @hasField(Data, "cursor");

            if (has_text and has_size and has_cursor) {
                if (event.event == .press) {
                    if (has_cursor) {
                        const margin = if (@hasDecl(Data, "getMargin")) mrg: {
                            if (comptime isMethod("getMargin")(Data)) {
                                break :mrg data.getMargin();
                            }
                            else {
                                break :mrg Data.getMargin();
                            }
                        }
                        else if (@hasField(Data, "margin"))
                            data.margin
                        else 0.0;

                        const font_size = if (@hasDecl(Data, "getFontSize")) fnt: {
                            if (comptime isMethod("getFontSize")){
                                break :fnt data.getFontSize();
                            }
                            else {
                                break :fnt Data.getFontSize();
                            }
                        }
                        else if (@hasField(Data, "font_size"))
                            data.font_size
                        else if (@hasField(Data, "size"))
                            data.size
                        else @compileError("Text Input could not find font size in widget data");

                        const text = if (@hasDecl(Data, "getString")) txt: {
                            if (comptime isMethod("getString")(Data)) {
                                break :txt data.getString();
                            }
                            else {
                                break :txt Data.getString();
                            }
                        }
                        else if (@hasField(Data, "text"))
                            switch (@typeInfo(@TypeOf(data.text))) {
                                .Pointer => |ptr| slc: {
                                    if (ptr.child != u8)
                                        @compileError("Text Input can only work on u8 strings");
                                    if (ptr.size != .Slice)
                                        @compileError("Text Input can only work on slice pointers");
                                    if (ptr.sentinel != null) {
                                        if (ptr.is_const) {
                                            break :slc @constCast(std.mem.span(data.text));
                                        }
                                        else {
                                            break :slc std.mem.span(data.text);
                                        }
                                    }
                                    else {
                                        if (ptr.is_const) {
                                            break :slc @constCast(data.text);
                                        }
                                        else {
                                            break :slc data.text;
                                        }
                                    }
                                },
                                .Array => |ar| slc: {
                                    if (!@hasField(Data, "len"))
                                        @compileError("Text Input requires data to have 'len' field accompanying 'text' array");
                                    const len = @min(data.len, ar.len);
                                    break :slc data.text[0..len];
                                },
                                else =>
                                    @compileError("Text Input requires 'text' field of data to be either a slice or array"),
                        };

                        const pointer = event.pointer[0] - event.area.position[0];
                        var pos : f32 = margin;
                        var idx : usize = 0;
                        while (idx < text.len) {
                            const len = std.unicode.utf8ByteSequenceLength(text[idx])
                                catch return error.InvalidCharacter;
                            const width = cake.backend.measureText(text[idx..][0..len], font_size);
                            const width_half = 0.5 * width;
                            if (pointer > pos + width_half) {
                                idx += len;
                                pos += width;
                            }
                            else {
                                break;
                            }
                        }
                        if (@hasDecl(Data, "setCursor")) {
                            if (comptime isMethod("setCursor")(Data)) {
                                data.setCursor(idx);
                            }
                            else {
                                Data.setCursor(idx);
                            }
                        }
                        else if (@hasField(Data, "cursor")) {
                            data.cursor = idx;
                        }
                    }
                    return .activated;
                }
                else if (event.event == .lift) {
                    if (event.ui.isActive()) {
                        return .deactivated;
                    }
                }
                return .processed;
            }
            else {
                return error.UnsupportedBehaviorData;
            }
        }
    };
}
