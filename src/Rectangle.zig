const std = @import("std");
const assert = std.debug.assert;

const Rectangle = @This();
const Vector = @Vector(2, f32);

const vector_zero = Vector { 0.0, 0.0 };
const vector_half = Vector { 0.5, 0.5 };
const vector_one = Vector { 1.0, 1.0 };
const vector_two = Vector { 2.0, 2.0 };

position : Vector = vector_zero,
size     : Vector = vector_zero,

pub fn contains (self : Rectangle, point : Vector) bool {
    const local = point - self.position;

    if (@reduce(.Or, local < vector_zero)) return false;
    if (@reduce(.Or, local > self.size)) return false;
    return true;
}

pub fn move (self : *Rectangle, delta : Vector) void {
    self.position += delta;
}
pub fn shrinkBy (self : *Rectangle, by : Vector) void {
    assert(@reduce(.And, by <= self.size));
    assert(@reduce(.And, by >= vector_zero));

    self.position += by * vector_half;
    self.size -= by;
}
pub fn shrinkTo (self : *Rectangle, to : Vector) void {
    assert(@reduce(.And, to >= vector_zero));
    assert(@reduce(.And, to <= self.size));

    const diff = self.size - to;
    self.size = to;
    self.position += diff * vector_half;
}
pub fn shrinkByPercent (self : *Rectangle, percent : Vector) void {
    assert(@reduce(.And, percent >= vector_zero ));
    assert(@reduce(.And, percent <= vector_one));

    const p = self.size * percent;
    self.position += p * vector_half;
    self.size -= p;
}
pub fn shrinkToPercent (self : *Rectangle, percent : Vector) void {
    assert(percent > 0.0 and percent <= 1.0);

    const p = self.size * percent;
    const diff = self.size - p;
    self.size = p;
    self.position += diff * vector_half;
}
pub fn shrinkWidthTo (self : *Rectangle, width : f32) void {
    assert (width <= self.size[0]);

    const diff = self.size[0] - width;
    self.size[0] = width;
    self.position[0] += diff * 0.5;
}
pub fn shrinkWidthBy (self : *Rectangle, width : f32) void {
    assert(width <= self.size[0]);

    self.size[0] -= width;
    self.position[0] += width * 0.5;
}
pub fn shrinkHeightTo (self : *Rectangle, height : f32) void {
    assert(self.size[1] >= height);

    const diff = self.size[1] - height;
    self.size[1] = height;
    self.position[1] += diff * 0.5;
}
pub fn shrinkHeightBy (self : *Rectangle, height : f32) void {
    assert(height <= self.size[1]);

    self.size[1] -= height;
    self.position += height * 0.5;
}
pub fn splitHorizontal (self : Rectangle, comptime count : usize, spacing : f32) [count]Rectangle {
    assert(spacing >= 0.0);

    if (count < 2) @compileError("Can't split rectangle in less than 2 parts");

    const height = (self.size[1] - (spacing * (count - 1)) ) / count;

    var result : [count]Rectangle = undefined;
    const size = Vector { self.size[0], height };
    const step = height + spacing;

    for (0..count) |i| {
        result[i] = .{
            .size = size,
            .position = Vector { self.position[0], self.position[1] + @as(f32, @floatFromInt(i)) * step }
        };
    }

    return result;
}
pub fn splitHorizontalPercent (self : Rectangle, comptime count : usize, spacing : f32) [count]Rectangle {
    assert(spacing > 0.0 and spacing <= 1.0);
    const spc = spacing * self.size[1];
    return self.splitHorizontal(count, spc);
}
pub fn splitVertical (self : Rectangle, comptime count : usize, spacing : f32) [count]Rectangle {
    assert(spacing >= 0.0);

    if (count < 2) @compileError("Can't split rectangle in less than 2 parts");

    const width = (self.size[0] - (spacing * (count - 1)) ) / count;

    var result : [count]Rectangle = undefined;
    const size = Vector { width, self.size[1] };
    const step = width + spacing;

    for (0..count) |i| {
        result[i] = .{
            .size = size,
            .position = Vector { self.position[0] + @as(f32, @floatFromInt(i)) * step , self.position[1] }
        };
    }

    return result;
}
pub fn splitVerticalPercent (self : Rectangle, comptime count : usize, spacing : f32) [count]Rectangle {
    assert(spacing > 0.0 and spacing <= 1.0);
    const spc = spacing * self.size[0];
    return self.splitVertical(count, spc);
}
/// Cuts off top or bottom from the rect dependin on whatever the amount is positive or negative
/// Spacing is always cut off the calling rect
pub fn cutHorizontal (self : *Rectangle, amount : f32, spacing : f32) Rectangle {
    const actual_amount = if (amount < 0) -amount else amount;
    const actual_diff = actual_amount + spacing;
    assert(spacing >= 0);
    assert(self.size[1] >= actual_diff);

    var result = self.*;
    result.size[1] = actual_amount;
    self.size[1] -= actual_diff;
    if (amount >= 0) {
        self.position[1] += actual_diff;
    }
    else {
        result.position[1] += self.size[1] + spacing;
    }
    return result;
}
pub fn cutHorizontalPercent (self : *Rectangle, amount : f32, spacing : f32) Rectangle {
    assert(amount >= -1 and amount <= 1);
    assert(spacing >= 0);
    const actual_amount = self.size[1] * amount;
    const actual_spacing = self.size[1] * spacing;
    return self.cutHorizontal(actual_amount, actual_spacing);
}
pub fn cutVertical (self : *Rectangle, amount : f32, spacing : f32) Rectangle {
    const actual_amount = if (amount < 0) -amount else amount;
    const actual_diff = actual_amount + spacing;
    assert(spacing >= 0);
    assert(self.size[0] >= actual_diff);

    var result = self.*;
    result.size[0] = actual_amount;
    self.size[0] -= actual_diff;
    if (amount >= 0) {
        self.position[0] += actual_diff;
    }
    else {
        result.position[0] += self.size[0] + spacing;
    }
    return result;
}
pub fn cutVerticalPercent (self : *Rectangle, amount : f32, spacing : f32) Rectangle {
    assert(amount >= -1 and amount <= 1);
    assert(spacing >= 0);
    const actual_amount = self.size[0] * amount;
    const actual_spacing = self.size[0] * spacing;
    return self.cutVertical(actual_amount, actual_spacing);
}

pub fn clampInsideOf (self : *Rectangle, borders : Rectangle) void {
    const too_large = self.size > borders.size;
    if (@reduce(.Or, too_large)) {
        self.size = @select(f32, too_large, borders.size, self.size);
    }

    const local = self.position - borders.position;
    const too_small = local < vector_zero;
    if (@reduce(.Or, too_small)) {
        self.position = @select(f32, too_small, vector_zero, self.position);
    }

    const over = (self.position + self.size) - (borders.position + borders.size);
    const outside = over > vector_zero;
    if (@reduce(.Or, outside)) {
        const diff = @select(f32, outside, over, vector_zero);
        self.position -= diff;
    }
}

test "horizontal cutting" {
    var rect : Rectangle = .{
        .position = .{ 0, 0 },
        .size = .{ 10, 10 },
    };

    var cut = rect.cutHorizontal(2, 0);
    try std.testing.expectEqualDeep(Vector{0, 2}, rect.position);
    try std.testing.expectEqualDeep(Vector{10, 8}, rect.size);
    try std.testing.expectEqualDeep(Vector{0, 0}, cut.position);
    try std.testing.expectEqualDeep(Vector{10, 2}, cut.size);
}
test "horizontal cutting bottom" {
    var rect : Rectangle = .{
        .position = .{ 0, 0 },
        .size = .{ 10, 10 },
    };

    var cut = rect.cutHorizontal(-2, 1);
    try std.testing.expectEqualDeep(Vector{0, 0}, rect.position);
    try std.testing.expectEqualDeep(Vector{10, 7}, rect.size);
    try std.testing.expectEqualDeep(Vector{0, 8}, cut.position);
    try std.testing.expectEqualDeep(Vector{10, 2}, cut.size);

}
test "horizontal cutting percents" {
    var rect : Rectangle = .{
        .position = .{ 0, 0 },
        .size = .{ 10, 10 },
    };

    var cut = rect.cutHorizontalPercent(0.2, 0.1);
    try std.testing.expectEqualDeep(Vector{0, 3}, rect.position);
    try std.testing.expectEqualDeep(Vector{10, 7}, rect.size);
    try std.testing.expectEqualDeep(Vector{0, 0}, cut.position);
    try std.testing.expectEqualDeep(Vector{10, 2}, cut.size);

}
