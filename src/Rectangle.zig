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

/// Decreases size of the rect while keeping it in the center
pub fn shrinkBy (self : *Rectangle, by : Vector) void {
    assert(@reduce(.And, by <= self.size));
    assert(@reduce(.And, by >= vector_zero));

    self.position += by * vector_half;
    self.size -= by;
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkTo (self : *Rectangle, to : Vector) void {
    assert(@reduce(.And, to >= vector_zero));
    assert(@reduce(.And, to <= self.size));

    const diff = self.size - to;
    self.size = to;
    self.position += diff * vector_half;
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkByPercent (self : *Rectangle, percent : Vector) void {
    assert(@reduce(.And, percent >= vector_zero ));
    assert(@reduce(.And, percent <= vector_one));

    const p = self.size * percent;
    self.position += p * vector_half;
    self.size -= p;
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkToPercent (self : *Rectangle, percent : Vector) void {
    assert(percent > 0.0 and percent <= 1.0);

    const p = self.size * percent;
    const diff = self.size - p;
    self.size = p;
    self.position += diff * vector_half;
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkWidthTo (self : *Rectangle, width : f32) void {
    assert (width <= self.size[0]);

    const diff = self.size[0] - width;
    self.size[0] = width;
    self.position[0] += diff * 0.5;
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkWidthBy (self : *Rectangle, width : f32) void {
    assert(width <= self.size[0]);

    self.size[0] -= width;
    self.position[0] += width * 0.5;
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkWidthToPercent (self : *Rectangle, width : f32) void {
    assert(width >= 0 and width <= 1);

    const w = self.size[1] * width;
    self.shrinkWidthTo(w);
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkWidthByPercent (self : *Rectangle, width : f32) void {
    assert(width >= 0 and width <= 1);

    const w = self.size[1] * width;
    self.shrinkWidthBy(w);
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkHeightTo (self : *Rectangle, height : f32) void {
    assert(self.size[1] >= height);

    const diff = self.size[1] - height;
    self.size[1] = height;
    self.position[1] += diff * 0.5;
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkHeightBy (self : *Rectangle, height : f32) void {
    assert(height <= self.size[1]);

    self.size[1] -= height;
    self.position += height * 0.5;
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkHeightToPercent (self : *Rectangle, height : f32) void {
    assert(height >= 0 and height <= 1);

    const h = self.size[1] * height;
    self.shrinkHeightTo(h);
}
/// Decreases size of the rect while keeping it in the center
pub fn shrinkHeightByPercent (self : *Rectangle, height : f32) void {
    assert(height >= 0 and height <= 1);

    const h = self.size[1] * height;
    self.shrinkHeightBy(h);
}

/// Decreases size of the rect towards the bottom right corner
pub fn squishBy (self : *Rectangle, by : Vector) void {
    assert(@reduce(.And, by <= self.size));
    assert(@reduce(.And, by >= vector_zero));

    self.position += by;
    self.size -= by;
}
/// Decreases size of the rect towards the bottom right corner
pub fn squishTo (self : *Rectangle, to : Vector) void {
    assert(@reduce(.And, to >= vector_zero));
    assert(@reduce(.And, to <= self.size));

    const diff = self.size - to;
    self.size = to;
    self.position += diff;
}
/// Decreases size of the rect towards the bottom right corner
pub fn squishByPercent (self : *Rectangle, percent : Vector) void {
    assert(@reduce(.And, percent >= vector_zero ));
    assert(@reduce(.And, percent <= vector_one));

    const p = self.size * percent;
    self.position += p;
    self.size -= p;
}
/// Decreases size of the rect towards the bottom right corner
pub fn squishToPercent (self : *Rectangle, percent : Vector) void {
    assert(percent > 0.0 and percent <= 1.0);

    const p = self.size * percent;
    const diff = self.size - p;
    self.size = p;
    self.position += diff;
}
/// Decreases size of the rect towards the right side
pub fn squishWidthTo (self : *Rectangle, width : f32) void {
    assert (width <= self.size[0]);

    const diff = self.size[0] - width;
    self.size[0] = width;
    self.position[0] += diff;
}
/// Decreases size of the rect towards the right side
pub fn squishWidthBy (self : *Rectangle, width : f32) void {
    assert(width <= self.size[0]);

    self.size[0] -= width;
    self.position[0] += width;
}
/// Decreases size of the rect towards the right side
pub fn squishWidthToPercent (self : *Rectangle, width : f32) void {
    assert(width >= 0 and width <= 1);

    const w = self.size[1] * width;
    self.squishWidthTo(w);
}
/// Decreases size of the rect towards the right side
pub fn squishWidthByPercent (self : *Rectangle, width : f32) void {
    assert(width >= 0 and width <= 1);

    const w = self.size[1] * width;
    self.squishWidthBy(w);
}
/// Decreases size of the rect towards the bottom
pub fn squishHeightTo (self : *Rectangle, height : f32) void {
    assert(self.size[1] >= height);

    const diff = self.size[1] - height;
    self.size[1] = height;
    self.position[1] += diff;
}
/// Decreases size of the rect towards the bottom
pub fn squishHeightBy (self : *Rectangle, height : f32) void {
    assert(height <= self.size[1]);

    self.size[1] -= height;
    self.position[1] += height;
}
/// Decreases size of the rect towards the bottom
pub fn squishHeightToPercent (self : *Rectangle, height : f32) void {
    assert(height >= 0 and height <= 1);

    const h = self.size[1] * height;
    self.squishHeightTo(h);
}
/// Decreases size of the rect towards the bottom
pub fn squishHeightByPercent (self : *Rectangle, height : f32) void {
    assert(height >= 0 and height <= 1);

    const h = self.size[1] * height;
    self.squishHeightBy(h);
}

/// Splits the rect into equally sized rectangles with optional spacing between them
pub fn splitHorizontal (self : Rectangle, comptime rows : usize, spacing : f32) [rows]Rectangle {
    assert(spacing >= 0.0);

    if (rows < 2) @compileError("Can't split rectangle in less than 2 parts");

    const height = (self.size[1] - (spacing * (rows - 1)) ) / rows;

    var result : [rows]Rectangle = undefined;
    const size = Vector { self.size[0], height };
    const step = height + spacing;

    for (0..rows) |i| {
        result[i] = .{
            .size = size,
            .position = Vector { self.position[0], self.position[1] + @as(f32, @floatFromInt(i)) * step }
        };
    }

    return result;
}
/// Splits the rect into equally sized rectangles with optional spacing between them
pub fn splitHorizontalPercent (self : Rectangle, comptime rows : usize, spacing : f32) [rows]Rectangle {
    assert(spacing > 0.0 and spacing <= 1.0);
    const spc = spacing * self.size[1];
    return self.splitHorizontal(rows, spc);
}
/// Splits the rect into equally sized rectangles with optional spacing between them
pub fn splitVertical (self : Rectangle, comptime columns : usize, spacing : f32) [columns]Rectangle {
    assert(spacing >= 0.0);

    if (columns < 2) @compileError("Can't split rectangle in less than 2 parts");

    const width = (self.size[0] - (spacing * (columns - 1)) ) / columns;

    var result : [columns]Rectangle = undefined;
    const size = Vector { width, self.size[1] };
    const step = width + spacing;

    for (0..columns) |i| {
        result[i] = .{
            .size = size,
            .position = Vector { self.position[0] + @as(f32, @floatFromInt(i)) * step , self.position[1] }
        };
    }

    return result;
}
/// Splits the rect into equally sized rectangles with optional spacing between them
pub fn splitVerticalPercent (self : Rectangle, comptime columns : usize, spacing : f32) [columns]Rectangle {
    assert(spacing > 0.0 and spacing <= 1.0);
    const spc = spacing * self.size[0];
    return self.splitVertical(columns, spc);
}

/// Cuts off top or bottom from the rect depending on whatever the amount is positive or negative
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
/// Cuts off top or bottom percentage of the rectangle depending on whatever the amount is positive or negative
/// Spacing is always cut off the calling rect
pub fn cutHorizontalPercent (self : *Rectangle, amount : f32, spacing : f32) Rectangle {
    assert(amount >= -1 and amount <= 1);
    assert(spacing >= 0);
    const actual_amount = self.size[1] * amount;
    const actual_spacing = self.size[1] * spacing;
    return self.cutHorizontal(actual_amount, actual_spacing);
}
/// Cuts off left or right side of the rectangle depending on whatever the amount is positive or negative
/// Spacing is always cut off the calling rect
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
/// Cuts off left or right side by percentage of the rectangle depending on whatever the amount is positive or negative
/// Spacing is always cut off the calling rect
pub fn cutVerticalPercent (self : *Rectangle, amount : f32, spacing : f32) Rectangle {
    assert(amount >= -1 and amount <= 1);
    assert(spacing >= 0);
    const actual_amount = self.size[0] * amount;
    const actual_spacing = self.size[0] * spacing;
    return self.cutVertical(actual_amount, actual_spacing);
}

/// Moves the rect so all of its area is within borders.
/// If rect is larger than borders, it will be shrinked
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
