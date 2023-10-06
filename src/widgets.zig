const std = @import("std");
const cake = @import("main.zig");
const types = @import("types.zig");
const text_fn = @import("text.zig");
const renderer = cake.backend;

const Rectangle = @import("Rectangle.zig");
const Context = types.DrawingContext;

pub const BuiltinWidgets = union (enum) {
    label      : Label,
    text_field : TextField,
    display    : TextDisplay,
    text_input : TextInput,
    background : Background,
    frame      : Frame,
};

pub const Label = struct {
    text : []const u8,
    size : f32 = 20,

    pub fn draw (self : Label, widget : anytype, context : Context) void {
        _ = widget;
        const color = context.state.selectColor(context.colors.text);
        renderer.drawText(self.text, context.area.position, @min(self.size, context.area.size[1]), color);
    }
};
pub const TextField = struct {
    text : []const u8,
    size : f32 = 20,
    margin : f32 = 4,

    pub fn draw (self : TextField, widget : anytype, context : Context) void {
        _ = widget;
        var zone = context.area;
        const bg = context.state.selectColor(context.colors.background);
        renderer.drawRectangle(zone, bg);
        zone.shrinkBy(@splat(self.margin));
        const color = context.state.selectColor(context.colors.text);
        renderer.drawText(self.text, zone.position, @min(self.size, zone.size[1]), color);
    }
};
pub const TextDisplay = struct {
    text : []const u8,
    size : f32 = 20,

    pub fn draw (self : TextDisplay, widget : anytype, context : Context) void {
        _ = widget;
        var zone = context.area;
        const bg = context.state.selectColor(context.colors.background);
        renderer.drawRectangle(zone, bg);

        const size = @min(self.size, context.area.size[1]);
        const width = renderer.view.measureText(self.text, size);

        zone.shrinkTo(.{width, size});
        const color = context.state.selectColor(context.colors.text);
        renderer.drawText(self.text, zone.position, size, color);
    }
};
pub const TextInput = struct {
    text : []u8,
    capacity : usize,
    cursor : usize = 0,

    size : f32 = 20,
    margin : f32 = 4,

    pub fn draw (self : TextInput, widget : anytype, context : Context) void {
        _ = widget;
        const background = context.state.selectColor(context.colors.background);
        const text_color = context.state.selectColor(context.colors.text);

        renderer.drawRectangle(context.area, background);

        var text_area = context.area;
        text_area.shrinkBy(@splat(self.margin));
        renderer.drawText(self.text, text_area.position, self.size, text_color);

        if (context.state.focus) {
            const width = if (self.cursor >= self.text.len)
                renderer.view.measureText(self.text, self.size)
                else
                renderer.view.measureText(self.text, self.size) - renderer.view.measureText(self.text[self.cursor..], self.size);

            text_area.move(.{ width, 0 });
            text_area.size[0] = 2;
            renderer.drawRectangle(text_area, context.colors.foreground.focus);
        }
    }
};
pub const Background = struct {
    pub fn draw (self : Background, widget : anytype, context : Context) void {
        _ = widget;
        _ = self;
        const color = context.state.selectColor(context.colors.background);
        renderer.drawRectangle(context.area, color);
    }
};
pub const Frame = struct {
    thickness : f32 = 1.0,

    pub fn draw (self : Frame, widget : anytype, context : Context) void {
        _ = widget;
        const color = context.state.selectColor(context.colors.foreground);
        renderer.drawFrame(context.area, self.thickness, color);
    }
};

