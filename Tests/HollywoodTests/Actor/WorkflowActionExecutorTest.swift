import Foundation
import XCTest  // XCTWaiter + XCTestExpectation
import Testing

@testable import Hollywood

struct WorkflowActionTest {
}

extension WorkflowActionTest {

    @Test @MainActor
    func successfulTask_CompletesWithExpectedResult_ProgressIsForcedToCompletionWhenActionFailsToFullyUpdateTheCompletedUnitCount() async {
        let progressContext = MockWorkflowAction<String>.ProgressContext(totalUnitCount: 100, completedUnitCount: 85)
        await doTestSuccessfulTask_CompletesWithExpectedResult_ProgressTracked(with: progressContext)
    }

    @Test @MainActor
    func successfulTask_CompletesWithExpectedResult_ProgressIsCompleted() async {
        let progressContext = MockWorkflowAction<String>.ProgressContext(totalUnitCount: 100, completedUnitCount: 100)
        await doTestSuccessfulTask_CompletesWithExpectedResult_ProgressTracked(with: progressContext)
    }

    @Test @MainActor
    func successfulTask_CompletesWithExpectedResult_OverCompletedProgressIsClampedToTotalUnitCount() async {
        let progressContext = MockWorkflowAction<String>.ProgressContext(totalUnitCount: 100, completedUnitCount: 151)
        await doTestSuccessfulTask_CompletesWithExpectedResult_ProgressTracked(with: progressContext)
    }

    @MainActor
    private func doTestSuccessfulTask_CompletesWithExpectedResult_ProgressTracked(with progressContext: MockWorkflowAction<String>.ProgressContext) async {
        let expectation = XCTestExpectation(description: "Did execute successfully.")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        let action = MockWorkflowAction(state: .mockResult("Brian", progressContext))
        let executor = WorkflowActionExecutor(action: action) { result in
            switch result {
            case .success(let string):
                #expect(string == "Brian")
                expectation.fulfill()
            case .failure(let error):
                Issue.record(error, "Expected success not failure with \(error).")
            }
        }

        let rootProgress = Progress(totalUnitCount: progressContext.totalUnitCount)
        executor.start(with: rootProgress)
        let result = await XCTWaiter().fulfillment(of: [expectation], timeout: 3)
        #expect(result == .completed)

        // The progress `completedUnitCount` should always match the progress `totalUnitCount`.
        // The `WorkflowActionExecutor` forces this condition when the underlying task succeeds.
        #expect(progressContext.totalUnitCount == rootProgress.completedUnitCount)
        #expect(rootProgress.isIndeterminate == false)
        #expect(Int(rootProgress.fractionCompleted) == 1)
    }
}

extension WorkflowActionTest {

    @Test @MainActor
    func successfulTask_CompletesWhenAProgressReportingActionIsSubmittedToTheExecutor() async {

        struct MockProgressReportingAction: ProgressReportingWorkflowAction {
            typealias T = String

            let pendingUnitCount: Int64

            func execute(withProgress progress: Progress) async throws -> String {
                progress.totalUnitCount = 100
                progress.completedUnitCount = 100

                return "Brian"
            }
        }

        let expectation = XCTestExpectation(description: "Did execute successfully.")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1

        let action = MockProgressReportingAction(pendingUnitCount: 100)
        let executor = WorkflowActionExecutor(action: action) { result in
            switch result {
            case .success(let string):
                #expect(string == "Brian")
                expectation.fulfill()
            case .failure(let error):
                Issue.record(error, "Expected success not failure with \(error).")
            }
        }

        let rootProgress = Progress()
        executor.start(with: rootProgress)
        let result = await XCTWaiter().fulfillment(of: [expectation], timeout: 3)
        #expect(result == .completed)

        // The progress `completedUnitCount` should always match the progress `totalUnitCount`.
        // The `WorkflowActionExecutor` forces this condition when the underlying task succeeds.
        #expect(rootProgress.completedUnitCount == 100)
        #expect(rootProgress.isIndeterminate == false)
        #expect(Int(rootProgress.fractionCompleted) == 1)
    }
}

extension WorkflowActionTest {

    @Test @MainActor
    func deinitAutomaticallyCancelsItsUnderlyingTask() async throws {
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
        let progress = Progress()
        try #require(executor).start(with: progress)

        // Now let's wait for the executor to signal it's executing. The mock executor then
        // wait for the `waitForCancellationExpectation` to be signaled before continuing execution.
        let executingResult = await XCTWaiter().fulfillment(of: [executingExpectation], timeout: 3)
        #expect(executingResult == .completed)

        // The executor is now executing again and waiting for the `waitForCancellationExpectation`
        // to be signaled. Setting the `executor` to `nil` sets the reference count to zero, which
        // immediately destroys the object (i.e. runtime calls the `deinit` method).
        executor = nil

        // At this point the executor should have cancelled its underlying `Task`. So let's signal
        // the underlying `Task` to continue its and complete its execution. The mock executor
        // checks for `Task` cancellation and throws a `CancellationError`.
        waitForCancellationExpectation.fulfill()
        let result = await XCTWaiter().fulfillment(of: [waitForResult], timeout: 3)
        #expect(result == .completed)

        // We should now have a `Result` that is a `CancellationError`.
        let actualResult = try #require(capturedResult)
        switch actualResult {
        case .success(let unexpectedValue):
            Issue.record("The executor should have been cancelled, but returned a `\(unexpectedValue)` result.")
        case .failure(let error) where error is CancellationError:
            // This expected.
            break
        case .failure(let unexpectedError):
            Issue.record(unexpectedError, "The executor should have been cancelled, but instead threw a `\(unexpectedError)` error.")
        }
    }
}
