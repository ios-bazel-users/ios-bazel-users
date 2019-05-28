"""Bazel rule for creating a multi-architecture iOS static framework for a Swift module."""

load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo", "swift_library")

_DEFAULT_MINIMUM_OS_VERSION = "10.0"

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

def _zip_generated_objc_hdr_arg(module_name, generated_objc_hdr_file):
    # Rename the generated ObjC header to `{module_name}-Swift.h`.
    return "{module_name}.framework/Headers/{module_name}-Swift.h={file_path}".format(
        module_name = module_name,
        file_path = generated_objc_hdr_file.path,
    )

def _prebuilt_swift_static_framework_impl(ctx):
    module_name = ctx.attr.module_name
    fat_file = ctx.outputs.fat_file

    input_libraries = []
    input_swift_info = []
    generated_objc_hdr_file = None

    # The Swift static framework has only one `swift_library` dependency target.
    platform_to_target_list = ctx.split_attr.archive.items()
    swift_library_target = platform_to_target_list[0][1]

    # Get the generated Objective-C header file for the `swift_library`.
    objc_provider = swift_library_target[apple_common.Objc]
    for objc_hdr_file in objc_provider.header.to_list():
        if swift_library_target.label.name in objc_hdr_file.basename:
            generated_objc_hdr_file = objc_hdr_file
            break

    zip_args = [
        _zip_binary_arg(module_name, fat_file),
        _zip_generated_objc_hdr_arg(module_name, generated_objc_hdr_file)
    ]

    # Get the `swiftdoc` and `swiftmodule` files for each iOS platform.
    for platform, target in platform_to_target_list:
        swiftmodule_identifier = _PLATFORM_TO_SWIFTMODULE[platform]
        if not swiftmodule_identifier:
            continue

        library = target[CcInfo].linking_context.libraries_to_link[0].pic_static_library
        input_libraries.append(library)

        swift_info_provider = target[SwiftInfo]
        swiftdoc = swift_info_provider.direct_swiftdocs[0]
        swiftmodule = swift_info_provider.direct_swiftmodules[0]
        input_swift_info += [swiftdoc, swiftmodule]
        zip_args += [
            _zip_swift_arg(module_name, swiftmodule_identifier, swiftdoc),
            _zip_swift_arg(module_name, swiftmodule_identifier, swiftmodule),
        ]

    ctx.actions.run(
        inputs = input_libraries,
        outputs = [fat_file],
        mnemonic = "LipoSwiftLibraries",
        progress_message = "Combining libraries for {}".format(module_name),
        executable = "lipo",
        arguments = ["-create", "-output", fat_file.path] + [x.path for x in input_libraries],
    )

    output_file = ctx.outputs.output_file
    ctx.actions.run(
        inputs = input_swift_info + [generated_objc_hdr_file, fat_file],
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
        module_name = attr.string(mandatory = True),
        minimum_os_version = attr.string(default = _DEFAULT_MINIMUM_OS_VERSION),
        platform_type = attr.string(
            default = str(apple_common.platform_type.ios),
        ),
        _zipper = attr.label(
            default = "@bazel_tools//tools/zip:zipper",
            cfg = "host",
            executable = True,
        ),
    ),
    outputs = {
        "fat_file": "%{name}.fat",
        "output_file": "%{name}.zip",
    },
)

def prebuilt_swift_static_framework(name, srcs = [], deps = [], **kwargs):
    """Builds and bundles an iOS Swift static framework for third-party distribution.

    This rule supports building the following:
        $ bazel build SwiftLibrary (builds a `swift_library` that other targets can depend on)
        $ bazel build SwiftLibraryFramework (builds an iOS Swift static framework)

    To build for multiple architectures, specify the list of architectures to
    build the framework with: `--ios_multi_cpus=i386,x86_64,armv7,arm64`. If no
    architectures are specified, the default is `x86_64`.

    Args:
      name: Name of the `swift_library` that the framework depends on.
      srcs: The Swift source files to compile. If no srcs are provided, it's
          assumed that the Swift srcs are located in `Sources` directory.
      deps: Dependencies of the `swift_library` target being compiled.
      **kwargs: Additional arguments to pass to this rule, such as `testonly`,
          `module_name`, `minimum_os_version`, `visibility`, etc.
    """
    module_name = kwargs.get("module_name", name)
    srcs = srcs or native.glob(["Sources/**/*.swift"])
    testonly = kwargs.get("testonly", False)
    visibility = kwargs.get("visibility")
    swift_library(
        name = name,
        testonly = testonly,
        module_name = module_name,
        srcs = srcs,
        deps = deps,
        visibility = visibility,
    )

    _prebuilt_swift_static_framework(
        name = name + "Framework",
        testonly = testonly,
        module_name = module_name,
        archive = name,
        minimum_os_version = kwargs.get("minimum_os_version"),
        visibility = visibility,
    )
