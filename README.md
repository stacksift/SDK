# Stacksift SDK

Capture and submit crashes to [Stacksift](https://www.stacksift.io).

This library ties together [Wells](https://github.com/stacksift/Wells) and [Impact](https://github.com/stacksift/Impact) to provide a full crash capturing and submission system. It is **not** required, but can be handy if you just want to drop something in and get going. It supports macOS 13.0+, iOS 12.0+, and tvOS 12.0+.

## Integration

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/stacksift/SDK.git")
]
```

## Getting Started

All you need to do is `import Stacksift`, and call then call `start` early in your app's lifecycle.

```swift
import Stacksift

...

    Stacksift.start(APIKey: "my key")
```

## Exceptions from AppKit apps

Unfortunately, AppKit intefers with the flow of runtime exceptions. If you want to capture information about uncaught exceptions, some extra work is required.

The top-level `NSApplication` instance for your app must be a subclass of `ImpactMonitoredApplication`.

```swift
import Impact

class Application: ImpactMonitoredApplication {
}
```

and, you must update your Info.plist to ensure that the `NSPrincipalClass` key references this class with `<App Module Name>.Application`.

I realize this is a huge pain. If you feel so motivated, please file feedback with Apple to ask them to make AppKit behave like UIKit in this respect.

I would also strongly recommend setting the `NSApplicationCrashOnExceptions` defaults key to true. The default setting will allow your application to continue executing post-exception, virtually guaranteeing state corruption and incorrect behavior.

## Suggestions or Feedback

We'd love to hear from you! Get in touch via [twitter](https://twitter.com/stacksift), an issue, or a pull request.

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.
