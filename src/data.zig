pub const Text = struct {
    text : []const u8,
    font_size : f32 = 20,
};
pub fn FixedStringBuffer (comptime size : usize) type {
    return struct {
        text : [size]u8 = [_]u8{0} ** size,
        len : usize = 0,
        cursor : usize = 0,
        font_size : f32 = 20,

        pub fn getString(self : *const @This()) []const u8 {
            return self.text[0..self.len];
        }
    };
}
pub const Frame = struct {
    thickness : f32 = 2,
};
pub const SizedRange = struct {
    min : f32,
    max : f32,
    value : f32,
    size : f32,
};
