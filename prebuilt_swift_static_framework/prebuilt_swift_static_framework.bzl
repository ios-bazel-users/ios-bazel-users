load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo", "swift_library")

_PLATFORM_TO_SWIFTMODULE = {
    "ios_armv7": "arm",
    "ios_arm64": "arm64",
    "ios_i386": "i386",
    "ios_x86_64": "x86_64",
}

def _zip_binary_arg(module_name, input_file):
    return "{module_name}.framework/{module_name}={file_path}".format(
        module_name = module_name,
        file_path = input_file.path,
    )

def _zip_swift_arg(module_name, swift_identifier, input_file):
    return "{module_name}.framework/Modules/{module_name}.swiftmodule/{swift_identifier}.{ext}={file_path}".format(
        module_name = module_name,
        swift_identifier = swift_identifier,
        ext = input_file.extension,
        file_path = input_file.path,
    )

def _prebuilt_swift_static_framework_impl(ctx):
    module_name = ctx.attr.framework_name
    fat_file = ctx.outputs.fat_file

    input_archives = []
    input_modules_docs = []
    zip_args = [_zip_binary_arg(module_name, fat_file)]

    for platform, archive in ctx.split_attr.archive.items():
        swiftmodule_identifier = _PLATFORM_TO_SWIFTMODULE[platform]
        library = archive[CcInfo].linking_context.libraries_to_link[0].pic_static_library
        swift_info = archive[SwiftInfo]
        swiftdoc = swift_info.direct_swiftdocs[0]
        swiftmodule = swift_info.direct_swiftmodules[0]

        input_archives.append(library)
        input_modules_docs += [swiftdoc, swiftmodule]
        zip_args += [
            _zip_swift_arg(module_name, swiftmodule_identifier, swiftdoc),
            _zip_swift_arg(module_name, swiftmodule_identifier, swiftmodule),
        ]

    ctx.actions.run(
        inputs = input_archives,
        outputs = [fat_file],
        mnemonic = "LipoSwiftLibraries",
        progress_message = "Combining libraries for {}".format(module_name),
        executable = "lipo",
        arguments = ["-create", "-output", fat_file.path] + [x.path for x in input_archives],
    )

    output_file = ctx.outputs.output_file
    ctx.actions.run(
        inputs = input_modules_docs + [fat_file],
        outputs = [output_file],
        mnemonic = "CreateSwiftFrameworkZip",
        progress_message = "Creating framework zip for {}".format(module_name),
        executable = ctx.executable._zipper,
        arguments = ["c", output_file.path] + zip_args,
    )

    return [
        DefaultInfo(
            files = depset([output_file]),
        ),
    ]

_prebuilt_swift_static_framework = rule(
    implementation = _prebuilt_swift_static_framework_impl,
    attrs = dict(
        archive = attr.label(
            mandatory = True,
            providers = [CcInfo, SwiftInfo],
            cfg = apple_common.multi_arch_split,
        ),
        framework_name = attr.string(mandatory = True),
        minimum_os_version = attr.string(default = "10.0"),
        platform_type = attr.string(
            default = str(apple_common.platform_type.ios),
        ),
        _zipper: attr.label(
            default = "@bazel_tools//tools/zip:zipper",
            cfg = "host",
            executable = True,
        ),
    ),
    outputs = {
        "fat_file": "%{framework_name}.fat",
        "output_file": "%{framework_name}.zip",
    },
)

def prebuilt_swift_static_framework(name, srcs = [], deps = []):
    srcs = srcs or native.glob(["Sources/**/*.swift"])
    swift_library(
        name = name,
        module_name = name,
        srcs = srcs,
        deps = deps,
    )

    _prebuilt_swift_static_framework(
        name = name + "Framework",
        framework_name = name,
        deps = [":" + name],
    )
