# Useful Flags

Bazel has hundreds of flags, but many are not relevant to iOS. This file shows some of the more useful ones to know and use for iOS. For the full list, see: https://docs.bazel.build/versions/master/command-line-reference.html

### General

###### `--subcommands` (`-s`)

Display the commands of each build action.

###### `--announce_rc`

Display the actual command flags after applying `.bazelrc` settings.

###### `--sandbox_debug`

Keep the sandbox directory (`/var/tmp/_bazel_$USER/*/sandbox/darwin-sandbox/*`) for debugging/inspection. See the `sandbox.sb` file for the `sandbox-exec` definition.

###### `--copt="-v"`, `--swiftcopt="-v"`

Print jobs run by the `clang` and `swiftc` drivers respectively. For example this will show compiler frontend invocations, linker invocations, etc.

###### `--experimental_generate_json_trace_profile`

Run `bazel build` with this flag to generate a Chrome compatible trace file that can be used to visually introspect the build's timing, sequencing, and parallelism. This flag requires the use of `--profile=<path>`, for example:

```sh
bazel build \
  --experimental_generate_json_trace_profile \
  --profile=path/to/trace.json \
  //some/build:target
```

See also chrome://tracing

### iOS

###### `--ios_multi_cpus`

Build fat binaries, for example: `--ios_multi_cpus=armv7,arm64`

###### `--apple_platform_type` [undocumented]

Build for a specific platform when none of the targets specify one. This is necessary when testing a  `swift_test` on macOS, because Bazel assumes iOS. See [bazelbuild/rules_swift#51](https://github.com/bazelbuild/rules_swift/issues/51) for complete details.

```
bazel test //foo:foo_tests --apple_platform_type=macos
```

###### `--xcode_version`

Select the version of Xcode to use. Bazel auto-discovers installed versions of Xcode. If you've recently installed a version of Xcode that Bazel can't find with `--xcode_version`, you might have to restart the daemon by running `bazel clean --expunge`.
