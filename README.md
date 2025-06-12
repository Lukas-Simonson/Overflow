<h3 align="center">🌊 Overflow</h3>
<p align="center">Swift 6 Reactive Data Flows</p>

<p align="center">
    <a href="https://developer.apple.com/swift/"><img alt="Swift 6.0" src="https://img.shields.io/badge/swift-6.0-orange.svg?style=flat"></a>
    <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-MIT-black.svg"></a>
</p>

## Overview

Overflow is a Swift 6-ready Reactive Data Flow library inspired by Kotlin Flows, designed to bring a composable, structured approach to asynchronous programming using Swift’s AsyncSequence. It provides a familiar and lightweight API for modeling data streams and reacting to changes over time, while embracing Swift’s modern concurrency model.

Features:
- ✅ Built for Swift 6 and native async/await
- 🔁 Supports both Cold and Hot flows
- 🧩 Composable operators: `map`, `filter`, `flatMap`, and more
- 🔄 Structured and cancelable data flows
- 🧭 Based on AsyncSequence for a native and intuitive experience
- 🧘 Minimal, dependency-free, and easy to integrate

## Quickstart Guide

### Flow Types

Overflow provides multiple flow types to suit different data stream needs, inspired by Kotlin's flow model but tailored for Swift and AsyncSequence.

- **`StateFlow` / `MutableStateFlow`:**
  A hot, state-holding flow that always emits the latest value to new subscribers. Useful for observing continuously changing state, such as UI or application state.

- **`SharedFlow` / `MutableSharedFlow`:**
  A hot, stateless broadcast flow that emits values to all active collectors. Ideal for sharing one-time events like navigation actions or notifications.

- **`ColdFlow`:**
  A cold, builder-based flow that creates a new asynchronous stream per collector. Execution begins when collection starts, making it perfect for one-off or deferred operations like fetching data.

Each flow type is built around Swift’s `AsyncSequence`, offering a familiar and ergonomic interface while supporting structured, reactive data flow.

### `StateFlow` & `MutableStateFlow`

`StateFlow` is a hot, state-holding flow that always contains the latest value. 

- `MutableSharedFlow` allows you to emit values to all current subscribers.
- `SharedFlow` provides a read-only interface for subscribers, preventing external emission.


#### Creating a `MutableStateFlow`

When you create a `MutableStateFlow` you must provide an initial value, as `StateFlows` always have a value.

```swift
import Overflow

let mutableState = MutableStateFlow(initial: 0)
```

#### Publishing / Emitting Values

You can update the current value of a `MutableStateFlow` and notify all subscribers using the `emit` functions.

```swift
// async context
await mutableState.emit(42)

// concurrent context
mutableState.emit(42)
```

#### Reading The Current Value

`StateFlows` always store the last emitted state, you can read this value by calling the `value` parameter in an asynchronous context`

```
let currentValue = await mutableState.value
```

#### Exposing a Read-Only `StateFlow`

You can expose a read-only interface for subscribers by converting your `MutableStateFlow` to a `StateFlow` using the `asStateFlow()` method.

```swift
let readOnlyFlow: StateFlow<Int> = mutableState.asStateFlow()
```

Use `MutableStateFlow` when you need access to update the value, and expose a `StateFlow` to subscribers to prevent unexpected emissions.

### `SharedFlow` & `MutableSharedFlow`

`SharedFlow` is a hot, stateless broadcast flow that multicasts values to all active subscribers as they are emitted. Unlike `StateFlow`, it does not hold a current value—subscribers only receive values emitted after they subscribe. This makes it ideal for one-time events, notifications, or actions that should be delivered to multiple listeners.

- `MutableSharedFlow` allows you to emit values to all current subscribers.
- `SharedFlow` provides a read-only interface for subscribers, preventing external emission.

#### Creating a `MutableSharedFlow`

```swift
import Overflow

let events = MutableSharedFlow<String>()
```

#### Emitting Values

Emit values to all active subscribers using the `emit` method.

```swift
// async context
await events.emit("Hello")

// concurrent context
events.emit("Overflow!")
```

#### Exposing a Read-Only `SharedFlow`

You can expose a read-only interface for subscribers by converting your `MutableSharedFlow` to a `SharedFlow` using the `asSharedFlow()` method.

```swift
let readOnlyEventFlow: SharedFlow<Int> = events.asSharedFlow()
```

### `ColdFlow`

`ColdFlow` is a cold, builder-based asynchronous flow. Each time a subscriber collects from a `ColdFlow`, the provided builder closure is executed anew, producing a fresh stream of values. This makes `ColdFlow` ideal for deferred or one-off operations, such as fetching data or performing computations on demand.

- Each subscription is independent and starts from the beginning.
- Values are emitted using an async `EmitAction` closure provided to the builder.

#### Creating a `ColdFlow`

```swift
import Overflow

let numbers = ColdFlow { emit in
    for i in 1...3 {
        await emit(i)
    }
}
```

### Observing Flow Values

All flow types in Overflow, `StateFlow`, `SharedFlow`, and `ColdFlow`, are built on top of Swift’s `AsyncSequence` protocol. This means you can observe and collect values from any flow using the same, familiar `for await` syntax, regardless of the flow’s type or behavior.

#### Collecting Values

```swift
Task {
    for await value in someFlow {
        print("Received value: \(value)")
    }
}
```

This unified approach helps make it easy to react to changes, events, or data emissions in a declarative and idiomatic Swift style.

#### Declarative Transformations

Because flows conform to `AsyncSequence`, you can use standard sequence operations like `map`, `filter`, and `compactMap` directly in your flows to transform or filter values as they are emitted:

```swift
let evenNumbers = numbersFlow
    .filter { $0 % 2 == 0 }
    .map { "\($0) is even" }
    
Task {
    for await message in evenNumbers {
        print(message)
    }
}
```

For even more power, you can use Apple’s [AsyncAlgorithms](https://github.com/apple/swift-async-algorithms) package to `combine`, `debounce`, `merge`, or otherwise compose flows in advanced ways. Since Overflow flows are `AsyncSequences`, they work seamlessly with these algorithms:

```swift
import AsyncAlgorithms

let merged = merge(flowA, flowB)

Task {
    for await value in merged {
        print("Merged value: \(value)")
    }
}
```
This makes Overflow flows highly composable and extensible, leveraging the full power of Swift's async ecosystem.

## Installation

### Swift Package Manager

Swift Package Manager is a tool for automating the distribution of Swift code and is integrated into the Swift compiler.

To add Overflow to your project do the following.

- Open Xcode
- Click on File -> Add Packages
- Use this repositories URL (https://github.com/Lukas-Simonson/Overflow.git) in the top right of the window to download the package.
- When prompted for a version or branch, choose the most up to date version, or the `main` branch.
