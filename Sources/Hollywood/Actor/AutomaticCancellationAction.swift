import Foundation

/// A proxy ``WorkflowAction`` that requests its underlying action to cancel after a defined period of time.
///
/// An underlying action is expected to honor standard Swift Concurrency cooperative cancellation guidelines.
public struct AutomaticCancellingAction<A: WorkflowAction>: WorkflowAction {

    private let timeout: Duration
    private let action: A

    public init(timeout: Duration, action: A) {
        self.timeout = timeout
        self.action = action
    }
}

extension AutomaticCancellingAction {

    public func execute() async throws -> A.T {
        return try await withAutomaticCancellation(after: timeout, operation: action.execute)
    }
}

extension AutomaticCancellingAction {

    private func withAutomaticCancellation<T: Sendable>(
        after duration: Duration,
        operation: @escaping @Sendable () async throws(any Error) -> T
    ) async throws -> T {

        return try await withThrowingTaskGroup(of: T.self) { group in

            // Immediately schedule the underlying action to begin execution. It's possible the task completes
            // before the "track cancellation" task begins execution. In that case, the `group.next()`
            // returns the action's result (success; no timeout).
            group.addTask { try await operation() }
            group.addTask { try await cancelIfExecutionTimeExceeds(duration) }

            // Immediately await the group's result.
            //
            // There are two options:
            // 1) Success: The group received a result from the underlying action's task.
            // 2) Timeout: The group received a `CancellationError` from the "track cancellation" task.
            //
            // This block should never execute. If for some reason it does, then a `CancellationError` is thrown.
            guard let result = try await group.next() else { throw CancellationError() }

            // It's possible the action completed well before the timeout. Therefore it's important to cancel
            // the task tracking cancellation so that task doesn't execute longer than needed.
            group.cancelAll()

            return result
        }
    }

    private func cancelIfExecutionTimeExceeds(_ duration: Duration) async throws -> Never {
        // There are two options here:
        // 1) Timeout: The `sleep` function exits.
        // 2) No timeout: The `sleep` function is interrupted via the `group.cancelAll` below because the
        // action succeeded.
        try await Task.sleep(for: duration)

        // The execution gets to this point, then the `sleep` function exited, and the
        // underlying action needs to be cancelled (taking too long).
        //
        // Throwing a `CancellationError` cancels the task group, which cancels the action.
        throw CancellationError()
    }
}
