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

###### `--experimental_show_artifacts`

Print the file paths to outputs created during `bazel build`. This is useful for inspecting outputs or building scripts that process outputs after the build.

###### `--keep_going=true`

Continue the build even if an error occurs. This is helpful in scenarios where you might want all the errors at once to address rather than a rebuild after addressing individual errors.

###### `--verbose_failures`

Bazel can sometimes fail with little to no information about the error. This will print verbose errors in the event of a build failure.

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

###### `--xcode_version_config=<label>`

Pass the Xcode configuration so that bazel doesn't have to fetch it. By default bazel queries your system to determine what Xcode versions are available. This can lead to [issues](https://github.com/bazelbuild/bazel/issues/6056) where you have to run a `bazel clean --expunge` to recover. If you can guarantee that all users of your bazel configuration have the same version of Xcode, you can copy the output from `cat "$(bazel info execution_root)"/external/local_config_xcode/BUILD` and check it in to your repo. This way bazel won't have to fetch this information.

###### `--objc_enable_binary_stripping=true` and `--features=dead_strip`

Strips unreachable functions and data from the final binary. These flags tell bazel to pass the `-dead_strip` flag at link time. If you are statically linking your entire application this can greatly reduce your binary size.

* For `objc_binary`, use `--objc_enable_binary_stripping=true`
* For `swift_binary`, use `--features=dead_strip`

The `--objc_enable_binary_stripping` flag only takes effect if you are building your application with `--compilation_mode=opt` and is a link-time optimization.

##### `--features=swift.use_global_module_cache`

Make all swiftc invocations use the same module cache. Otherwise each invocation has to generate its own cache which can be very expensive for many invocations.

### Build Caching

Bazel supports multiple forms of caching action outputs. The default behavior is to store the outputs of actions locally and replace those outputs when the action changes.

Caches allow you to keep older outputs for actions which is helpful for scenarios like branch switching or CI builds that may be building very different changelists for consecutive jobs.

The two main options right now are local or remote caches. Local caches utlize a disk cache whereas a remote cache is accessible over http or gRPC.

#### General 

###### `--experimental_strict_action_env`

Forces developers to declare the environment variables / values at BUILD time. This is essential for getting cache hits since common variables like `$PATH` can differ amongst machines and will result in a cache miss.

###### `--experimental_multi_threaded_digest`

By default, Bazel has a serial queue for generating digests for build actions (hashes for the remote cache). This flag is recommended to enable if you're building on SSDs since it will allow hashes to be constructed quicker.

###### `--spawn_strategy=local`

Disable sandboxing for all actions. This can improve build performance significantly on macOS.

#### Local

###### `--disk_cache=/path/to/disk/cache`

Path to a directory where Bazel can read and write actions and action outputs. If the directory does not exist, it will be created.

#### Remote

> More information here: https://docs.bazel.build/versions/master/remote-caching.html

###### `--remote_http_cache=http://url/to/cache/server:port`

Specify the URL / port for the remote cache server over `http`.

###### `--remote_upload_local_results=true`

This controls whether or not local action outputs are uploaded to the remote cache. A common strategy is to allow CI machines / Build farms to populate caches and local developer machines will be read-only. The rationale is that the local developer workflow generates outputs that are likely not consumed by other builds until it is in the form of a PR or has been committed.

###### `--experimental_remote_retry=true`

Retry remote cache / execution actions if there is an errors when building against a remote cache or build farm.

###### `--remote_local_fallback=true`

Perform a build action locally if its not available on the remote cache.
