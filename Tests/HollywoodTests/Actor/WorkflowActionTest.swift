import Foundation
import XCTest

@testable import Hollywood

final class WorkflowActionTest: XCTestCase {

}

extension WorkflowActionTest {

    @MainActor
    func testDeinitAutomaticallyCancelsItsUnderlyingTask() async throws {
        let executingExpectation = XCTestExpectation()
        let waitForCancellationExpectation = XCTestExpectation()
        let action = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation)
        )

        let waitForResult = XCTestExpectation()

        var capturedResult: Result<String, any Error>? = nil
        var executor: WorkflowActionExecutor? = WorkflowActionExecutor(action: action) { result in
            // The executor's callback always executes even if the executor is destroyed.
            capturedResult = result

            // Let's inform the test that the `Result` is captured and ready for final assertion.
            waitForResult.fulfill()
        }

        // Everything is set up. Let's start the async execution of the action and wait for the
        // result to be captured. The expected result should be a `CancellationError` initiated
        // when the `executor` reference is set to `nil`, which causes the executor's `deinit`
        // method to execute, which then cancels the underlying `Task`.
        try XCTUnwrap(executor).start()

        // Now let's wait for the executor to signal it's executing. The mock executor then
        // wait for the `waitForCancellationExpectation` to be signaled before continuing execution.
        await fulfillment(of: [executingExpectation], timeout: 3)

        // The executor is now executing again and waiting for the `waitForCancellationExpectation`
        // to be signaled. Setting the `executor` to `nil` sets the reference count to zero, which
        // immediately destroys the object (i.e. runtime calls the `deinit` method).
        executor = nil

        // At this point the executor should have cancelled its underlying `Task`. So let's signal
        // the underlying `Task` to continue its and complete its execution. The mock executor
        // checks for `Task` cancellation and throws a `CancellationError`.
        waitForCancellationExpectation.fulfill()
        await fulfillment(of: [waitForResult], timeout: 3)

        // We should now have a `Result` that is a `CancellationError`.
        let actualResult = try XCTUnwrap(capturedResult)
        switch actualResult {
        case .success(let unexpectedValue):
            XCTFail("The executor should have been cancelled, but returned a `\(unexpectedValue)` result.")
        case .failure(let error) where error is CancellationError:
            // This expected.
            break
        case .failure(let unexpectedError):
            XCTFail("The executor should have been cancelled, but instead threw a `\(unexpectedError)` error.")
        }
    }
}
