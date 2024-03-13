import Foundation

/// Exposes a `TaskLocal` `Foundation/Progress` object to the current `Task`.
///
/// - SeeAlso: ``ProgressReportingWorkflowAction`` for how to implement a ``WorkflowAction`` that produces incremental progress updates.
/// - SeeAlso: ``UnitOfWork`` for how to configure a "workflow" with a non-``ProgressReportingWorkflowAction`` that produces incremental progress updates.
public enum TaskProgress {

    @TaskLocal
    public static var progress = Progress()
}
