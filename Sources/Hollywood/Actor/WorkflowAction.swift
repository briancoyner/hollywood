import Foundation

/// A `WorkflowAction` is a simple command that asynchronously executes to produce a value `T`.
///
/// A good way to think about this protocol is that it forces developers to give a discoverable name to an asynchronous
/// function. For a large code base, with multiple developers contributing code, this helps with discoverability,
/// maintenance, and just generally helps organize reusable, composable asynchronous functions.
///
/// Implementations typically following this naming scheme:
/// - `<Action><Noun>WorkflowAction`
///
/// Here are some examples to help motivate this protocol:
/// - `ObtainTokensWorkflowAction`
/// - `SearchMusicStoreWorkflowAction`
/// - `LoadPhotosPickerSelectedImageWorkflowAction`
/// - `FetchModulesFromPersistentStorageWorkflowAction`
/// - `ValidateFileChecksumWorkflowAction`
///
/// Of course you're free to omit the `WorkflowAction` suffix if you think it's too noisy.
/// - `<Action><Noun>`
///
/// Thus leading to alternative naming examples:
/// - `ObtainTokens`
/// - `SearchMusicStore`
/// - `LoadPhotosPickerSelectedImage`
/// - `FetchModulesFromPersistentStorage`
/// - `ValidateFileChecksum`
///
/// - SeeAlso: ``CompositeWorkflowAction`` for an API that helps with executing composed actions.
public protocol WorkflowAction<T>: Sendable {

    associatedtype T: Sendable

    /// Implementations should throw a `CancellationError` if the workflow action cancels. `Task.checkCancellation()`,
    /// 
    /// - Returns: `T` upon success.
    /// - Throws: `CancellationError` if the workflow action cancels
    func execute() async throws -> T
}
