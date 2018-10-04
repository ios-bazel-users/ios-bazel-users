### General

###### `--subcommands` (`-s`)

Display the commands of each build action.

###### `--announce_rc`

Display the actual command flags after applying `.bazelrc` settings.

###### `--sandbox_debug`

Keep the sandbox directory (`/var/tmp/_bazel_$USER/*/sandbox/darwin-sandbox/*`) for debugging/inspection. See the `sandbox.sb` file for the `sandbox-exec` definition.

###### `--copt="-v"`, `--swiftcopt="-v"`

Print jobs run by the `clang` and `swiftc` drivers respectively. For example this will show compiler frontend invocations, linker invocations, etc.

### iOS

###### `--ios_multi_cpus`

Build fat binaries, for example: `--ios_multi_cpus=armv7,arm64`

###### `--apple_platform_type`

TBD
