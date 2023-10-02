const std = @import("std");
const types = @import("types.zig");

const KeyboardEvent = types.KeyboardEvent;

/// Deletes a character before cursor point by overriding it with following bytes
/// returns new size of the text buffer
pub fn deleteCharBeforeUnicode (text : []u8, cursor : usize) usize {
    if (cursor < 1) return text.len;
    if (text.len == 0) return text.len;
    const pointer = if (cursor > text.len) text.len else cursor;
    var move = pointer;

    moveCursorCharBackward(text, &move);
    if (move == pointer) return 0;
    std.mem.copyForwards(u8, text[move..], text[pointer..]);
    return pointer - move;
}

/// Inputs the unicode character into the string at the cursor.
/// The function returns how many bytes were inserted into the string
/// or error if the character insertion would overflow the buffer
/// or if the codepoint is an invalid unicode character
pub fn inputTextUnicode (
    text_buffer : []u8,
    capacity : usize,
    cursor : usize,
    codepoint : u32
) error { OutOfMemory, InvalidCharacter } ! usize {
    if (codepoint == 0) return error.InvalidCharacter;
    const pointer = if (cursor > text_buffer.len) text_buffer.len else cursor;

    var uni : [4]u8 = undefined;
    var len = std.unicode.utf8Encode(@truncate(codepoint), uni[0..])
        catch return error.InvalidCharacter;

    if (text_buffer.len + len > capacity) return error.OutOfMemory;

    var input = text_buffer.ptr[0..text_buffer.len + len];
    std.mem.copyBackwards(u8, input[pointer + len..], text_buffer[pointer..]);
    @memcpy(input[pointer..][0..len], uni[0..len]);
    return len;
}
/// Calculates how many bytes the cursor must move to be at next character
pub fn moveCursorCharForward (text : []const u8, cursor : *usize) void {
    if (cursor.* >= text.len) {
        cursor.* = text.len;
        return;
    }
    if (text.len == 0) {
        cursor.* = 0;
        return;
    }

    const len = std.unicode.utf8ByteSequenceLength(text[cursor.*]) catch 1;
    cursor.* += len;
}
/// Calculates how many bytes the cursor must move to be at previous character
pub fn moveCursorCharBackward (text : []const u8, cursor : *usize) void {
    if (cursor.* == 0) {
        return;
    }
    if (text.len == 0) {
        cursor.* = 0;
        return;
    }

    var peek = cursor.* - 1;
    while (true) : (peek -= 1) {
        if (std.unicode.utf8ValidateSlice(text[peek..cursor.*])) {
            const diff = cursor.* - peek;
            cursor.* -= diff;
            break;
        }
        if (peek == 0) {
            cursor.* = 0;
            break;
        }
    }
}
