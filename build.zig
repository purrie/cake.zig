const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/cake.zig" },
        .target = target,
        .optimize = optimize,
    });


    const opt = b.addOptions();
    opt.addOption(Backend, "backend", .raylib);
    const options = opt.createModule();
    main_tests.addModule("cake_options", options);
    main_tests.linkLibC();
    main_tests.linkSystemLibrary("raylib");

    const run_main_tests = b.addRunArtifact(main_tests);
    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build test`
    // This will evaluate the `test` step rather than the default, which is "install".
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    buildExample(b, target, optimize);
}

pub const Backend = @import("src/cake.zig").Backend;

/// Adds cake module to the provided build step
/// User is responsible for linking any backend rendering libraries in use
pub fn addCake (
    b : *std.Build,
    exe: *std.build.LibExeObjStep,
    target : std.zig.CrossTarget,
    optimize : std.builtin.OptimizeMode,
    backend : Backend,
) *std.Build.CompileStep {
    const src = comptime std.fs.path.dirname(@src().file).?;
    const cake = b.addStaticLibrary(.{
        .name = "cake",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = src ++ "/src/cake.zig" },
    });

    const opt = b.addOptions();
    opt.addOption(Backend, "backend", backend);
    const options = opt.createModule();

    exe.linkLibrary(cake);
    exe.addAnonymousModule(
        "cake",
        .{
            .source_file = cake.root_src.?,
            .dependencies = &.{
                .{ .name = "cake_options", .module = options }
            }
        }
    );
    return cake;
}

const Examples = enum {
    hello_world,
    styling,
    password_form,
    clicker,
    todo,
};

fn buildExample (b : *std.Build, target : std.zig.CrossTarget, optimize : std.builtin.OptimizeMode) void {
    const example_selected = b.option(Examples, "example", "Select example to run (default: hello_world)") orelse .hello_world;

    const exe = b.addExecutable(.{
        .name = @tagName(example_selected),
        .target = target,
        .optimize = optimize,
        .root_source_file = .{
            .path = switch (example_selected) {
                .hello_world => "examples/hello_world.zig",
                .styling => "examples/styling.zig",
                .password_form => "examples/password.zig",
                .clicker => "examples/clicker.zig",
                .todo => "examples/todo.zig"
            }
        },
    });

    switch (example_selected) {
        .clicker,
        .password_form,
        .styling,
        .todo,
        .hello_world => {
            const cake = addCake(b, exe, target, optimize, .raylib);
            cake.linkLibC();
            cake.linkSystemLibrary("raylib");
        }
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("example", "Run the selected example");
    run_step.dependOn(&run_cmd.step);
}
