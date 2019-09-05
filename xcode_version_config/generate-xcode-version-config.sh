#!/bin/bash
#
# Generates a package that holds the `xcode_version_config` option based on the
# current selected Xcode, so that Bazel will never have to fetch this
# information.

set -eu

readonly current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly xcode_version_output=$(env -i xcodebuild -version)
readonly xcode_sdk_version_output=$(env -i xcodebuild -sdk -version)

xcode_version=$(echo "${xcode_version_output}" \
  | grep "Xcode" | sed -E "s/Xcode (([0-9]|.)+).*/\1/")
readonly xcode_build_version=$(echo "${xcode_version_output}" \
  | grep "Build version" | sed -E "s/Build version (([0-9]|.)+).*/\1/")
readonly ios_sdk=$(echo "${xcode_sdk_version_output}" \
  | grep iphoneos | sed -E "s/.*\(iphoneos(([0-9]|.)+)\).*/\1/")
readonly tvos_sdk=$(echo "${xcode_sdk_version_output}" \
  | grep appletvos | sed -E "s/.*\(appletvos(([0-9]|.)+)\).*/\1/")
readonly macosx_sdk=$(echo "${xcode_sdk_version_output}" \
  | grep macosx10. | sed -E "s/.*\(macosx(([0-9]|.)+)\).*/\1/" | head -n 1)
readonly watchos_sdk=$(echo "${xcode_sdk_version_output}" \
  | grep watchos | sed -E "s/.*\(watchos(([0-9]|.)+)\).*/\1/")

# xcodebuild -version doesn't always pad with trailing .0.
# Add a trailing .0 to be identical with what Bazel is doing.
# for example, "10.3" will be converted to "10.3.0".
if [[ ! $xcode_version =~ [0-9].[0-9].[0-9] ]]
then
  xcode_version="${xcode_version}.0"
fi

readonly xcode_version_full="${xcode_version}.${xcode_build_version}"
readonly xcode_version_label=$(echo "version${xcode_version_full}" | tr . _)

cat > "${current_dir}/BUILD" <<EOF
package(default_visibility = ['//visibility:public'])

xcode_version(
    name = '${xcode_version_label}',
    version = '${xcode_version_full}',
    default_ios_sdk_version = '${ios_sdk}',
    default_tvos_sdk_version = '${tvos_sdk}',
    default_macos_sdk_version = '${macosx_sdk}',
    default_watchos_sdk_version = '${watchos_sdk}',
)

xcode_config(
    name = 'host_xcodes',
    versions = [
        ':${xcode_version_label}',
    ],
    default = ':${xcode_version_label}',
)
EOF
