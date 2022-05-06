import AsyncAlgorithms

/// The tests need a way to coordinate between different actors/ threads. We can't use an expectation (it's not sendable) nor
/// can we use a GCD `DispatchSemaphore` (it's dangerous). Therefore, this solution leans on the AsyncAlgorithms `AsyncChannel`
/// to signal suspended tasks. It seems work well (at least for unit tests).
struct Semaphore: Sendable {

    private let channel = AsyncChannel(element: Void.self)
}

extension Semaphore {

    /// Tests call this method to "signal" a single "waiter" to continue.
    func signal() {
        channel.finish()
    }
}

extension Semaphore {

    /// Suspends execution until another task/ thread "signals" it's time to continue.
    /// - Parameter duration: The minimum length of time to wait for a signal to continue.
    ///
    /// - Throws: A `CancellationError` if a timeout occurs.
    func wait(forAtLeast duration: Int = 1) async throws {
        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in channel {
                    // no-op
                }
            }

            group.addTask {
                try await TimeoutAction(duration: duration) {
                    channel.finish()
                }.execute()
            }

            try await group.next()
            group.cancelAll()
        }
    }
}
