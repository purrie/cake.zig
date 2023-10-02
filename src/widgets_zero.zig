const std = @import("std");
const cake = @import("main.zig");
const types = @import("types.zig");
const text_fn = @import("text.zig");

const Rectangle = @import("Rectangle.zig");
const ColorScheme = types.ColorScheme;
const DrawFilter = types.DrawFilter;
const KeyboardEvent = types.KeyboardEvent;

pub fn ExtendedWidgets (comptime Event : type) type {
    return union (enum) {
        label      : Label,
        text_field : TextField,
        display    : TextDisplay,
        text_input : TextInput,
        background : Background,
        frame      : Frame,
        button     : Button(Event),
    };
}

pub const BuiltinWidgets = union (enum) {
    label      : Label,
    text_field : TextField,
    display    : TextDisplay,
    text_input : TextInput,
    background : Background,
    frame      : Frame,
};

pub const Label = struct {
    text : [:0]const u8,
    size : f32 = 20,

    pub fn draw (self : Label, area : Rectangle, colors : ColorScheme, state : DrawFilter, comptime renderer : type) void {
        const color = state.selectColor(&colors.text);
        renderer.drawText(self.text, area.position, @min(self.size, area.size[1]), color);
    }
};
pub const TextField = struct {
    text : [:0]const u8,
    size : f32 = 20,
    margin : f32 = 4,

    pub fn draw (self : TextField, area : Rectangle, colors : ColorScheme, state : DrawFilter, comptime renderer : type) void {
        var zone = area;
        const bg = state.selectColor(&colors.background);
        renderer.drawRectangle(zone, bg);
        zone.shrinkBy(@splat(self.margin));
        const color = state.selectColor(&colors.text);
        renderer.drawText(self.text, zone.position, @min(self.size, zone.size[1]), color);
    }
};
pub const TextDisplay = struct {
    text : [:0]const u8,
    size : f32 = 20,

    pub fn draw (self : TextDisplay, area : Rectangle, colors : ColorScheme, state : DrawFilter, comptime renderer : type) void {
        var zone = area;
        const bg = state.selectColor(&colors.background);
        renderer.drawRectangle(zone, bg);

        const size = @min(self.size, area.size[1]);
        const width = renderer.view.measureText(self.text, size);

        zone.shrinkTo(.{width, size});
        const color = state.selectColor(&colors.text);
        renderer.drawText(self.text, zone.position, size, color);
    }
};
pub fn Button (comptime Event : type) type {
    return struct {
        text : [:0]const u8,
        size : f32 = 20,
        event : Event,

        pub fn draw (self : @This(), area : Rectangle, colors : ColorScheme, state : DrawFilter, comptime renderer : type) void {
            var zone = area;
            const bg = state.selectColor(&colors.background);
            renderer.drawRectangle(zone, bg);

            const size = @min(self.size, area.size[1]);
            const width = renderer.view.measureText(self.text, size);

            zone.shrinkTo(.{width, size});
            const color = state.selectColor(&colors.text);
            renderer.drawText(self.text, zone.position, size, color);
        }
        pub fn pointerEvent (self : *@This(), ui : anytype, event : anytype) ! cake.EventResult {
            switch (event.kind) {
                .press => {
                    return .activated;
                },
                .lift => {
                    if (ui.focus == event.idx) {
                        ui.event = self.event;
                    }
                    return .deactivated;
                },
                else => return .processed,
            }
        }
    };
}
pub const TextInput = struct {
    text : [:0]u8,
    capacity : usize,
    cursor : usize = 0,

    size : f32 = 20,
    margin : f32 = 4,

    pub fn draw (self : TextInput, area : Rectangle, colors : ColorScheme, state : DrawFilter, comptime renderer : type) void {
        const background = state.selectColor(&colors.background);
        const text_color = state.selectColor(&colors.text);

        renderer.drawRectangle(area, background);

        var text_area = area;
        text_area.shrinkBy(@splat(self.margin));
        renderer.drawText(self.text, text_area.position, self.size, text_color);

        if (state.focus) {
            const width = if (self.cursor >= self.text.len)
                renderer.view.measureText(self.text, self.size)
                else
                renderer.view.measureText(self.text, self.size) - renderer.view.measureText(self.text[self.cursor..], self.size);

            text_area.move(.{ width, 0 });
            text_area.size[0] = 2;
            renderer.drawRectangle(text_area, colors.foreground.focus);
        }
    }
    pub fn inputEvent (self : *TextInput, ui : anytype, pointer : anytype, keyboard : cake.KeyboardEvent) ! cake.EventResult {
        try self.keyboardEvent(ui, keyboard);
        return self.pointerEvent(ui, pointer);
    }
    pub fn keyboardEvent (self : *TextInput, ui : anytype, event : cake.KeyboardEvent) ! void {
        _ = ui;
        if (event.character) |char| chr: {
            const diff = text_fn.inputTextUnicode(
                self.text[0..self.text.len],
                self.capacity - 1,
                self.cursor,
                char
            ) catch |err| switch (err) {
                error.OutOfMemory => return,
                error.InvalidCharacter => break :chr,
                else => return err,
            };
            if (diff == 0) {
                return;
            }
            self.cursor += diff;

            const len = self.text.len + diff;
            @memset(self.text.ptr[len..len+1], 0);
            self.text = self.text.ptr[0..len :0];
            return;
        }
        if (event.keycode) |key| {
            if (cake.backend.input.isBackspace(key)) {
                const diff = text_fn.deleteCharBeforeUnicode(self.text[0..self.text.len], self.cursor);
                if (diff == 0) {
                    return;
                }
                std.debug.print("Len: {d}", .{diff});
                self.cursor -= diff;

                const len = self.text.len - diff;
                self.text[len] = 0;
                self.text = self.text[0..len :0];
            }
            else if (cake.backend.input.isNavLeft(key)) {
                text_fn.moveCursorCharBackward(self.text[0..self.text.len], &self.cursor);
            }
            else if (cake.backend.input.isNavRight(key)) {
                text_fn.moveCursorCharForward(self.text[0..self.text.len], &self.cursor);
            }
        }
    }
    pub fn pointerEvent (self : *TextInput, ui : anytype, event : anytype) ! cake.EventResult {
        if (event.kind == .press) {
            const UiType = @typeInfo(@TypeOf(ui)).Pointer.child;
            const pointer = ( ui.pointer orelse return .ignored )[0] - ui.zones[event.idx].position[0];
            var pos = self.margin;
            var idx : usize = 0;
            var char_buff = [_]u8{0} ** 5;
            while (idx < self.text.len) {
                const len = std.unicode.utf8ByteSequenceLength(self.text[idx]) catch return error.InvalidCharacter;
                @memcpy(char_buff[0..len], self.text[idx..][0..len]);
                char_buff[len] = 0;
                const width = UiType.Context.renderer.view.measureText(char_buff[0..len :0], self.size);
                const width_half = 0.5 * width;
                if (pointer > pos + width_half) {
                    idx += len;
                    pos += width;
                }
                else {
                    break;
                }
            }
            self.cursor = idx;
            return .activated;
        }
        return .processed;
    }
};
pub const Background = struct {
    pub fn draw (self : Background, area : Rectangle, colors : ColorScheme, state : DrawFilter, comptime renderer : type) void {
        _ = self;
        const color = state.selectColor(&colors.background);
        renderer.drawRectangle(area, color);
    }
};
pub const Frame = struct {
    thickness : f32 = 1.0,

    pub fn draw (self : Frame, area : Rectangle, colors : ColorScheme, state : DrawFilter, comptime renderer : type) void {
        const color = state.selectColor(&colors.foreground);
        renderer.drawRectangleFrame(area, self.thickness, color);
    }
};

pub const Image = struct {
    handle : []const u8, // TODO this should probably be backend specific?
};
