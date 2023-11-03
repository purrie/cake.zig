const cake = @import("cake.zig");
const contains = cake.contains;
const looks_like = cake.looks_like;
const acts_like = cake.acts_like;

pub const Background = cake.widgets.Decor(void, looks_like.background);
pub const Frame = cake.widgets.Decor(contains.Frame, looks_like.frame);
pub const Label = cake.widgets.Decor(contains.Text, looks_like.label);
pub const Plaque = cake.widgets.Decor(contains.Text, looks_like.text_display);

pub fn Button (comptime Event : type) type {
    return cake.widgets.Widget(contains.Text, looks_like.text_display, acts_like.Button(Event));
}
pub fn FixedTextInput (comptime size : usize, comptime Event : type) type {
    return cake.widgets.Widget(contains.FixedStringBuffer(size), looks_like.text_input, acts_like.TextInput(Event));
}
