const std = @import("std");
const cake = @import("cake");
const ray = @cImport(@cInclude("raylib.h"));

pub fn main () ! void {
    ray.InitWindow(800, 600, "TODO");
    defer ray.CloseWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var todo = Todo.init(cake.theme_dark, allocator);
    defer todo.deinit();
    try todo.start();

    while (ray.WindowShouldClose() == false) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);
        try todo.update();
        todo.draw();
    }
}

const Event = union (enum) {
    add,
    remove : usize,
    mark : usize,
    slide : f32,

    pub fn onSlider (old : f32, new : f32) Event {
        return .{ .slide = new - old };
    }
};
const InputUi = cake.FixedUi(.{ .Event = Event }, 3);
const ListUi = cake.DynamicUi(.{ .Event = Event });
const Button = cake.premade.Button(Event);
const TextInput = cake.premade.FixedTextInput(256, Event);
const Label = cake.widgets.Decor(cake.contains.FixedStringBuffer(256), cake.looks_like.text_field);
const Slider = cake.premade.WindowScrollVertical(Event, Event.onSlider);

const input_size = 32;
const entry_size = 24;

const Todo = struct {
    input : InputUi,

    text : TextInput = TextInput { .data = .{}, .behavior = .{} },
    add_button : Button = Button { .data = .{ .text = "Add Entry" }, .behavior = .{ .event = .add } },
    slider : Slider,

    list : ListUi,
    entries : std.ArrayList(Entry),
    entries_area : cake.Rectangle = .{},

    pub fn init (theme : cake.DefaultPalette, allocator : std.mem.Allocator) Todo {
        const screen_height = cake.backend.windowHeight();
        return Todo {
            .input = InputUi.init(theme),
            .list = ListUi.init(theme, allocator),
            .slider = .{ .data = .{ .size = screen_height - input_size, .max = 0 } },
            .entries = std.ArrayList(Entry).init(allocator),
        };
    }
    pub fn deinit (self : *Todo) void {
        self.entries.deinit();
        self.list.deinit();
    }

    pub fn start (self : *Todo) ! void {
        try self.connectUi();
        self.layoutUi();
    }
    pub fn update (self : *Todo) ! void {
        const cursor = cake.backend.input.cursorPosition();
        try self.input.setPointerPosition(cursor);
        try self.list.setPointerPosition(cursor);
        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            try self.input.sendPointerEvent(.{ .press = .left });
            try self.list.sendPointerEvent(.{ .press = .left });
        }
        if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_LEFT)) {
            try self.input.sendPointerEvent(.{ .lift = .left });
            try self.list.sendPointerEvent(.{ .lift = .left });
        }
        if (cake.backend.input.keyboardEvent()) |key| {
            self.input.sendKeyboardEvent(key) catch {};
        }
        const wheel = ray.GetMouseWheelMove();
        if (wheel != 0 and self.entries_area.contains(cursor)) {
            self.slider.data.slideValue(-wheel * 10);
            self.layoutEntries();
        }
        if (self.input.popEvent()) |ev| {
            switch (ev) {
                .add => try self.addEntry(),
                .slide => {
                    self.layoutEntries();
                },
                else => unreachable,
            }
        }
        if (self.list.popEvent()) |event| {
            switch (event) {
                .add => unreachable,
                .remove => |idx| {
                    _ = self.entries.orderedRemove(idx);
                    try self.connectEntries();
                    self.slider.data.clampValue();
                    self.layoutEntries();
                },
                .mark => |idx| {
                    self.entries.items[idx].toggleCompleted();
                },
                .slide => unreachable,
            }
        }
    }
    pub fn draw (self : *const Todo) void {
        self.input.draw();
        const area = self.entries_area;
        const x : c_int = @intFromFloat(area.position[0]);
        const y : c_int = @intFromFloat(area.position[1]);
        const width : c_int = @intFromFloat(area.size[0]);
        const height : c_int = @intFromFloat(area.size[1]);
        ray.BeginScissorMode(x, y, width, height);
        self.list.draw();
        ray.EndScissorMode();
    }

    fn connectUi (self : *Todo) ! void {
        const input = self.input.layout();
        try input.addWidget(self.add_button.getInterface(), .{ .theme = .interactive });
        try input.addWidget(self.text.getInterface(), .{ .theme = .interactive });
        try input.addWidget(self.slider.getInterface(), .{ .theme = .interactive });
        try self.connectEntries();
    }
    fn layoutUi (self : *Todo) void {
        var area = cake.backend.windowArea();
        self.text.area = area.cutHorizontal(input_size, 8);
        self.text.area.shrinkWidthByPercent(0.1);
        const add_size = cake.backend.measureText(
            self.add_button.data.text,
            self.add_button.data.font_size
        ) * 1.2;
        self.add_button.area = self.text.area.cutVertical(-add_size, 4);
        self.slider.area = area.cutVertical(-input_size, 4);
        self.entries_area = area;
        self.slider.data.size = area.size[1];
        self.layoutEntries();
    }
    fn connectEntries (self : *Todo) ! void {
        const entries = self.list.layout();
        for (self.entries.items, 0..) |*entry, i| {
            try entry.addToUi(entries);
            entry.setIndex(i);
        }
        self.slider.data.max = ( entry_size + 4 ) * @as(f32, @floatFromInt(self.entries.items.len));
    }
    fn layoutEntries (self : *Todo) void {
        var area = self.entries_area;
        area.size[1] = ( 4 + entry_size ) * @as(f32, @floatFromInt(self.entries.items.len));
        area.position[1] -= self.slider.data.value;

        for (self.entries.items) |*entry| {
            entry.setArea(area.cutHorizontal(entry_size, 4));
        }
    }
    fn addEntry (self : *Todo) ! void {
        const text = self.text.data.getString();
        if (text.len == 0) return;
        self.text.data.len = 0;
        try self.entries.append(Entry.init(text));
        try self.connectEntries();
        self.layoutEntries();
    } 
};
const Entry = struct {
    delete : Button,
    text : Label,
    check : Button,
    completed : bool,

    pub fn init (text : []const u8) Entry {
        var entry = Entry {
            .delete = .{ .data = .{ .text = "X" } },
            .check = .{ .data = .{ .text = "" } },
            .completed = false,
            .text = .{ .data = undefined, }
        };
        @memcpy(entry.text.data.text[0..text.len], text);
        entry.text.data.len = text.len;
        entry.text.data.font_size = entry_size - 4;
        return entry;
    }
    pub fn toggleCompleted (self : *Entry) void {
        self.completed = ! self.completed;
        self.check.data.text = if (self.completed) "X" else "";
    }
    pub fn setIndex (self : *Entry, idx : usize) void {
        self.delete.behavior.event = .{ .remove = idx };
        self.check.behavior.event = .{ .mark = idx };
    }
    pub fn setArea (self : *Entry, area : cake.Rectangle) void {
        self.text.area = area;
        self.check.area = self.text.area.cutVertical(entry_size, 4);
        self.delete.area = self.text.area.cutVertical(-entry_size, 4);
    }
    pub fn addToUi (self : *Entry, ui : ListUi.LayoutContext) ! void {
        try ui.addPlainWidget(self.text.getInterface());
        try ui.addWidget(self.delete.getInterface(), .{ .theme = .danger });
        try ui.addWidget(self.check.getInterface(), .{ .theme = .interactive });
    }
};
