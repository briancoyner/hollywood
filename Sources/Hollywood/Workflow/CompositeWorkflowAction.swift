import Foundation

/// Asynchronous workflows often require collaborating with multiple ``WorkflowAction``s.
/// Adopting this protocol does two things:
///
/// 1) It tells the reader that the ``WorkflowAction`` leans on other ``WorkflowAction``s to complete the action.
/// 2) Exposes a convenience method for executing ``WorkflowAction``s without having to explicitly invoke the action's ``execute(_:)`` method.
///
/// Example Implementation that mimics how an app may sign in a user.
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
///         let tokens = try await execute(ObtainTokensWorkflowAction(authorizationCode: authorizationCode, clientSecret: clientSecret)
///         return try await execute(PersistTokensInKeychainWorkflowAction(tokens: tokens)
///     }
/// }
/// ```
///
/// Of course, there's nothing stopping you from implementing the action as a non-`CompositeWorkflowAction`. But I think you'll agree that adopting the
/// `CompositeWorkflowAction` helps document the action's intentions as a "composite", and simplifies the implementation by using the convenience
/// ``execute(_:)`` method.
/// ```
public protocol CompositeWorkflowAction: WorkflowAction {
}

extension CompositeWorkflowAction {

    public func execute<A: WorkflowAction>(_ action: A) async throws -> A.T {
        return try await action.execute()
    }
}
