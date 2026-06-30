const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const semver = try incrementBuildNumber(b);

    const lib_mod = b.addModule("libfilebender", .{
        .root_source_file = b.path("src/libfilebender/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    addLib(b, lib_mod, semver);
    addGui(b, lib_mod, target, optimize);
    addTests(b, lib_mod, target, optimize);
}

fn addLib(b: *std.Build, lib_mod: *std.Build.Module, semver: std.SemanticVersion) void {
    const lib_step = b.step("lib", "Build only the library (static + dynamic)");

    const static_lib = b.addLibrary(.{
        .name = "filebender",
        .linkage = .static,
        .root_module = lib_mod,
        .version = semver,
    });
    const dynamic_lib = b.addLibrary(.{
        .name = "filebender",
        .linkage = .dynamic,
        .root_module = lib_mod,
        .version = semver,
    });
    const install_static = b.addInstallArtifact(static_lib, .{});
    const install_dynamic = b.addInstallArtifact(dynamic_lib, .{});
    const install_headers = b.addInstallDirectory(.{
        .source_dir = b.path("include"),
        .install_dir = .header,
        .install_subdir = "",
    });

    b.getInstallStep().dependOn(&install_static.step);
    b.getInstallStep().dependOn(&install_dynamic.step);
    b.getInstallStep().dependOn(&install_headers.step);
    lib_step.dependOn(&install_static.step);
    lib_step.dependOn(&install_dynamic.step);
    lib_step.dependOn(&install_headers.step);
}

fn addGui(
    b: *std.Build,
    lib_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/gui/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("libfilebender", lib_mod);

    const exe = b.addExecutable(.{ .name = "filebender", .root_module = exe_mod });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the GUI app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);
}

fn addTests(
    b: *std.Build,
    lib_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const lib_tests = b.addTest(.{ .root_module = lib_mod });
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("include/filebender.h"),
        .target = target,
        .optimize = optimize,
    });
    lib_tests.root_module.addImport("filebender_h", translate_c.createModule());
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const gui_mod = b.createModule(.{
        .root_source_file = b.path("src/gui/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    gui_mod.addImport("libfilebender", lib_mod);
    const gui_tests = b.addTest(.{ .root_module = gui_mod });
    const run_gui_tests = b.addRunArtifact(gui_tests);

    const Scope = enum { lib, gui };
    const scope = b.option(Scope, "scope", "Test scope (leave blank for all)");
    const test_step = b.step("test", "Run tests (-Dscope=lib|gui)");
    if (scope == null or scope.? == .lib)
        test_step.dependOn(&run_lib_tests.step);
    if (scope == null or scope.? == .gui)
        test_step.dependOn(&run_gui_tests.step);
}

fn incrementBuildNumber(b: *std.Build) !std.SemanticVersion {
    const alloc = b.allocator;
    const manifest = @embedFile("build.zig.zon");
    const range = try findVersion(manifest);
    const old_version = manifest[range.start..range.end];
    const new_version = try bumpVersion(alloc, old_version);
    const new_manifest = try std.mem.concat(alloc, u8, &.{ manifest[0..range.start], new_version, manifest[range.end..] });

    const io = b.graph.io;
    var file = try b.build_root.handle.openFile(io, "build.zig.zon", .{ .mode = .write_only });
    defer file.close(io);
    var buf: [4096]u8 = undefined;
    var w = file.writer(io, &buf);
    try w.interface.writeAll(new_manifest);
    try w.interface.flush();

    return std.SemanticVersion.parse(new_version);
}

const field = "version";
fn findVersion(manifest: []const u8) !struct { start: usize, end: usize } {
    var i: usize = 0;

    while (i + field.len < manifest.len) : (i += 1) {
        if (!std.mem.eql(u8, manifest[i .. i + field.len], field)) continue;

        i += field.len;
        while (i < manifest.len and std.ascii.isWhitespace(manifest[i])) i += 1;
        if (i >= manifest.len or manifest[i] != '=') continue;
        i += 1;
        while (i < manifest.len and std.ascii.isWhitespace(manifest[i])) i += 1;
        if (i >= manifest.len or manifest[i] != '"') return error.MalformedVersion;

        const start = i + 1;
        i = start;
        while (i < manifest.len and manifest[i] != '"') i += 1;
        if (i >= manifest.len) return error.UnterminatedString;

        return .{ .start = start, .end = i };
    }

    return error.VersionNotFound;
}

fn bumpVersion(alloc: std.mem.Allocator, old: []const u8) ![]u8 {
    var it = std.mem.splitScalar(u8, old, '+');
    const base = it.next() orelse return error.InvalidVersion;
    const build_str = it.next() orelse "0";
    const build_num = try std.fmt.parseInt(usize, build_str, 10) + 1;
    return std.fmt.allocPrint(alloc, "{s}+{d}", .{ base, build_num });
}
