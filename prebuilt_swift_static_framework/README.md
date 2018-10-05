# prebuilt_swift_static_framework

This is a macro & rule to build multi-architecture (fat) static
frameworks from Swift sources.

This example could be updated based on your use case.

## Usage

You need to include
[rules_swift](https://github.com/bazelbuild/rules_swift) in your
WORKSPACE, then in a BUILD file:

```python
prebuilt_swift_static_framework(
    name = "Whatever",
    srcs = glob(["path/to/sources/*.swift"]),
    deps = [":SomeDependency"],
)
```

If you omit `srcs`, this macro defaults to `Sources/**/*.swift`. This
macro doesn't currently support resources, but could be updated to do
so. Internally this rule creates a `swift_library` and compiles it for
all the architectures passed with `--ios_multi_cpus`. If you want to
re-use this same `swift_library` you could make the
`_prebuilt_swift_static_framework` public, and use it directly.
