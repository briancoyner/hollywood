import Foundation

/// An instance of this class executes a `WorkflowAction<T>` using a privately created `Task`.
@MainActor
final class WorkflowActionExecutor<T: Sendable> {

    private let action: any WorkflowAction<T>
    private let completion: (Result<T, any Error>) -> Void
    private var task: Task<Void, any Error>?

    init(action: any WorkflowAction<T>, completion: @MainActor @Sendable @escaping (Result<T, any Error>) -> Void) {
        self.action = action
        self.completion = completion
    }

    deinit {
        // Automatically cancel the running task if being deinitialized.
        task?.cancel()
    }
}

extension WorkflowActionExecutor {

    func start(with progress: Progress) {
        precondition(task == nil, "Programmer Error! Calling `start` multiple times is not supported.")

        // IMPORTANT: - `task` must not capture `self` in order to avoid a retain cycle.
        task = Task { [completion, action] in
            do {
                try await TaskProgress.$progress.withValue(progress) {
                    // Note: Execution is currently on the main queue.
                    // The main queue suspends here, while the command executes in the cooperative thread pool.
                    let result = try await action.execute()

                    // The progress is effectively forced to 100% completion if the underlying `WorkflowAction`
                    // implementation fails to properly update the `completedUnitCount`. Doing so ensures the
                    // user always sees a progress view transition to 100% (even if the developer writing the
                    // `WorkflowAction` fails to correctly update the `completedUnitCount`.
                    if progress.completedUnitCount != progress.totalUnitCount {
                        progress.completedUnitCount = progress.totalUnitCount
                    }

                    // Execution is now back on the main queue. So it's safe to synchronously execute
                    // the main actor completion block.
                    completion(.success(result))
                }
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
