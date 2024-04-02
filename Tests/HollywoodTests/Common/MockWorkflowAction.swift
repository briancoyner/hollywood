import XCTest

import Hollywood

struct MockWorkflowAction<T: Sendable>: WorkflowAction, CustomDebugStringConvertible {

    struct ProgressContext {
        let totalUnitCount: Int64
        let completedUnitCount: Int64
    }

    enum State: Sendable {
        case mockResult(T, ProgressContext? = nil)
        case mockError(any Error)
        case mockCancellation(executingExpectation: XCTestExpectation, waitForCancellationExpectation: XCTestExpectation)
    }

    var description: String {
        return debugDescription
    }

    var debugDescription: String {
        switch state {
        case .mockResult(let value, let progressContext):
            return "MockResult: \(value); Progress Context: \(String(describing: progressContext))"
        case .mockError(let error):
            return "MockError: \(error)"
        case .mockCancellation:
            return "MockCancellation"
        }
    }

    let state: State
}

extension MockWorkflowAction {

    func execute() async throws -> T {
        switch state {
        case .mockResult(let result, let progressContext):
            if let progressContext {
                // Any action executing in the context of a `ContextualActor` may ask for a Task-local
                // `Progress` object via the `TaskProgress/progress` property.
                let progress = try TaskProgress.safeProgress
                progress.totalUnitCount = progressContext.totalUnitCount
                progress.completedUnitCount = progressContext.completedUnitCount
            }

            return result
        case .mockError(let error):
            throw error
        case .mockCancellation(let executingExpectation, let waitForCancellationExpectation):
            executingExpectation.fulfill()

            await XCTWaiter().fulfillment(of: [waitForCancellationExpectation])
            try Task.checkCancellation()

            XCTFail("Expected the parent task to be cancelled and a `\(CancellationError.self) to be thrown.")
            throw TimeOutError()
        }
    }
}
