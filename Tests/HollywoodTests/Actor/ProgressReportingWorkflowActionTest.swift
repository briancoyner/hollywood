import Foundation
import Testing

@testable import Hollywood

struct ProgressReportingWorkflowActionTest {
}

extension ProgressReportingWorkflowActionTest {

    @Test
    func progressReportingAPIMisuseErrorIsThrownIfTheTaskLocalProgressIsNotProperlySetUpOnTheTaskLocal() async throws {

        struct MockProgressReportingWorkflowAction: ProgressReportingWorkflowAction {
            typealias T = String

            let pendingUnitCount: Int64

            func execute(withProgress progress: Progress) async throws -> String {
                return "Brian"
            }
        }

        let action = MockProgressReportingWorkflowAction(pendingUnitCount: 100)
        do {
            _ = try await action.execute()
            Issue.record("Expected a `\(ProgressReportingAPIMisuseError.self) to be thrown because a parent progress was not set up.")
        } catch is ProgressReportingAPIMisuseError {
            // Expected
        }
    }
}

extension ProgressReportingWorkflowActionTest {

    @Test
    func actionCorrectlySetsTheCompletedUnitCountToMatch_WhenTheActionDoesNotExpliclitySetATotalUnitCount() async throws {

        struct MockProgressReportingWorkflowAction: ProgressReportingWorkflowAction {
            typealias T = String

            let pendingUnitCount: Int64

            func execute(withProgress progress: Progress) async throws -> String {
                // This action doesn't explicitly set a `totalProgressCount` value. In this case, the
                // progress object believes it's in an "indeterminate" state. The `ProgressReportingWorkflowAction`
                // automatically handles this situation to ensure progress is 100% completed.
                return "Brian"
            }
        }

        let rootProgress = Progress(totalUnitCount: 100)
        let result = try await TaskProgress.$progress.withValue(rootProgress) {

            let action = MockProgressReportingWorkflowAction(pendingUnitCount: 100)
            return try await action.execute()
        }

        #expect(result == "Brian")
        #expect(rootProgress.totalUnitCount == 100)
        #expect(rootProgress.completedUnitCount == 100)
    }
}

extension ProgressReportingWorkflowActionTest {

    @Test
    func actionCorrectlySetsTheCompletedUnitCountToMatchTheTotalUnitCount_ParentProgressCorrectlyReflectsCompletion() async throws {

        struct MockProgressReportingWorkflowAction: ProgressReportingWorkflowAction {
            typealias T = String

            let pendingUnitCount: Int64

            func execute(withProgress progress: Progress) async throws -> String {
                progress.totalUnitCount = 6
                progress.completedUnitCount = 6

                return "Brian"
            }
        }

        let rootProgress = Progress(totalUnitCount: 100)
        let result = try await TaskProgress.$progress.withValue(rootProgress) {

            let action = MockProgressReportingWorkflowAction(pendingUnitCount: 100)
            return try await action.execute()
        }

        #expect(result == "Brian")
        #expect(rootProgress.totalUnitCount == 100)
        #expect(rootProgress.completedUnitCount == 100)
    }
}

extension ProgressReportingWorkflowActionTest {

    @Test
    func actionFailsToSetTheCompletedUnitCount_ParentProgressCorrectlyReflectsCompletion() async throws {

        struct MockProgressReportingWorkflowAction: ProgressReportingWorkflowAction {
            typealias T = String

            let pendingUnitCount: Int64

            func execute(withProgress progress: Progress) async throws -> String {
                progress.totalUnitCount = 6

                // Note: This action fails to update the progress object's `completedUnitCount`. When this happens the
                // `ProgressReportingWorkflowAction` ensures the `completedUnitCount` is equal to the
                // `totalUnitCount` (i.e. this action's progress is 100% complete). This in turn updates the parent
                // progress.

                return "Brian"
            }
        }

        let rootProgress = Progress(totalUnitCount: 100)
        let result = try await TaskProgress.$progress.withValue(rootProgress) {

            let action = MockProgressReportingWorkflowAction(pendingUnitCount: 100)
            return try await action.execute()
        }

        #expect(result == "Brian")
        #expect(rootProgress.totalUnitCount == 100)
        #expect(rootProgress.completedUnitCount == 100)
    }
}

extension ProgressReportingWorkflowActionTest {

    @Test
    func actionIncorrectlySetsTheCompletedCountToBeGreaterThanTheTotalUnitCount_ParentProgressCorrectlyReflectsCompletion() async throws {

        struct MockProgressReportingWorkflowAction: ProgressReportingWorkflowAction {
            typealias T = String

            let pendingUnitCount: Int64

            func execute(withProgress progress: Progress) async throws -> String {
                progress.totalUnitCount = 6
                progress.completedUnitCount = 7

                // Note: This action fails "over completes" this object's `completedUnitCount`. When this happens the
                // `ProgressReportingWorkflowAction` leaves the progress as-is because the parent progress has
                // already been updated to reflect completion of this child progress.

                return "Brian"
            }
        }

        let rootProgress = Progress(totalUnitCount: 100)
        let result = try await TaskProgress.$progress.withValue(rootProgress) {

            let action = MockProgressReportingWorkflowAction(pendingUnitCount: 100)
            return try await action.execute()
        }

        #expect(result == "Brian")
        #expect(rootProgress.totalUnitCount == 100)
        #expect(rootProgress.completedUnitCount == 100)
    }

    @Test
    func actionForceSetsTheParentProgressTotalUnitCountToTheActionsPendingUnitCount() async throws {

        struct MockProgressReportingWorkflowAction: ProgressReportingWorkflowAction {
            typealias T = String

            let pendingUnitCount: Int64

            func execute(withProgress progress: Progress) async throws -> String {
                // Note: This action fails "over completes" this object's `completedUnitCount`. When this happens the
                // `ProgressReportingWorkflowAction` leaves the progress as-is because the parent progress has
                // already been updated to reflect completion of this child progress.
                return "Brian"
            }
        }

        // This test ensures a `ProgressReportingWorkflowAction`'s progress is captured by a parent progress when
        // the parent progress doesn't have a valid `totalUnitCount` value. In this case, the parent's `totalUnitCount`
        // is force set by the `ProgressReportingWorkflowAction` to the action's `pendingUnitCount`. This means the
        // parent progress will be 100% complete after this action completes.
        let rootProgress = Progress()
        let result = try await TaskProgress.$progress.withValue(rootProgress) {
            let action = MockProgressReportingWorkflowAction(pendingUnitCount: 100)
            return try await action.execute()
        }

        #expect(result == "Brian")
        #expect(rootProgress.totalUnitCount == 100)
        #expect(rootProgress.completedUnitCount == 100)
    }
}
