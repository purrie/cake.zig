const std = @import("std");
const cake = @import("cake.zig");
const types = @import("types.zig");
const text_fn = @import("text.zig");

const Rectangle = cake.Rectangle;
const InputContext = types.BehaviorContext;
const KeyboardContext = types.KeyboardContext;
const PointerContext = types.PointerContext;

pub fn BuiltinBehaviors (comptime Event : type) type {
    return union (enum) {
        button : Button(Event),
        text_input : TextInput(Event),
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
pub fn TextInput (comptime Event : type) type {
    const event_present = @typeInfo(Event) != .Void;

    const OnCharChange = if (event_present)
        ?*const fn(text : []const u8, cursor : usize, char : u21) ?Event
    else void;

    const OnCursor = if(event_present)
        ?*const fn(text : []const u8, old_cursor : usize, new_cursor : usize) ?Event
    else void;

    const default = if (event_present)
        null else {};

    return struct {
        capacity : usize,

        /// Called when a character has been input
        onInput : OnCharChange = default,
        /// Called when a character has been deleted
        onDelete : OnCharChange = default,
        /// Called when cursor has been moved
        onCursorMove : OnCursor = default,

        pub fn validate (comptime look : type) ! void {
            const no_text = ! @hasField(look, "text");
            const no_size = ! @hasField(look, "size");
            if (no_text or no_size) {
                return error.InvalidWidget;
            }
        }
        pub fn inputEvent (self : *@This(), ui : anytype, look : anytype, event : types.BehaviorContext) ! cake.EventResult {
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
        pub fn keyboardEvent (self : *@This(), ui : anytype, look : anytype, event : KeyboardContext) ! void {
            const has_text     = @hasField(@TypeOf(look.*), "text");
            const has_size     = @hasField(@TypeOf(look.*), "size");
            const has_cursor   = @hasField(@TypeOf(look.*), "cursor");

            if (has_text and has_size) {
                const TextType = @TypeOf(look.text);
                switch (@typeInfo(TextType)) {
                    .Pointer => |ptr| {
                        if (ptr.size == .One) @compileError("Text Input can't work on single item pointers for text");
                        if (ptr.sentinel != null) @compileError("Text Input does not support sentinel guarded strings");
                    },
                    else => @compileError("Text input has invalid text field type"),
                }
                var text = @constCast(look.text);
                const cursor = if (has_cursor) look.cursor else look.text.len;

                if (event.keyboard.character) |char| chr: {
                    const diff = text_fn.inputTextUnicode(
                        text[0..look.text.len],
                        self.capacity,
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
                    if (has_cursor)
                        look.cursor += diff;

                    const len = look.text.len + diff;
                    look.text = text.ptr[0..len];
                    if (event_present) {
                        if (self.onInput) |ie| {
                            const input = std.unicode.utf8Decode(look.text[cursor..][0..diff]) catch return;
                            ui.event = ie(look.text, cursor + diff, input);
                        }
                    }
                    return;
                }
                if (event.keyboard.keycode) |key| {
                    const input = cake.backend.input;
                    if (input.isBackspace(key)) {
                        if (cursor == 0) return;
                        const deletion = text_fn.deleteCharBeforeUnicode(text[0..look.text.len], cursor) orelse return;
                        if (has_cursor)
                            look.cursor -= deletion.size_diff;

                        look.text = text[0..deletion.new_size];
                        if (event_present) {
                            if (self.onDelete) |de| {
                                ui.event = de(look.text, cursor - deletion.size_diff, deletion.deleted);
                            }
                        }
                    }
                    else if (has_cursor and input.isNavLeft(key)) {
                        text_fn.moveCursorCharBackward(look.text[0..look.text.len], &look.cursor);
                        if (event_present) {
                            if (self.onCursorMove) |cme| {
                                ui.event = cme(look.text, cursor, look.cursor);
                            }
                        }
                    }
                    else if (has_cursor and input.isNavRight(key)) {
                        text_fn.moveCursorCharForward(look.text[0..look.text.len], &look.cursor);
                        if (event_present) {
                            if (self.onCursorMove) |cme| {
                                ui.event = cme(look.text, cursor, look.cursor);
                            }
                        }
                    }
                }
            }
            else {
                return error.UnsupportedBehaviorWidgetPair;
            }

        }
        pub fn pointerEvent (self : *@This(), ui : anytype, look : anytype, event : PointerContext) ! cake.EventResult {
            _ = ui;
            _ = self;
            const has_margin = @hasField(@TypeOf(look.*), "margin");
            const has_cursor = @hasField(@TypeOf(look.*), "cursor");
            const has_text = @hasField(@TypeOf(look.*), "text");
            const has_size = @hasField(@TypeOf(look.*), "size");

            if (has_text and has_size) {
                if (event.pointer == .press) {
                    if (has_cursor) {
                        const pointer = event.position[0] - event.area.position[0];
                        var pos : f32 = if (has_margin) look.margin else 0;
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
                    }
                    return .activated;
                }
                return .processed;
            }
            else {
                return error.UnsupportedBehaviorWidgetPair;
            }
        }
    };
}
