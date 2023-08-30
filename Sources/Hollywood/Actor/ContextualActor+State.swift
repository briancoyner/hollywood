import Foundation

extension ContextualActor {

    public enum State {

        /// This is the default initial state. In this state the ``ContextualActor`` is awaiting the execution of a ``WorkflowAction``.
        ///
        /// A ``ContextualActor`` may transition from the ``ready`` to one of the following states:
        ///
        /// - ``busy(_:)`` when the workflow begins asynchronous execution.
        case ready

        /// This state indicates a ``ContextualActor`` is currently busy awaiting the result of the executing `WorkflowAction`
        /// or cancellation. If the workflow successfully cancels, the ``ContextualActor`` transitions to the ``ready`` state.
        ///
        /// A ``ContextualActor`` may transition from the ``busy(_:)`` to one of the following states:
        ///
        /// - ``ready`` when the workflow successfully cancels.
        /// - ``success(_:)`` when the workflow succeeds with a value `T`.
        /// - ``failure(_:_:)`` when the workflow throws an `Error`.
        case busy(T?)

        /// A `ContextualActor` received a value from a `WorkflowAction` (or was set during initialization).
        ///
        /// A ``ContextualActor`` may transition from the ``success(_:)`` to one of the following states:
        ///
        /// - ``busy(_:)`` when the workflow begins asynchronous execution.
        case success(T)

        /// A `ContextualActor` received an error from a `WorkflowAction`.
        ///
        /// A ``ContextualActor`` may transition from the ``failure(_:_:)`` to one of the following states:
        ///
        /// - ``busy(_:)``when the workflow begins asynchronous execution.
        case failure(any Error, T?)
    }
}

extension ContextualActor.State: CustomDebugStringConvertible {

    public var debugDescription: String {
        switch self {
        case .ready:
            return "Ready"
        case .busy(let value):
            return "Busy: \(String(describing: value))"
        case .success(let result):
            return "Success: \(result)"
        case .failure(let error, let value):
            return "Error: \(error); Value: \(String(describing: value))"
        }
    }
}
