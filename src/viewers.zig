const std = @import("std");
const types = @import("types.zig");

const Context = types.DrawingContext;
const isContainer = std.meta.trait.isContainer;
const isMethod = @import("widgets.zig").isMethod;

/// Creates a namespace of viewers that use provided renderer
pub fn viewers(comptime Renderer : type) type {
    return struct {
        pub const label = struct {
            pub fn validate (comptime Data : type) bool {
                const result = if (@hasDecl(Data, "getString"))
                    true
                else if (@hasField(Data, "text"))
                    true
                else false;

                if (result == false) return false;

                return if (@hasDecl(Data, "getFontSize"))
                    true
                else if (@hasField(Data, "font_size"))
                    true
                else if (@hasField(Data, "size"))
                    true
                else false;
            }
            pub fn draw (data : anytype, context : Context) void {
                const Data = switch(@typeInfo(@TypeOf(data))) {
                    .Pointer => |ptr| ptr.child,
                    else => @TypeOf(data),
                };
                const text = if (@hasDecl(Data, "getString")) txt: {
                    if (comptime isMethod("getString")(Data)) {
                        break :txt data.getString();
                    }
                    else {
                        break :txt Data.getString();
                    }
                }
                else if (@hasField(Data, "text"))
                    data.text
                else @compileError("Viewer was unable to find where to look for text to render");

                const font_size = if (@hasDecl(Data, "getFontSize")) txt: {
                    if (comptime isMethod("getFontSize")(Data)) {
                        break :txt data.getFontSize();
                    }
                    else {
                        break :txt Data.getFontSize();
                    }
                }
                else if (@hasField(Data, "font_size"))
                    data.font_size
                else if (@hasField(Data, "size"))
                    data.size
                else @compileError("Viewer was unable to find font size to render text at");

                Renderer.drawText(
                    text,
                    context.area.position,
                    @min(font_size, context.area.size[1]),
                    context.state.selectColor(context.colors.text)
                );
            }
        };
        pub const text_field = struct {
            pub const validate = label.validate;
            pub fn draw (data : anytype, context : Context) void {
                const Data = switch(@typeInfo(@TypeOf(data))) {
                    .Pointer => |ptr| ptr.child,
                    else => @TypeOf(data),
                };
                const text = if (@hasDecl(Data, "getString")) txt: {
                    if (comptime isMethod("getString")(Data)) {
                        break :txt data.getString();
                    }
                    else {
                        break :txt Data.getString();
                    }
                }
                else if (@hasField(Data, "text"))
                    data.text
                else @compileError("Viewer was unable to find where to look for text to render");

                const font_size = if (@hasDecl(Data, "getFontSize")) fnt: {
                    if (comptime isMethod("getFontSize")(Data)) {
                        break :fnt data.getFontSize();
                    }
                    else {
                        break :fnt Data.getFontSize();
                    }
                }
                else if (@hasField(Data, "font_size"))
                    data.font_size
                else if (@hasField(Data, "size"))
                    data.size
                else @compileError("Viewer was unable to find font size to render text at");

                const margin = if (@hasDecl(Data, "getMargin")) mrg: {
                    if (comptime isMethod("getMargin")(Data)) {
                        break :mrg data.getMargin();
                    }
                    else {
                        break :mrg Data.getMargin();
                    }
                }
                else if (@hasField(Data, "margin"))
                    data.margin
                else 0.0;

                const bg = context.state.selectColor(context.colors.background);
                const color = context.state.selectColor(context.colors.text);

                var zone = context.area;
                Renderer.drawRectangle(zone, bg);
                const size = @min(font_size, zone.size[1]);
                zone.squishWidthBy(4);
                if (margin == 0) {
                    zone.shrinkHeightTo(size);
                }
                else {
                    zone.shrinkBy(@splat(margin));
                }
                Renderer.drawText(text, zone.position, size, color);
            }
        };
        pub const text_display = struct {
            pub const validate = label.validate;
            pub fn draw (data : anytype, context : Context) void {
                const Data = switch(@typeInfo(@TypeOf(data))) {
                    .Pointer => |ptr| ptr.child,
                    else => @TypeOf(data),
                };
                const text = if (@hasDecl(Data, "getString")) txt: {
                    if (comptime isMethod("getString")(Data)) {
                        break :txt data.getString();
                    }
                    else {
                        break :txt Data.getString();
                    }
                }
                else if (@hasField(Data, "text"))
                    data.text
                else @compileError("Viewer was unable to find where to look for text to render");

                const font_size = if (@hasDecl(Data, "getFontSize")) fnt: {
                    if (comptime isMethod("getFontSize")(Data)) {
                        break :fnt data.getFontSize();
                    }
                    else {
                        break :fnt Data.getFontSize();
                    }
                }
                else if (@hasField(Data, "font_size"))
                    data.font_size
                else if (@hasField(Data, "size"))
                    data.size
                else @compileError("Viewer was unable to find font size to render text at");

                var zone = context.area;
                const bg = context.state.selectColor(context.colors.background);
                Renderer.drawRectangle(zone, bg);

                const size = @min(font_size, context.area.size[1]);
                const width = Renderer.measureText(text, size);

                zone.shrinkTo(.{width, size});
                const color = context.state.selectColor(context.colors.text);
                Renderer.drawText(text, zone.position, size, color);
            }
        };
        pub const text_input = struct {
            pub fn validate (comptime Data : type) bool {
                const result = if (@hasDecl(Data, "getString"))
                    true
                else if (@hasField(Data, "text"))
                    true
                else false;

                if (result == false) return false;

                return if (@hasDecl(Data, "getFontSize"))
                    true
                else if (@hasField(Data, "font_size"))
                    true
                else if (@hasField(Data, "size"))
                    true
                else false;
            }
            pub fn draw (data : anytype, context : Context) void {
                const Data = switch(@typeInfo(@TypeOf(data))) {
                    .Pointer => |ptr| ptr.child,
                    else => @TypeOf(data),
                };

                const text = if (@hasDecl(Data, "getString")) txt: {
                    if (comptime isMethod("getString")(Data)) {
                        break :txt data.getString();
                    }
                    else {
                        break :txt Data.getString();
                    }
                }
                else if (@hasField(Data, "text")) txt: {
                    switch (@typeInfo(@TypeOf(data.text))) {
                        .Pointer => |ptr| {
                            if (ptr.child != u8)
                                @compileError("Text Input viewer requires text field to be based on u8");
                            if (ptr.size != .Slice)
                                @compileError("Text Input viewer requires text field to be a slice or an array");
                            if (ptr.sentinel != null)
                                @compileError("Text Input viewer does not support sentinel guarded slices");
                            break :txt data.text;
                        },
                        .Array => |ar| {
                            if (ar.child != u8)
                                @compileError("Text Input viewer requires text field to be based on u8");
                            if (@hasField(Data, "len") == false)
                                @compileError("Text Input viewer requires text array to be acompanied with len field");
                            break :txt data.text[0..data.len];
                        },
                        else =>
                            @compileError("Text Input viewer requires text field to be a slice or array"),
                    }
                }
                else @compileError("Viewer could not find text to render");

                const font_size = if (@hasDecl(Data, "getFontSize")) fnt: {
                    if (comptime isMethod("getFontSize")(Data)) {
                        break :fnt data.getFontSize();
                    }
                    else {
                        break :fnt Data.getFontSize();
                    }
                }
                else if (@hasField(Data, "font_size"))
                    data.font_size
                else if (@hasField(Data, "size"))
                    data.size
                else @compileError("Viewer could not find font size to render the text at");

                const cursor = if (@hasDecl(Data, "getCursor")) crs: {
                    if (comptime isMethod("getCursor")) {
                        break :crs data.getCursor();
                    }
                    else {
                        break :crs Data.getCursor();
                    }
                }
                else if (@hasField(Data, "cursor"))
                    data.cursor
                else text.len;

                const margin = if (@hasDecl(Data, "getMargin")) mrg: {
                    if (comptime isMethod("getMargin")(Data)) {
                        break :mrg data.getMargin();
                    }
                    else {
                        break :mrg Data.getMargin();
                    }
                }
                else if (@hasField(Data, "margin"))
                    data.margin
                else 0.0;

                const bg = context.state.selectColor(context.colors.background);
                const text_color = context.state.selectColor(context.colors.text);

                Renderer.drawRectangle(context.area, bg);

                var text_area = context.area;
                text_area.squishWidthBy(4);
                if (margin == 0) {
                    text_area.shrinkHeightTo(font_size);
                }
                else {
                    text_area.shrinkBy(@splat(margin));
                }
                Renderer.drawText(text, text_area.position, font_size, text_color);

                if (context.state.focus) {
                    const width = if (cursor >= text.len)
                        Renderer.measureText(text, font_size)
                        else
                        Renderer.measureText(text, font_size) - Renderer.measureText(text[cursor..], font_size);

                    text_area.move(.{ width, 0 });
                    text_area.size[0] = 2;
                    Renderer.drawRectangle(text_area, context.colors.foreground.focus);
                }
            }
        };
        pub const background = struct {
            pub fn draw (data : anytype, context : Context) void {
                _ = data;
                const color = context.state.selectColor(context.colors.background);
                Renderer.drawRectangle(context.area, color);
            }
        };
        pub const frame = struct {
            pub fn draw (data : anytype, context : Context) void {
                const Data = switch(@typeInfo(@TypeOf(data))) {
                    .Pointer => |ptr| ptr.child,
                    else => @TypeOf(data),
                };
                const thickness = if (comptime isContainer(Data) and @hasDecl(Data, "getThickness")) thc: {
                    if (comptime isMethod("getThickness")(Data)) {
                        break :thc data.getThickness();
                    }
                    else {
                        break :thc Data.getThickness();
                    }
                }
                else if (comptime isContainer(Data) and @hasField(Data, "thickness"))
                    data.thickness
                else 1.0;

                const color = context.state.selectColor(context.colors.foreground);
                Renderer.drawFrame(context.area, thickness, color);
            }
        };
        pub const window_scroll_vertical = struct {
            pub fn validate (comptime Data : type) bool {
                if (! @hasField(Data, "min")) return false;
                if (! @hasField(Data, "max")) return false;
                if (! @hasField(Data, "value")) return false;
                if (! @hasField(Data, "size")) return false;
                return true;
            }
            pub fn draw (data : anytype, context : Context) void {
                std.debug.assert(data.size >= 0.0);

                const color_bg = context.colors.background.normal;
                const color = context.state.selectColor(context.colors.foreground);

                Renderer.drawRectangle(context.area, color_bg);

                var area = context.area;
                area.shrinkBy(.{ @min(6, context.area.size[0] * 0.1), @min(6, context.area.size[1] * 0.1) });
                const total_size = data.max - data.min;

                if (total_size > data.size) {
                    const diff = data.size / total_size;
                    area.size[1] *= diff;
                    const pos_percent = @min(total_size - data.size, data.value - data.min ) / ( total_size - data.size );
                    area.position[1] += (context.area.size[1] - area.size[1]) * pos_percent;
                    Renderer.drawRectangle(area, color);
                }
                else {
                    Renderer.drawRectangle(area, color);
                }
            }
        };
    };
}
