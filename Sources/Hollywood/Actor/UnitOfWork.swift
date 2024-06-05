import Foundation

/// An action that enables a non-`ProgressReportingWorkflowAction` to participate in progress reporting alongside other
/// `ProgressReportingWorkflowAction`s. From a call site perspective, this enables a `WorkflowAction` to provide a `pendingUnitCount` to
/// a parent `Progress` object.
///
/// Here's an example to motivate this API:
///
/// ```
/// struct YourAsyncWorkflowAction: CompositeWorkflowAction {
///
///     func execute() async throws -> String {
///
///         // As noted in `ProgressReportingWorkflowAction`, a "total unit count" of 100 for a "root" action
///         // makes it super easy for humans reason about the amount of progress each progress-reporting
///         // contributes to the overall workflow.
///         TaskProgress.progress.totalUnitCount = 100
///
///         // This `ProgressReportingWorkflowAction` produces 25% of the workflow's progress.
///         let resultA = try await execute(SomeProgressReportingAction(pendingUnitCount: 25))
///
///         // This `ProgressReportingWorkflowAction` produces 15% of the workflow's progress.
///         let resultB = try await execute(SomeOtherProgressReportingAction(pendingUnitCount: 15))
///
///         // This non-`ProgressReportingWorkflowAction` action produces 40% of the workflow's progress.
///         //
///         // The big difference here is that the `SomeCompositeWorkflowAction` doesn't explicitly 
///         // adopt the `ProgressReportingWorkflowAction` protocol. But, the action can still participate
///         // in progress reporting using the `CompositeWorkflowAction.execute(_:pendingUnitCount:)` method,
///         // which behind the scenes uses a `UnitOfWork` action.
///         let resultC = try await execute(SomeCompositeWorkflowAction(), pendingUnitCount: 40)
///
///         // The explicit use of a `UnitOfWork` workflow action is equivalent to the line above--minus the
///         // arbitrary different in the `pendingUnitCount`, which produces the final 20% of the workflow's progress.
///         let resultD = try await execute(UnitOfWork(underlyingAction: action, pendingUnitCount: 20))
///
///         return resultA + resultB + resultC + resultD
///    }
///}
/// ```
public struct UnitOfWork<T>: ProgressReportingWorkflowAction where T: Sendable {

    /// The number of "units of work" this action contributes to the parent action's overall progress.
    public let pendingUnitCount: Int64

    private let underlyingAction: any WorkflowAction<T>

    /// - Parameters:
    ///   - underlyingAction: A non-`ProgressReportingWorkflowAction`.  It's undefined how this function behaves if a
    ///   `ProgressReportingWorkflowAction` is passed to this function.
    ///   - pendingUnitCount: The number of "units of work" this action contributes to the parent's overall progress
    public init(underlyingAction: any WorkflowAction<T>, pendingUnitCount: Int64) {
        self.underlyingAction = underlyingAction
        self.pendingUnitCount = pendingUnitCount
    }
}

extension UnitOfWork {

    public func execute(withProgress _: Progress) async throws -> T {
        // Note: The `Progress` parameter is ignored because the `ProgressReportingWorkflowAction`
        // takes care of correctly updating the `totalUnitCount` and `completedUnitCount` values
        // on behalf of this action.
        return try await underlyingAction.execute()
    }
}
