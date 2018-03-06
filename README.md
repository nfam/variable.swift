
# Variable.swift

[![swift][swift-badge]][swift-url]
![platform][platform-badge]
[![build][travis-badge]][travis-url]
[![codecov][codecov-badge]][codecov-url]
![license][license-badge]

> Represents a value that changes over time.

# Install
```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(url: "https://github.com/nfam/variable.swift.git", majorVersion: 0, minor: 1)
    ]
)
```

# Usage
```swift
let variable = Variable<String>(value: "Initial value")

// `variable` does have `subscribe` method,
// however wrapping it with `Subscribable` will stop subscribers from setting the variable value.
let subscribable = Variable<String>.Subscribable(variable)

variable.next(value: "Not printed!")
variable.next(value: "Not printed!")
variable.next(value: "Printed!")

subscribable.subscribe { value in
    print(value)
}

subject.onNext("Printed!")
```

[swift-url]: https://swift.org
[swift-badge]: https://img.shields.io/badge/Swift-3.1%20%7C%204.0-orange.svg?style=flat
[platform-badge]: https://img.shields.io/badge/Platforms-Linux%20%7C%20macOS%20%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgray.svg?style=flat

[travis-badge]: https://travis-ci.org/nfam/variable.swift.svg
[travis-url]: https://travis-ci.org/nfam/variable.swift

[codecov-badge]: https://codecov.io/gh/nfam/variable.swift/branch/master/graphs/badge.svg
[codecov-url]: https://codecov.io/gh/nfam/variable.swift/branch/master

[license-badge]: https://img.shields.io/github/license/nfam/variable.swift.svg