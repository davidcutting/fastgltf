const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pic = b.option(bool, "pic", "platform independent code");
    const strip = b.option(bool, "strip", "strip symbols");

    const lib = b.addLibrary(.{
        .name = "fastgltf",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
            .pic = pic,
            .strip = strip,
        }),
    });

    lib.linkLibC();
    lib.linkLibCpp();

    var simdjson_flags = std.ArrayListUnmanaged([]const u8){};
    simdjson_flags.appendSlice(b.allocator, &.{
        "-DSIMDJSON_IMPLEMENTATION_FALLBACK=1",
        "-DSIMDJSON_FORCE_DISABLE_X86_SIMD=1",
        "-DSIMDJSON_DISABLE_HASWELL=1",
        "-DSIMDJSON_DISABLE_ICELAKE=1",
        "-DSIMDJSON_DISABLE_AVX512=1",
        "-std=c++20",
        "-fno-exceptions",
    }) catch @panic("OOM");

    const simdjson_dep = b.dependency("simdjson", .{
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });

    lib.root_module.addIncludePath(simdjson_dep.path("singleheader"));
    lib.root_module.addCSourceFiles(.{
        .root = simdjson_dep.path("singleheader"),
        .files = &.{"simdjson.cpp"},
        .flags = simdjson_flags.items,
    });

    // fastgltf
    lib.root_module.addIncludePath(b.path("include"));
    lib.root_module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "fastgltf.cpp",
            "base64.cpp",
            "io.cpp",
        },
        .flags = &.{
            "-std=c++20",
        },
    });
    lib.installHeadersDirectory(b.path("include"), "", .{});

    b.installArtifact(lib);
}
