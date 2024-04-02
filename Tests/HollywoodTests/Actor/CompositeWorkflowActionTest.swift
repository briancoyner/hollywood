import Foundation
import XCTest

import Hollywood

final class CompositeWorkflowActionTest: XCTestCase {
}

extension CompositeWorkflowActionTest {

    func testCompositeActionDefaultExecuteImplementationExecutesTheAction() async throws {

        struct TestCompositeAction: CompositeWorkflowAction {
            func execute() async throws -> String {

                // The `CompositeWorkflowAction` protocol exposes two methods with default
                // implementations:
                //
                // The composite's `execute(_:)` method simply calls the given action's `execute` method.
                let firstName = try await execute(MockWorkflowAction(state: .mockResult("Brian")))

                // The composite's `execute(_:pendingUnitCount:)` first wraps the given action
                // in a `UnitOfWork` action with the given pending unit count. The `UnitOfWork`
                // action is then passed to the composite's `execute(_:)` method, which simply
                // calls the `UnitOfWork`'s `execute` method, which calls the action's `execute` method.
                let lastName = try await execute(MockWorkflowAction(state: .mockResult("Coyner")), pendingUnitCount: 100)

                return "\(firstName) \(lastName)"
            }
        }

        let compositeAction = TestCompositeAction()

        // Given this test manually executes an action, i.e. not using a `ContextualResource`
        // for execution, then the test must explicitly invoke the action within a `TaskProgress`
        // value block. Failure to do this results in a `ProgressReportingAPIMisuseError` being thrown.
        let parentProgress = Progress()
        let result = try await TaskProgress.$progress.withValue(parentProgress) {
            return try await compositeAction.execute()
        }

        XCTAssertEqual("Brian Coyner", result)
    }
}
