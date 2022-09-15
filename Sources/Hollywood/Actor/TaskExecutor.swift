import Foundation

/// An instance of this class executes a `WorkflowAction<T>` using a privately created `Task`.
@MainActor
final class TaskExecutor<T: Sendable> {

    private var task: Task<Void, Error>?

    init(command: some WorkflowAction<T>, completion: @MainActor @Sendable @escaping (Result<T, Error>) -> Void) {
        self.task = Task {
            do {
                // Note: Execution is currently on the main queue.
                // The main queue suspends here, while the command executes in the cooperative thread pool.
                let result = try await command.execute()

                // Execution is now back on the main queue. So it's safe to synchronously execute
                // the main actor completion block.
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

extension TaskExecutor {

    func cancel() {
        task?.cancel()
        task = nil
    }
}
