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
    min : f32 = 0,
    max : f32 = 1,
    value : f32 = 0,
    size : f32 = 0,

    /// Slides value by specified amount between min and max - size
    pub fn slideValue (self : *SizedRange, by : f32) void {
        self.value = @max(self.min, @min(self.max - self.size, self.value + by));
    }
    /// Clamps value to be between min and max - size, both inclusive
    pub fn clampValue (self : *SizedRange) void {
        self.value = @max(self.min, @min(self.max - self.size, self.value));
    }
};
