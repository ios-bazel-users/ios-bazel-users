# Jump to test failure

This is a quick example of how you can swizzle XCTest to make the issue
navigator correctly jump to test failures even when bazel builds your
source with relative paths.

To use this workaround you must define a module with the swizzling
source, in this example named `UnitTestMain`.

For each `ios_unit_test` bundle you must add this target as a
dependency, and set the `infoplists` to contain a custom plist with
something like:

```
{
  "NSPrincipalClass" => "UnitTestMain.UnitTestMain"
}
```

This makes every test bundle first load the `UnitTestMain` class inside
the `UnitTestMain` module. Which you can define as:

```swift
import ObjectiveC

final class UnitTestMain: NSObject {
    override init() {
        super.init()

        swizzleXCTSourceCodeLocationIfNeeded()
    }
}
```

This calls the core piece of logic:

```swift
import Foundation
import XCTest

// NOTE: This path has to start with a / for fileURLWithPath to resolve it correctly as an absolute path
public let kSourceRoot = ProcessInfo.processInfo.environment["SRCROOT"]!

private func remapFileURL(_ fileURL: URL) -> URL {
    if fileURL.path.hasPrefix(kSourceRoot) {
        return fileURL
    }

    return URL(fileURLWithPath: "\(kSourceRoot)/\(fileURL.relativePath)")
}

private extension XCTSourceCodeLocation {
    @objc
    convenience init(initWithRelativeFileURL relativeURL: URL, lineNumber: Int) {
        // NOTE: This call is not recursive because of swizzling
        self.init(initWithRelativeFileURL: remapFileURL(relativeURL), lineNumber: lineNumber)
    }
}

func swizzleXCTSourceCodeLocationIfNeeded() {
    if kSourceRoot == "$(SRCROOT)" {
        fatalError("Got unsubstituted SRCROOT")
    }

    let originalSelector = #selector(XCTSourceCodeLocation.init(fileURL:lineNumber:))
    let swizzledSelector = #selector(XCTSourceCodeLocation.init(initWithRelativeFileURL:lineNumber:))

    guard let originalMethod = class_getInstanceMethod(XCTSourceCodeLocation.self, originalSelector),
        let swizzledMethod = class_getInstanceMethod(XCTSourceCodeLocation.self, swizzledSelector) else
    {
        fatalError("Failed to swizzle XCTSourceCodeLocation ping #client-tooling")
    }

    method_exchangeImplementations(originalMethod, swizzledMethod)
}
```

Which replaces the underlying `XCTSourceCodeLocation`'s filepath, with
one resolved against the `SRCROOT` environment variable.

The last piece of this is to appropriately set the `SRCROOT`
environment variable in Xcode via the target's scheme. When running the
tests from the command line, the value of this environment variable
doesn't really matter since it won't be used to jump to any file (this
could potentially change if you wanted to produce valid `.xcresult`
bundles from the command line that could be viewed in Xcode).
