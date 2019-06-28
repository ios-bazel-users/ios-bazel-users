# swift_static_framework

This is a macro & rule to build multi-architecture (fat) static
frameworks from Swift sources.

This example could be updated based on your use case.

## Usage

You will need to include
[rules_swift](https://github.com/bazelbuild/rules_swift) in your
WORKSPACE. In your BUILD file, define the target:

```python
swift_static_framework(
    name = "Whatever",
    srcs = glob(["path/to/sources/*.swift"]),
    deps = [":SomeDependency"],
)
```

If you omit `srcs`, this macro defaults to `Sources/**/*.swift`. This
macro doesn't currently support resources, but could be updated to do
so. Internally this rule creates a `swift_library` and compiles it for
all the architectures passed with `--ios_multi_cpus`.

Build the `swift_library` and Swift static framework:

```shell
$ bazel build WhateverFramework --ios_multi_cpus=i386,x86_64,armv7,arm64
```

Build the `swift_library` only:

```shell
$ bazel build Whatever
```

You can depend on the `swift_library` from other libraries using the
`swift_static_framework`'s name, for example:

```python
swift_library(
    name = "MyLibrary",
    ...
    deps = [":Whatever"],
)
```

## Implementation

This works by using bazel's `apple_common.multi_arch_split`
configuration. This is used in place of `target` or `host` in
the `cfg` field. When you use this you must provide both a
`platform_type` which is a type of `apple_common.platform_type` and
`minimum_os_version`.

By using this attribute you now have `ctx.split_attr` populated in your
rule's implementation. This field is a dictionary of architectures to
the type of field where you set `cfg` to `multi_arch_split`. In the case
of this rule we use this for `deps`, this way we have our single
dependency grouped by architecture, and we can extract values that are
architecture specific from it, such as the swiftmodule files.
