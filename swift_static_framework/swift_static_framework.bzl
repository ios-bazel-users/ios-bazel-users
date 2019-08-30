"""Bazel rule for creating a multi-architecture static framework for a Swift module."""

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
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

def _zip_modulemap_arg(module_name, modulemap_file):
    return "{module_name}.framework/Modules/module.modulemap={file_path}".format(
        module_name = module_name,
        file_path = modulemap_file.path,
    )

def _modulemap_file_content(module_name):
    return """\
framework module %s {
  header %s-Swift.h
  requires objc
}
""" % (module_name, module_name)

def _swift_static_framework_impl(ctx):
    module_name = ctx.attr.module_name
    fat_file = ctx.outputs.fat_file
    modulemap_file = ctx.outputs.modulemap_file
    zip_args = [_zip_binary_arg(module_name, fat_file)]

    libraries = []
    swift_info_files = []
    generated_objc_hdr_file = None

    # The Swift static framework has only one `swift_library` dependency target.
    platform_to_target_list = ctx.split_attr.archive.items()
    swift_library_target = platform_to_target_list[0][1]

    # Get the generated Objective-C header file for the `swift_library`.
    if apple_common.Objc in swift_library_target:
        objc_provider = swift_library_target[apple_common.Objc]
        generated_hdr_file_basename = swift_library_target.label.name + "-Swift.h"
        for objc_hdr_file in objc_provider.header.to_list():
            if objc_hdr_file.basename == generated_hdr_file_basename:
                generated_objc_hdr_file = objc_hdr_file
                zip_args.append(_zip_generated_objc_hdr_arg(module_name, generated_objc_hdr_file))
                break

    # Get the `swiftdoc` and `swiftmodule` files for each platform.
    for platform, target in platform_to_target_list:
        swiftmodule_identifier = _PLATFORM_TO_SWIFTMODULE[platform]
        if not swiftmodule_identifier:
            continue

        # Bazel 0.27 changed `libraries_to_link` from a list to a `depset`.
        libraries_to_link = target[CcInfo].linking_context.libraries_to_link
        if hasattr(libraries_to_link, "to_list"):
            libraries_to_link = libraries_to_link.to_list()
        library = libraries_to_link[0].pic_static_library
        libraries.append(library)

        swift_info_provider = target[SwiftInfo]
        swiftdoc = swift_info_provider.direct_swiftdocs[0]
        swiftmodule = swift_info_provider.direct_swiftmodules[0]
        swift_info_files += [swiftdoc, swiftmodule]
        zip_args += [
            _zip_swift_arg(module_name, swiftmodule_identifier, swiftdoc),
            _zip_swift_arg(module_name, swiftmodule_identifier, swiftmodule),
        ]

    apple_support.run(
        ctx,
        inputs = libraries,
        outputs = [fat_file],
        mnemonic = "LipoSwiftLibraries",
        progress_message = "Combining libraries for {}".format(module_name),
        executable = "/usr/bin/lipo",
        arguments = ["-create", "-output", fat_file.path] + [x.path for x in libraries],
    )

    input_files = [fat_file]
    if generated_objc_hdr_file:
        ctx.actions.write(
            output = modulemap_file,
            content = _modulemap_file_content(module_name)
        )
        zip_args.append(_zip_modulemap_arg(module_name, modulemap_file))

        input_files.append(generated_objc_hdr_file)
        input_files.append(modulemap_file)

    output_file = ctx.outputs.output_file

    ctx.actions.run(
        inputs = swift_info_files + input_files,
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

_swift_static_framework = rule(
    implementation = _swift_static_framework_impl,
    attrs = dict(
        apple_support.action_required_attrs(),
        archive = attr.label(
            mandatory = True,
            providers = [CcInfo, SwiftInfo],
            cfg = apple_common.multi_arch_split,
        ),
        module_name = attr.string(mandatory = True),
        minimum_os_version = attr.string(mandatory = True),
        platform_type = attr.string(
            default = str(apple_common.platform_type.ios),
        ),
        _zipper = attr.label(
            default = "@bazel_tools//tools/zip:zipper",
            cfg = "host",
            executable = True,
        ),
    ),
    fragments = ["apple"],
    outputs = {
        "fat_file": "%{name}.fat",
        "modulemap_file": "module.modulemap",
        "output_file": "%{name}.zip",
    },
)

def swift_static_framework(name, srcs = [], deps = [], **kwargs):
    """Builds and bundles a Swift static framework for third-party distribution.

    This rule supports building the following:
        $ bazel build SwiftLibrary (builds a `swift_library` that other targets can depend on)
        $ bazel build SwiftLibraryFramework (builds a Swift static framework)

    To build for multiple architectures, specify the list of architectures to
    build the framework with: `--ios_multi_cpus=i386,x86_64,armv7,arm64`. If no
    architectures are specified, the default is `x86_64`.

    Args:
      name: Name of the `swift_library` that the framework depends on.
      srcs: The Swift source files to compile. If not provided, it's assumed
          that source files are located in a `Sources` directory.
      deps: Dependencies of the `swift_library` target being compiled.
      **kwargs: Additional arguments supported by this rule:
          copts: Additional compiler options that should be passed to `swiftc`.
          module_name: The name of the Swift module being built. If not
              provided, the `name` is used.
          minimum_os_version: The minimum OS version supported by the framework.
          testonly: If `True`, only testonly targets (such as tests) can depend
              on the `swift_library` target. The default is `False`.
          visibility: The visibility specifications for this target.
    """
    module_name = kwargs.get("module_name", name)
    srcs = srcs or native.glob(["Sources/**/*.swift"])
    testonly = kwargs.get("testonly", False)
    minimum_os_version = kwargs.get("minimum_os_version", _DEFAULT_MINIMUM_OS_VERSION)
    visibility = kwargs.get("visibility")

    swift_library(
        name = name,
        testonly = testonly,
        srcs = srcs,
        copts = kwargs.get("copts"),
        module_name = module_name,
        visibility = visibility,
        deps = deps,
    )

    _swift_static_framework(
        name = name + "Framework",
        testonly = testonly,
        module_name = module_name,
        archive = name,
        minimum_os_version = minimum_os_version,
        visibility = visibility,
    )
