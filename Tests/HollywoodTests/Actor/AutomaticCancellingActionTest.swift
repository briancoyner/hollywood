import Foundation
import Testing

import Hollywood

struct AutomaticCancellingActionTest {

    @Test
    func automaticCancellingActionCancelsTheActionWhenTimingOut() async throws {
        struct InternalAction: WorkflowAction {
            func execute() async throws -> String {
                try await Task.sleep(for: .seconds(1))
                return "Brian"
            }
        }

        let action = InternalAction()
        let cancellingAction = AutomaticCancellingAction(timeout: .milliseconds(500), action: action)

        await #expect(performing: {
            try await cancellingAction.execute()
        }, throws: { error in
            return error is CancellationError
        })
    }

    @Test
    func automaticCancellingActionReturnsTheValueProducedByTheAction() async throws {
        struct InternalAction: WorkflowAction {
            func execute() async throws -> String {
                try await Task.sleep(for: .milliseconds(500))
                return "Brian"
            }
        }

        let action = InternalAction()
        let cancellingAction = AutomaticCancellingAction(timeout: .seconds(1), action: action)

        #expect(try await cancellingAction.execute() == "Brian")
    }

    @Test
    func automaticCancellingActionCancelsActionThatChecksTheTaskIsCancelledFlag() async throws {
        struct InternalAction: WorkflowAction {
            func execute() async throws -> Int {

                var result = 0
                while Task.isCancelled == false {
                    result += 1
                }

                return result
            }
        }

        let action = InternalAction()
        let cancellingAction = AutomaticCancellingAction(timeout: .seconds(1), action: action)

        await #expect(performing: {
            try await cancellingAction.execute()
        }, throws: { error in
            return error is CancellationError
        })
    }

    @Test
    func automaticCancellingActionCancelsActionThatCallsTaskCheckCancellationFunction() async throws {
        struct InternalAction: WorkflowAction {
            func execute() async throws -> Int {
                var result = 0
                while true {
                    result += 1
                    try Task.checkCancellation()
                }

                return result
            }
        }

        let action = InternalAction()
        let cancellingAction = AutomaticCancellingAction(timeout: .seconds(1), action: action)

        await #expect(performing: {
            try await cancellingAction.execute()
        }, throws: { error in
            return error is CancellationError
        })
    }
}
