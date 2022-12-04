import XCTest

import Hollywood

struct MockWorkflowAction<T: Sendable>: WorkflowAction, CustomDebugStringConvertible {

    enum State: Sendable {
        case mockResult(T)
        case mockError(Error)
        case mockCancellation(executingExpectation: Semaphore, waitForCancellationExpectation: Semaphore)
    }

    var description: String {
        return debugDescription
    }

    var debugDescription: String {
        switch state {
        case .mockResult(let value):
            return "MockResult: \(value)"
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
        case .mockResult(let result):
            return result
        case .mockError(let error):
            throw error
        case .mockCancellation(let executingExpectation, let waitForCancellationExpectation):
            executingExpectation.signal()

            try await waitForCancellationExpectation.wait()
            try Task.checkCancellation()

            throw TimeOutError()
        }
    }
}
