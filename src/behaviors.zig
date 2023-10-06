const std = @import("std");
const cake = @import("main.zig");
const types = @import("types.zig");
const text_fn = @import("text.zig");

const Rectangle = cake.Rectangle;
const InputContext = types.BehaviorContext;
const KeyboardContext = types.KeyboardContext;
const PointerContext = types.PointerContext;

pub fn BuiltinBehaviors (comptime Event : type) type {
    return union (enum) {
        button : Button(Event),
        text_input : TextInput,
    };
}

/// Buttons produce given event in host Ui when they're clicked and released
pub fn Button (comptime Event : type) type {
    return struct {
        event : Event,

        pub fn pointerEvent (self : *@This(), ui : anytype, look : anytype, event : PointerContext) ! cake.EventResult {
            _ = look;
            switch (event.pointer) {
                .press => {
                    return .activated;
                },
                .lift => {
                    if (ui.isActive(self)) {
                        ui.event = self.event;
                    }
                    return .deactivated;
                },
                else => return .processed,
            }
        }
    };
}

/// Handles single line keyboard input
/// Widget it is attached to must have following fields:
/// margin : f32,
/// text : []u8 or [:0]u8
/// size : f32
/// cursor : usize
/// capacity : usize
pub const TextInput = struct {
    pub fn validate (comptime look : type) ! void {
        const no_margin   = ! @hasField(look, "margin");
        const no_text     = ! @hasField(look, "text");
        const no_size     = ! @hasField(look, "size");
        const no_cursor   = ! @hasField(look, "cursor");
        const no_capacity = ! @hasField(look, "capacity");
        if (no_margin or no_text or no_size or no_cursor or no_capacity) {
            return error.InvalidWidget;
        }
    }
    pub fn inputEvent (self : *TextInput, ui : anytype, look : anytype, event : types.BehaviorContext) ! cake.EventResult {
        const result = .ignored;

        if (event.keyboard) |kb| {
            try self.keyboardEvent(ui, look, .{ .area = event.area, .keyboard = kb });
            result = .processed;
        }
        if (event.pointer) |ptr| {
            if (event.position) |pos| {
                result = self.pointerEvent(ui, look, .{ .area = event.area, .pointer = ptr, .position = pos });
            }
        }

        return result;
    }
    pub fn keyboardEvent (self : *TextInput, ui : anytype, look : anytype, event : KeyboardContext) ! void {
        _ = ui;
        _ = self;
        const has_margin   = @hasField(@TypeOf(look.*), "margin");
        const has_text     = @hasField(@TypeOf(look.*), "text");
        const has_size     = @hasField(@TypeOf(look.*), "size");
        const has_cursor   = @hasField(@TypeOf(look.*), "cursor");
        const has_capacity = @hasField(@TypeOf(look.*), "capacity");

        if (has_margin and has_text and has_size and has_cursor and has_capacity) {
            const TextType = @TypeOf(look.text);
            const sentineled = switch (@typeInfo(TextType)) {
                .Pointer => |ptr| rt: {
                    if (ptr.size == .One) @compileError("Text Input can't work on single item pointers for text");
                    break :rt ptr.sentinel != null;
                },
                .Array => |ar| ar.sentinel != null,
                else => @compileError("Text input has invalid text field type"),
            };
            if (event.keyboard.character) |char| chr: {
                const diff = text_fn.inputTextUnicode(
                    look.text[0..look.text.len],
                    if (sentineled) look.capacity - 1 else look.capacity,
                    look.cursor,
                    char
                ) catch |err| switch (err) {
                    error.OutOfMemory => return,
                    error.InvalidCharacter => break :chr,
                    else => return err,
                };
                if (diff == 0) {
                    return;
                }
                look.cursor += diff;

                const len = look.text.len + diff;
                @memset(look.text.ptr[len..len+1], 0);
                look.text = look.text.ptr[0..len :0];
                return;
            }
            if (event.keyboard.keycode) |key| {
                const input = cake.backend.input;
                if (input.isBackspace(key)) {
                    const diff = text_fn.deleteCharBeforeUnicode(look.text[0..look.text.len], look.cursor);
                    if (diff == 0) {
                        return;
                    }
                    std.debug.print("Len: {d}", .{diff});
                    look.cursor -= diff;

                    const len = look.text.len - diff;
                    look.text[len] = 0;
                    look.text = look.text[0..len :0];
                }
                else if (input.isNavLeft(key)) {
                    text_fn.moveCursorCharBackward(look.text[0..look.text.len], &look.cursor);
                }
                else if (input.isNavRight(key)) {
                    text_fn.moveCursorCharForward(look.text[0..look.text.len], &look.cursor);
                }
            }
        }
        else {
            return error.UnsupportedBehaviorWidgetPair;
        }

    }
    pub fn pointerEvent (self : *TextInput, ui : anytype, look : anytype, event : PointerContext) ! cake.EventResult {
        _ = ui;
        _ = self;
        const has_margin = @hasField(@TypeOf(look.*), "margin");
        const has_text = @hasField(@TypeOf(look.*), "text");
        const has_size = @hasField(@TypeOf(look.*), "size");
        const has_cursor = @hasField(@TypeOf(look.*), "cursor");

        if (has_margin and has_text and has_size and has_cursor) {
            if (event.pointer == .press) {
                const pointer = event.position[0] - event.area.position[0];
                var pos = look.margin;
                var idx : usize = 0;
                var char_buff = [_]u8{0} ** 5;
                while (idx < look.text.len) {
                    const len = std.unicode.utf8ByteSequenceLength(look.text[idx]) catch return error.InvalidCharacter;
                    @memcpy(char_buff[0..len], look.text[idx..][0..len]);
                    char_buff[len] = 0;
                    const width = cake.backend.view.measureText(char_buff[0..len :0], look.size);
                    const width_half = 0.5 * width;
                    if (pointer > pos + width_half) {
                        idx += len;
                        pos += width;
                    }
                    else {
                        break;
                    }
                }
                look.cursor = idx;
                return .activated;
            }
            return .processed;
        }
        else {
            return error.UnsupportedBehaviorWidgetPair;
        }
    }
};
