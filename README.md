# Stacksift SDK

Capture and submit crashes to [Stacksift](https://www.stacksift.io).

This library ties together [Wells](https://github.com/stacksift/Wells) and [Impact](https://github.com/stacksift/Impact) to provide a full crash capturing and submission system. It is **not** required, but can be handy if you just want to drop something in and get going. It supports macOS 13.0+, iOS 12.0+, and tvOS 12.0+.

## Integration

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/stacaksift/SDK.git")
]
```

## Getting Started

All you need to do is `import Stacksift`, and call then call `start` early in your app's lifecycle.

```swift
import Stacksift

...

    Stacksift.start(APIKey: "my key")
```

## Suggestions or Feedback

We'd love to hear from you! Get in touch via [twitter](https://twitter.com/stacksift), an issue, or a pull request.

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.
