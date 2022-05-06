import Foundation
import SwiftUI
import AsyncAlgorithms

/// A `ContextualActor` asynchronously executes and publishes the result of a ``WorkflowAction``.
/// A `ContextualActor` transitions between ``ContextualActor/State-swift.enum``s. The current
/// state is available by reading/ observing the  ``state-swift.property``.
@MainActor
public final class ContextualActor<T: Sendable>: ObservableObject, Sendable {

    @Published
    public private(set) var state: State = .ready

    private var internalState: InternalState = .ready {
        didSet {
            state = map(internalState)
        }
    }

    private var backlog: [AnyWorkflowAction<T>]

    public init(initialValue: T? = nil) {
        self.state = initialValue.map { .success($0) } ?? .ready
        self.internalState = initialValue.map { .success($0) } ?? .ready
        self.backlog = []
    }

    public init(initialError: Error, initialValue: T? = nil) {
        self.state = .failure(initialError, initialValue)
        self.backlog = []
    }
}

// MARK: Execute

extension ContextualActor {

    /// Submits a ``WorkflowAction`` for asynchronous execution.
    ///
    /// Passing `true` for the `cancelIfBusy` parameter performs the following logic:
    /// - If the current state is ``State-swift.enum/busy(_:)``, then
    ///   - Cancel the executing ``WorkflowAction`` , which calls `cancel` on the internally owned detached `Task`.
    ///   - Immediately transition to the ``State-swift.enum/ready`` state.
    ///   - Submit the given ``WorkflowAction`` for asynchronous execution, which transitions to the ``State-swift.enum/busy(_:)`` state.
    ///
    /// It's important to understand that even though the current workflow action is cancelled, it's possible the workflow action still produces
    /// a result. In this case, the result is dropped on the floor by the ``ContextualActor``.
    ///
    /// Passing `false` for the `cancelIfBusy` parameter performs the following logic:
    /// - The given ``WorkflowAction`` is enqueued for execution, and executes once the current action completes (success or failure).
    ///
    /// It's important to understand that upon execution of the enqueued action, `state` immediately transitions to `.busy(previousResult)` and
    /// passes along the previous action's result value.
    ///
    /// It's also important to understand that it's not currently possible to cancel an enqueued ``WorkflowAction`` without
    ///
    /// - Parameters:
    ///   - action: The ``WorkflowAction`` to asynchronously execute.
    ///   - cancelIfBusy: Pass `true` to cancel the current asynchronous ``WorkflowAction`` and immediately submit the
    ///   given ``WorkflowAction`` for execution.
    ///
    ///   - SeeAlso: ``State-swift.enum`` for more information on expected state transitions.
    public func execute(_ action: some WorkflowAction<T>, cancelIfBusy: Bool = false) {
        switch internalState {
        case .ready:
            doExecute(action, currentValue: nil)
        case .busy(_, _, let currentValue):
            if cancelIfBusy {
                cancel()
                doExecute(action, currentValue: currentValue)
            } else {
                backlog.append(AnyWorkflowAction(action))
            }
        case .success(let currentValue):
            doExecute(action, currentValue: currentValue)
        case .failure(_, let currentValue):
            doExecute(action, currentValue: currentValue)
        }
    }

    private func doExecute<C: WorkflowAction>(_ action: C, currentValue: T?) where C.T == T {
        let identifier = UUID()
        let executor = TaskExecutor(command: AnyWorkflowAction(action)) { [weak self] result in
            self?.handleResult(result, identifier: identifier)
        }

        internalState = .busy(executor, identifier, currentValue)
    }
}

// MARK: Cancel

extension ContextualActor {

    /// Request the current workflow action, if there is one executing, to stop executing as soon as possible.
    ///
    /// Workflow cancellation is cooperative:
    /// - A ``WorkflowAction`` (or its sub-actions) should support cancellation by checking if the workflow has been cancelled at opportune times.
    ///
    /// This method has no effect if:
    /// - The ``ContextualActor/State-swift.enum`` is not ``State-swift.enum/busy(_:)`` at the time of the cancellation request.
    /// - The ``WorkflowActon`` (or its sub-actions) do not support cancellation or have passed the point of no return. In this case
    /// a workflow eventually succeeds or fails (assuming the `WorkflowAction` is properly implemented to make forward progress).
    public func cancel() {
        if case .busy(let task, _, _) = internalState {
            task.cancel()

            internalState = .ready
        }
    }
}

// MARK: Reset

extension ContextualActor {

    /// Request the current workflow action, if there is one executing, to stop executing as soon as possible.
    /// Also, any enqueued ``WorkflowAction``s are removed and not executed.
    ///
    /// The `state`property  immediately transitions to ``State-swift.enum/ready``, if needed, and any result returned by the currently executing
    /// workflow action is ignored.
    public func reset() {
        // First, let's remove all enqueued actions.
        backlog.removeAll()

        // Next, let's cancel the current task, if `.busy`.
        // Cancelling may also transition to the `.ready` state.
        cancel()

        // Finally transition back to the `.ready` state, if needed.
        resetInternalStateIfNeeded()
    }

    private func resetInternalStateIfNeeded() {
        switch internalState {
        case .ready:
            break
        default:
            internalState = .ready
        }
    }
}

extension ContextualActor {

    private func handleResult(_ result: Result<T, Error>, identifier: UUID) {
        switch internalState {
        case .ready:
            executeFromBacklog()
        case .busy(_, let currentIdentifier, let value) where currentIdentifier == identifier:
            switch result {
            case .success(let value):
                internalState = .success(value)
            case .failure(let error):
                internalState = .failure(error, value)
            }

            executeFromBacklog()
        default:
            // No-op. The result is ignored because it's associated with a non-active action.
            // This happens when a workflow action is cancelled due to executing a newer action by
            // calling `execute(someAction, cancelIfBusy:true)`.
            break
        }
    }

    private func executeFromBacklog() {
        guard !backlog.isEmpty else {
            return
        }

        execute(backlog.removeFirst())
    }
}

extension ContextualActor {

    private enum InternalState {
        case ready
        case busy(TaskExecutor<AnyWorkflowAction<T>>, UUID, T?)
        case success(T)
        case failure(Error, T?)
    }

    private func map(_ internalState: InternalState) -> State {
        switch internalState {
        case .ready:
            return .ready
        case .busy(_, _, let value):
            return .busy(value)
        case .success(let value):
            return .success(value)
        case .failure(let error, let value):
            return .failure(error, value)
        }
    }
}
