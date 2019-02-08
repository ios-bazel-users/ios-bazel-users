load("@bazel_skylib//lib:paths.bzl", "paths")

def _bitcode_linkopts(ctx):
    bitcode_mode = str(ctx.fragments.apple.bitcode_mode)
    # We don't have to check for device or simulator because bazel does this
    # for us https://github.com/bazelbuild/bazel/blob/2a116372382aedbf8a39477e0ea1123903ab5479/src/main/java/com/google/devtools/build/lib/rules/apple/AppleConfiguration.java#L358-L365
    if bitcode_mode != "embedded":
        return struct(objc = apple_common.new_objc_provider())

    root_build_dir = paths.dirname(ctx.build_file_path)
    symbolmap_path = paths.join(
        ctx.bin_dir.path,
        root_build_dir,
        # This is where bazel requires this file to end up
        ctx.attr.target_name + ".apple_binary.bcsymbolmap",
    )
    linkopts = [
        "-fembed-bitcode",
        "-Wl,-bitcode_verify",
        "-Wl,-bitcode_hide_symbols",
        "-Wl,-bitcode_symbol_map",
        "BITCODE_TOUCH_SYMBOL_MAP=" + symbolmap_path,
    ]

    return struct(
        objc = apple_common.new_objc_provider(
            linkopt = depset(linkopts, order = "preorder"),
        ),
    )

bitcode_linkopts = rule(
    attrs = {
        "target_name": attr.string(mandatory = True),
    },
    fragments = ["apple"],
    implementation = _bitcode_linkopts,
)
