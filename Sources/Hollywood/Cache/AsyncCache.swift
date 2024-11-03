import Foundation

/// A general purpose cache that asynchronously loads and provides a value `T`.
///
/// The cache is effectively a Swift actor with non-reentrant behavior.
///
/// ## Value Behavior
///
/// The first call to ``value`` attempts to asynchronously load and cache the value using the
/// ``AsyncCacheCommand`` passed to the initializer. It's common for a ``value`` to take time to
/// load, e.g. network call, database query, etc. Therefore, any additional concurrent calls to
/// ``value`` await the initial result returned by the executing command.
///
/// If an error is thrown by the ``AsyncCacheCommand`` obtaining the initial value, then the cache
/// effectively remains in its initial "no value" state. The next call to ``value`` re-executes
/// the ``AsyncCacheCommand``.
///
/// Once the ``AsyncCacheCommand`` returns a value `T`, that value is cached and returned to all
/// callers.
///
/// ## Reset Behavior
///
/// A cache may be asked to ``reset()`` at anytime to attempt to update the cache's ``value``. The
///``AsyncCacheCommand`` re-executes to obtain the updated value.
///
/// If ``reset()`` executes while the cache is in the middle of executing the ``AsyncCacheCommand``,
/// then the caller awaits the value returned by the active ``AsyncCacheCommand``. To put it another
/// way: if the cache is currently "busy" obtaining a value from the ``AsyncCacheCommand``, then
/// the ``reset()`` does **not** initiate another call to the command. Instead the ``reset()`` simply
/// awaits the result of the active command execution. This matches the behavior of multiple calls
/// to ``value``.
///
/// ### Appoint a single monitor/ owner to reset
///
/// Typically there's a single monitor/ owner responsible for calling ``reset()``. You may 
/// experience unexpected behavior if you have multiple shared owners of the cache concurrently
/// invoking ``reset()``. See "Reset Behavior" notes).
///
/// ### Reset behavior that may cause developer confusion
///
/// A ``reset()`` always uses the same ``AsyncCacheCommand`` instance. If the cache's value is
/// derived from context that changes over time (due to some business related rules), then it's
/// possible for a reset-miss to occur if the cache is "busy" (see "Reset Behavior" notes).
public actor AsyncCache<T: Sendable> {

    private enum State {
        case empty
        case busy([UUID: CheckedContinuation<T, any Error>])
        case value(T)
    }

    private var command: any AsyncCacheCommand<T>
    private var state: State = .empty

    /// Creates a cache whose ``value`` is lazily loaded using the given ``AsyncCacheCommand``.
    /// 
    /// - Parameter command: the command used to lazily load and ``reset()`` the ``value``.
    public init(command: any AsyncCacheCommand<T>) {
        self.command = command
    }
}

// MARK: - Retrieve Value

extension AsyncCache {

    /// The first call to ``value`` attempts to asynchronously load the value using the
    /// ``AsyncCacheCommand`` passed to the initializer. If additional concurrent calls happen
    /// while the command executes, then the caller awaits the value.
    ///
    /// If an error is thrown while asynchronously loading the value, then the next call to ``value``
    /// attempts to asynchronously load the value again.
    public var value: T {
        get async throws {
            return try await execute(command, forceResetIfNeeded: false)
        }
    }
}

// MARK: - Reset Value

extension AsyncCache {

    /// Calling `reset` attempts to asynchronously reload the value using the ``AsyncCacheCommand``
    /// passed to the initializer.
    public func reset() async throws -> T {
        return try await execute(command, forceResetIfNeeded: true)
    }
}

// MARK: - State Management Entry Points

extension AsyncCache {

    private func execute(_ command: any AsyncCacheCommand<T>, forceResetIfNeeded: Bool) async throws -> T {
        switch state {
        case .empty:
            return try await doExecute(command, currentValue: nil)
        case .busy(_):
            do {
                return try await awaitResult()
            } catch {
                if forceResetIfNeeded {
                    return try await doExecute(command, currentValue: nil)
                } else {
                    throw error
                }
            }
        case .value(let value):
            if forceResetIfNeeded {
                return try await doExecute(command, currentValue: value)
            } else {
                return value
            }
        }
    }
}

// MARK: - State Management Execution

extension AsyncCache {

    private func doExecute(_ command: any AsyncCacheCommand<T>, currentValue: T?) async throws -> T {
        state = .busy([:])

        do {
            let value = try await command.execute()
            resumeContinuations(with: value)
            return value
        } catch let error as CancellationError {
            resumeContinuations(throwing: error, currentValue: currentValue)
            throw error
        } catch {
            resumeContinuations(throwing: error, currentValue: nil)
            throw error
        }
    }

    private func awaitResult() async throws -> T {
        let id = UUID()

        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                trackContinuation(continuation, withID: id)
            }
        } onCancel: {
            Task {
                await cancelContinuation(withID: id)
            }
        }
    }
}

// MARK: - Continuation Tracking + State Management

extension AsyncCache {

    private var activeContinuations: [UUID: CheckedContinuation<T, any Error>] {
        guard case .busy(let continuations) = state else {
            preconditionFailure("Invalid state: \(state))")
        }

        return continuations
    }

    private func resumeContinuations(with value: T) {
        for continuation in activeContinuations.values {
            continuation.resume(returning: value)
        }

        state = .value(value)
    }

    private func resumeContinuations(throwing error: any Error, currentValue: T?) {
        for continuation in activeContinuations.values {
            continuation.resume(throwing: error)
        }

        if let currentValue {
            state = .value(currentValue)
        } else {
            state = .empty
        }
    }

    private func trackContinuation(
        _ continuation: CheckedContinuation<T, any Error>,
        withID identifier: UUID
    ) {
        var continuations = activeContinuations
        continuations[identifier] = continuation

        state = .busy(continuations)
    }

    private func cancelContinuation(withID identifier: UUID) {
        guard case .busy(var continuations) = state else {
            // Important: It's possible that a cancellation request needs to be ignored because
            // the value is already returned to the caller. This may happen due to how the
            // the `withTaskCancellationHandler:onCancel:` callback happens asynchronously.
            return
        }

        continuations[identifier]?.resume(throwing: CancellationError())
        continuations[identifier] = nil

        state = .busy(continuations)
    }
}
