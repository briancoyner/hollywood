import Foundation
import OSLog

/// An instance of a ``ProgressReportingWorkflowAction`` is a ``CompositeWorkflowAction`` that executes with an isolated `Progress`
/// object. The isolated `Progress` object is added to the current Task's ``TaskProgress/progress`` instance with this action's ``pendingUnitCount``
/// value. The action's ``execute(withProgress:)`` implementation is responsible for updating the given `Progress` object's `Progress/totalUnitCount`
/// to reflect the total amount of work to be done, and to update the `Progress/completedUnitCount` value as work completes.
///
/// - Important: Developers conforming to this protocol must implement the ``execute(withProgress:)``. Do **not** implement ``execute()``.
public protocol ProgressReportingWorkflowAction<T>: CompositeWorkflowAction {

    /// The number of "units of work" this action contributes to the parent action's overall work. If, for example, the parent `Progress/totalUnitCount`
    /// is `100` and this action returns `15`, then this action contributes 15% of the parent action's overall progress.
    ///
    /// It's often convenient to set the parent's `Progress/totalUnitCount` to `100`. This makes it super easy to set the child action's
    /// `Progress/pendingUnitCount`, such that all child action's `Progress/pendingUnitCount` values add up to 100 (i.e. 100%).
    var pendingUnitCount: Int64 { get }

    func execute(withProgress progress: Progress) async throws -> T
}

extension ProgressReportingWorkflowAction {

    public func execute() async throws -> T {
        let taskProgress = Progress()
        defer { finalizeTaskProgressIfNeeded(taskProgress) }

        let parentProgress = TaskProgress.progress
        prepareParentProgressIfNeeded(parentProgress)

        parentProgress.addChild(taskProgress, withPendingUnitCount: pendingUnitCount)

        return try await TaskProgress.$progress.withValue(taskProgress) {
            return try await execute(withProgress: taskProgress)
        }
    }
}

// MARK: - Prepare Parent Progress

extension ProgressReportingWorkflowAction {

    private func prepareParentProgressIfNeeded(_ parentProgress: Progress) {
        if parentProgress.isIndeterminate {
            logger.info("""
                The `\(type(of: self))`'s parent progress is currently indeterminate. Therefore the parent's `totalUnitCount` \
                will be forced to the `pendingUnitCount` value `\(pendingUnitCount)` provided by this action. This may \
                happen when a `\(type(of: (any ProgressReportingWorkflowAction).self))` implementation is passed directly \
                to a `ContextualResource` for execution.
                """
            )

            parentProgress.totalUnitCount = pendingUnitCount
        }
    }
}

// MARK: - Finalize Task Progress

extension ProgressReportingWorkflowAction {

    private func finalizeTaskProgressIfNeeded(_ taskProgress: Progress) {
        // The action is forgiving if the developer neglects to set a `totalUnitCount` in the `execute(withProgress:)`
        // function. When this happens the task's progress is in an indeterminate state and will never update the
        // parent progress to reflect this action's `pendingUnitCount`. Therefore, if the `totalUnitCount` was not
        // set, then set it to 1, followed immediately by setting the `completedUnitCount` to 1. This ensures the
        // task progress is marked as 100% complete, which then notifies the parent progress to reflect total
        // progress (which is derived from the `pendingUnitCount`).
        if taskProgress.totalUnitCount == 0 {
            logger.warning("""
                The `\(type(of: self))`'s `totalUnitCount` is still zero. This means the action neglected \
                to implement proper progress reporting. Therefore the `totalUnitCount` is forced to `1`.
                """
            )

            taskProgress.totalUnitCount = 1
        }

        // The action is also forgiving if the developer neglects to set the `completedUnitCount` equal to the
        // `totalUnitCount`. When this happens the task's `completedUnitCount` is set to the task's `totalUnitCount`.
        // This ensures the task progress is marked as 100% complete.
        if taskProgress.completedUnitCount < taskProgress.totalUnitCount {
            logger.warning("""
                The `\(type(of: self))`'s `completedUnitCount` value is `\(taskProgress.completedUnitCount)`, \
                which is less than the task's `totalUnitCount` value of `\(taskProgress.totalUnitCount)`. \
                Therefore the `completedUnitCount` will be forced to `\(taskProgress.totalUnitCount)`.
                """
            )

            taskProgress.completedUnitCount = taskProgress.totalUnitCount
        }
    }
}

// MARK: - OSLog

private let logger = Logger(subject: (any ProgressReportingWorkflowAction).self)
