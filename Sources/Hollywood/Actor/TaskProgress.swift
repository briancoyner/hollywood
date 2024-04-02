import Foundation
import OSLog

/// Exposes a `TaskLocal` `Foundation/Progress` object to the current `Task`.
///
/// - SeeAlso: ``ProgressReportingWorkflowAction`` for how to implement a ``WorkflowAction`` that produces incremental progress updates.
/// - SeeAlso: ``UnitOfWork`` for how to configure a "workflow" with a non-``ProgressReportingWorkflowAction`` that produces incremental progress updates.
public enum TaskProgress {

    /// Returns the task's `Progress` if it's been set. The Hollywood `ContextualActor` API **always** ensures a root-level `Progress` is
    /// created and published to this `TaskLocal` variable. Therefore developers using the `ContextualActor` API to execute an async workflow
    /// may use the ``safeProgress`` property to return a non-nil `Progress` associated with the current `Task`.
    @TaskLocal
    public static var progress: Progress?
}

extension TaskProgress {

    /// - Throws `ProgressReportingAPIMisuseError` if the ``progress`` property is `nil`, which indicates that
    public static var safeProgress: Progress {
        get throws {
            guard let safeProgress = TaskProgress.progress else {
                logger.error("""
                   Programmer Error! The `\(type(of: self))` is trying to participate in progress reporting
                   but the workflow is not properly set up to manage progress reporting. This is most likely
                   caused by accessing the `TaskProgress/progress` property outside the context of a `ContextualResource`.
                   If this is desired, then the async function must be wrapped in a call to `TaskProgress.$progress.withValue(...) { ... }`.
                   """
                )
                throw ProgressReportingAPIMisuseError()
            }

            return safeProgress
        }
    }
}

// MARK: - OSLog

private let logger = Logger(subject: TaskProgress.self)
