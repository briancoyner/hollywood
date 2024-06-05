import Foundation

/// Asynchronous workflows often require collaborating with other ``WorkflowAction``s to complete a unit of related work. This protocol
/// helps developers to organize more complex workflows behind a "composite" definition.
///
/// Adopting this protocol does two things:
///
/// 1) It tells the reader that the ``WorkflowAction`` leans on other ``WorkflowAction``s to complete the action.
/// 2) Exposes a convenience method for executing ``WorkflowAction``s without having to explicitly invoke the action's ``execute(_:)`` method.
///
/// Here's an example showing how to use a composite action that executes other actions to sign-in a user:
///
/// ```
/// struct SignInUserWorkflowAction: CompositeWorkflowAction {
///     func execute() async throws -> User {
///
///         // This presents the web-based sign-in view used to obtain a short-lived authorization code.
///         // The caller suspends while the user interacts with the user interface.
///         let authorizationCode = try await execute(AuthorizeUserWorkflowAction())
///
///         // We now have the authorization code, so let's march towards obtaining the OAuth tokens.
///         let clientSecret = try await execute(ObtainClientSecretWorkflowAction())
///         let tokens = try await execute(ObtainTokensWorkflowAction(
///             authorizationCode: authorizationCode,
///             clientSecret: clientSecret
///         )
///         return try await execute(PersistTokensInKeychainWorkflowAction(tokens: tokens)
///     }
/// }
/// ```
///
/// Of course, there's nothing stopping you from implementing the action as a non-`CompositeWorkflowAction`. Basically, this API is an alternative to
/// tossing async static functions into case-less enums, structs, or even as free functions.
public protocol CompositeWorkflowAction: WorkflowAction {
}

extension CompositeWorkflowAction {

    public func execute<A: WorkflowAction>(_ action: A) async throws -> A.T {
        return try await action.execute()
    }
}

extension CompositeWorkflowAction {

    /// Developers call this function to execute a `WorkflowAction` that does not directly conform to the `ProgressReportingWorkflowAction`
    /// but still contributes progress by way of child task actions or by directly updating the ``TaskProgress/progress`` instance associated with the
    /// current task.
    ///
    /// A best-practice for a `CompositeWorkflowAction` participating in progress reporting is to set the current `Progress/totalUnitCount` to 100.
    /// This means, for example, that a `pendingUnitCount` value of `15` passed to this function contributes 15% towards the parent's total progress.
    ///
    /// - SeeAlso: `UnitOfWork` for an example of how this function is used.
    public func execute<A: WorkflowAction>(_ action: A, pendingUnitCount: Int64) async throws -> A.T {
        return try await execute(UnitOfWork(underlyingAction: action, pendingUnitCount: pendingUnitCount))
    }
}
