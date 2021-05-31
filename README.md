# Stacksift SDK

Capture and submit crashes to [Stacksift](https://www.stacksift.io).

This library ties together [Wells][wells] and [Impact][impact] to provide a full crash capturing and submission system. It is **not** required, but can be handy if you just want to drop something in and get going. It supports macOS 13.0+, iOS 12.0+, and tvOS 12.0+.

## Integration

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/stacksift/SDK.git")
]
```

Carthage:

```
github "stacksift/SDK"
```

## Getting Started

All you need to do is `import Stacksift`, and call then call `start` early in your app's lifecycle.

```swift
import Stacksift

...

Stacksift.start(APIKey: "my key")
```

## Background Uploads

By default, Stacksift using `URLSession` background uploads for both reliability and performance. However, sometimes these can take **hours** for the OS to actually execute. This can be a pain if you are just testing things out. To make that easier, you can disable background uploads with another parameter to the `start` method.

## MetricKit vs In-Process

Stacksift can capture your crash information in two different ways: in-process monitoring or via MetricKit diagnostics. In-process is the default, but you can use a parameter to `start` to make another choice.

In-process monitoring is the traditional approach taken by third-party crash reporting systems. In-process monitoring can capture many, but not all types of crashes. However, it requires a complex system that does not interoperate well. You should install only **one** in-process reporter.

MetricKit [crash diagnostics][mxcrashdiagnostic] is a new facility introduced with iOS 14. MetricKit is far less invasive, much simpler, and can include more context than an in-process system. And, it was built to be used by multiple consumers within the same app. Unfortunately, MetricKit also comes with some severe limitations, in addition to the platform/OS availability.

MetricKit results are only available ~ 24 hours after they have been captured, even while testing. It is also undocumented how many crashes MetricKit will buffer, should your app not be relaunched within that 24 hour window. MetricKit crashes are only available on devices that have opted into sharing diagnostic data with developers. It is widely believed the opt-in rate is below 25%. Finally, MetricKit reports omit a number of relevant details, such as a precise time and information about uncaught runtime exceptions.

When Stacksift is configured to use MetricKit only, it will not intefere with any other installed 3rd-party reporter.

## Exceptions from macOS Apps

Unfortunately, AppKit intefers with the flow of runtime exceptions. If you want to capture information about uncaught exceptions, some extra work is required.

⚠️ This technique does not work for SwiftUI lifecycle-based macOS applications. A solution is still being investigated. 

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

[impact]: https://github.com/stacksift/Impact
[wells]: https://github.com/stacksift/Wells
[metrickit]: https://developer.apple.com/documentation/metrickit
[mxcrashdiagnostic]: https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic
