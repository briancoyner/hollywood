import Foundation

/// An instance of this class executes a `WorkflowAction<T>` using a privately created `Task`.
@MainActor
final class WorkflowActionExecutor<T: Sendable> {

    private let workflowAction: any WorkflowAction<T>
    private let completion: (Result<T, any Error>) -> Void
    private var task: Task<Void, any Error>?

    init(command: any WorkflowAction<T>, completion: @MainActor @Sendable @escaping (Result<T, any Error>) -> Void) {
        self.workflowAction = command
        self.completion = completion
    }

    deinit {
        task?.cancel()
    }
}

extension WorkflowActionExecutor {

    func start() {
        precondition(task == nil, "Programmer Error! Calling `start` multiple times is not supported.")

        task = Task { [workflowAction, completion] in
            do {
                // Note: Execution is currently on the main queue.
                // The main queue suspends here, while the command executes in the cooperative thread pool.
                let result = try await workflowAction.execute()

                // Execution is now back on the main queue. So it's safe to synchronously execute
                // the main actor completion block.
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

extension WorkflowActionExecutor {

    func cancel() {
        task?.cancel()
    }
}
