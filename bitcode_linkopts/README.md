# bitcode_linkopts

This is a small rule to workaround bazel not fully supporting bitcode.
This workaround will no longer be necessary once
https://github.com/bazelbuild/bazel/pull/7356 is merged.

To use this rule, create an instance of it per `ios_application` rule
(or similar rule that requires bitcode), pass the `target_name` as the
name of the final `.ipa`, and add it as a dependency of your
`ios_application`.

This works by propagating the necessary bitcode flags to the final
linker invocation per architecture you're building for.

This concept is generally useful if you need to inject your own linker
flags for some targets, especially if the flags vary by architecture
(otherwise you could just use `--linkopt`).

## Issues

- This causes a warning since bazel unconditionally passes
  `-headerpad_max_install_names`, so you cannot use `-fatal_warnings`
- This doesn't solve passing the correct compiler flags to support
  bitcode. If you're using Swift this is [solved by
  rules_swift](https://github.com/bazelbuild/rules_swift/blob/f27ba20590e8a2b1d14e1506fbec48996de5ac62/swift/internal/xcode_swift_toolchain.bzl#L124-L131)
  but if you're using a different language you'll need to pass
  `--copt=-fembed-bitcode` wherever you pass `--apple_bitcode=embedded`
