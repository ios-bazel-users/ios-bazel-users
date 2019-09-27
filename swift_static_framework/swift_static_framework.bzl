"""Bazel rule for creating a multi-architecture static framework for a Swift module."""

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo", "swift_library")

_ALL_PLATFORMS = [
    "arm",
    "arm64",
    "i386",
    "x86_64",
]

_DEFAULT_MINIMUM_OS_VERSION = "10.0"

_PLATFORM_TO_SWIFTMODULE = {
    "ios_armv7": "arm",
    "ios_arm64": "arm64",
    "ios_i386": "i386",
    "ios_x86_64": "x86_64",
}

def _swiftdoc_output(platform, outputs):
    if platform == "arm":
        return outputs.arm_swiftdoc
    elif platform == "arm64":
        return outputs.arm64_swiftdoc
    elif platform == "i386":
        return outputs.i386_swiftdoc
    return outputs.x86_64_swiftdoc

def _swiftmodule_output(platform, outputs):
    if platform == "arm":
        return outputs.arm_swiftmodule
    elif platform == "arm64":
        return outputs.arm64_swiftmodule
    elif platform == "i386":
        return outputs.i386_swiftmodule
    return outputs.x86_64_swiftmodule

def _modulemap_file_content(module_name):
    return """\
framework module {module_name} {{
  header "{module_name}-Swift.h"
  requires objc
}}
""".format(module_name = module_name)

def _swift_static_framework_impl(ctx):
    module_name = ctx.attr.module_name
    fat_file = ctx.outputs.fat_file
    modulemap_file = ctx.outputs.modulemap_file

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
        swiftdoc_input = swift_info_provider.direct_swiftdocs[0]
        swiftmodule_input = swift_info_provider.direct_swiftmodules[0]

        swiftdoc_output = _swiftdoc_output(swiftmodule_identifier, ctx.outputs)
        swiftmodule_output = _swiftmodule_output(swiftmodule_identifier, ctx.outputs)

        ctx.actions.run(
            inputs = [swiftdoc_input],
            outputs = [swiftdoc_output],
            mnemonic = "CopySwiftDoc",
            progress_message = "Copying swiftdoc for {}".format(module_name),
            executable = "cp",
            arguments = [swiftdoc_input.path, swiftdoc_output.path],
        )
        ctx.actions.run(
            inputs = [swiftmodule_input],
            outputs = [swiftmodule_output],
            mnemonic = "CopySwiftModule",
            progress_message = "Copying swiftmodule for {}".format(module_name),
            executable = "cp",
            arguments = [swiftmodule_input.path, swiftmodule_output.path],
        )

    # Create zero-byte swiftdoc and swiftmodule files for platform that we're
    # not building for, because we can't change the number of outputs
    building_platforms = [
        _PLATFORM_TO_SWIFTMODULE[x]
        for x, _ in platform_to_target_list
    ]
    not_building_platforms = [
        x for x in _ALL_PLATFORMS if x not in building_platforms
    ]

    for platform in not_building_platforms:
        swiftdoc_output = _swiftdoc_output(platform, ctx.outputs)
        swiftmodule_output = _swiftmodule_output(platform, ctx.outputs)

        ctx.actions.run(
            inputs = [],
            outputs = [swiftdoc_output],
            mnemonic = "CreateEmptySwiftDoc",
            progress_message = "Create non-building platform swiftdoc for {}".format(module_name),
            executable = "touch",
            arguments = [swiftdoc_output.path],
        )
        ctx.actions.run(
            inputs = [],
            outputs = [swiftmodule_output],
            mnemonic = "CreateEmptySwiftModule",
            progress_message = "Create non-building platform swiftmodule for {}".format(module_name),
            executable = "touch",
            arguments = [swiftmodule_output.path],
        )

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
            content = _modulemap_file_content(module_name),
        )

        ctx.actions.run(
            inputs = [generated_objc_hdr_file],
            outputs = [ctx.outputs.generated_header],
            mnemonic = "CopyGeneratedHeader",
            progress_message = "Copying generated header for {}".format(module_name),
            executable = "cp",
            arguments = [generated_objc_hdr_file.path, ctx.outputs.generated_header.path],
        )

    return [
        DefaultInfo(
            files = depset([
                ctx.outputs.fat_file,
                ctx.outputs.generated_header,
                ctx.outputs.modulemap_file,
                ctx.outputs.arm_swiftdoc,
                ctx.outputs.arm_swiftmodule,
                ctx.outputs.arm64_swiftdoc,
                ctx.outputs.arm64_swiftmodule,
                ctx.outputs.i386_swiftdoc,
                ctx.outputs.i386_swiftmodule,
                ctx.outputs.x86_64_swiftdoc,
                ctx.outputs.x86_64_swiftmodule,
            ]),
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
    ),
    fragments = ["apple"],
    outputs = {
        "fat_file": "%{module_name}.framework/%{module_name}",
        "generated_header": "%{module_name}.framework/Headers/%{module_name}-Swift.h",
        "modulemap_file": "%{module_name}.framework/Modules/module.modulemap",
        "arm_swiftdoc": "%{module_name}.framework/Modules/%{module_name}.swiftmodule/arm.swiftdoc",
        "arm_swiftmodule": "%{module_name}.framework/Modules/%{module_name}.swiftmodule/arm.swiftmodule",
        "arm64_swiftdoc": "%{module_name}.framework/Modules/%{module_name}.swiftmodule/arm64.swiftdoc",
        "arm64_swiftmodule": "%{module_name}.framework/Modules/%{module_name}.swiftmodule/arm64.swiftmodule",
        "i386_swiftdoc": "%{module_name}.framework/Modules/%{module_name}.swiftmodule/i386.swiftdoc",
        "i386_swiftmodule": "%{module_name}.framework/Modules/%{module_name}.swiftmodule/i386.swiftmodule",
        "x86_64_swiftdoc": "%{module_name}.framework/Modules/%{module_name}.swiftmodule/x86_64.swiftdoc",
        "x86_64_swiftmodule": "%{module_name}.framework/Modules/%{module_name}.swiftmodule/x86_64.swiftmodule",
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
