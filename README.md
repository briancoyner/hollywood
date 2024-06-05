# Hollywood

![Header](Hollywood-Header.png)

<p align="leading">
    <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" />
    <img src="https://img.shields.io/badge/macOS-14.0+-brightgreen.svg" />
    <img src="https://img.shields.io/badge/Swift-5.10-ff69b4.svg" />
</p>

The **Hollywood** library provides developers a simple API for tracking the state of an asynchronous [Swift Structured Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) workflow, with optional progress reporting.

There are two core APIs: `ContextualActor` and `WorkflowAction`.

A `ContextualActor` asynchronously executes and publishes the result of a `WorkflowAction` that produces a type `T`. A `ContextualActor` transitions between `ContextualActor/State`s, i.e. ready, busy, success, failure. The current state is available by reading/ observing the `state` property. This makes it super easy to tie in with SwiftUI.

A `WorkflowAction` is a simple command (think GoF command) implementation that asynchronously executes to produce a value `T`. A good way to think about this protocol is that it forces you to give a discoverable name (via a concrete type) to a top-level asynchronous function. For a large code base, with multiple developers contributing code, this enables discoverability, improves future maintenance, and just generally helps organize top-level reusable functions.

![GeneralDiagram](GeneralDiagram.png)

`WorkflowAction`s are composable. This means it's super easy to stitch together WorkflowAction`s into a complex asynchronous execution graph. To further help with  discoverability, maintenance, and progress reporting, you can lean on the `CompositeWorkflowAction` and `UnitOfWork`.

### Examples

Workflows that require tracking state changes:
- Fetching anything from a web service (JSON, images, etc.)
- Uploading anything to a web service.
- Performing SQLite database reads and writes.
- Long running computations. 

Workflows that benefit from progress reporting:
- Downloading large files over a network.
- Decompressing/ compressing large files.
- Importing a large amount of data into a local persistent store (SQLite, Core Data, etc.)
- Long running computations.

## Hollywood Demos

The [Hollywood-Demos](https://github.com/briancoyner/hollywood-demos) repo contains several working examples (including the example above). Additional examples will be added in the future. 

- [x] GitHub OAuth sign-in workflow.
- [x] iTunes Music search (with album artwork download example).
- [x] Numerous progress reporting examples.

## Unit Tests

There are numerous unit tests showing how to use Hollywood, as well as showing techniques for unit testing asynchronous
workflows.

## Requirements
- Swift 5.10+
- iOS 17+
- macOS 14+

## Adding Hollywood as a Dependency

To use the `Hollywood` library in a SwiftPM project simply add the following to your `Package.swift` file:

```
.package(url: "https://github.com/briancoyner/hollywood.git", branch: "main"),
```

```
.target(name: "<target>", dependencies: [
     .product(name: "Hollywood", package: "hollywood")
]),
```

Finally, add `import Hollywood` as needed to your source files.

## What's Next?

- [ ] More demos are in the works, so you should watch and/ star the [Hollywood-Demos](https://github.com/briancoyner/hollywood-demos) repo.
- [ ] Introduce HollywoodTestKit to make it easier for you to write asynchronous unit tests.
- [ ] Additional DocC documentation (there's a decent start, but it's far from great).


## Credits

Hollywood is written and maintained by [Brian Coyner](https://briancoyner.github.io).


## License

Hollywood and HollywoodUI is released under the MIT License.
See [LICENSE](https://github.com/briancoyner/hollywood/blob/master/LICENSE) for details.
