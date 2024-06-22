/// An `AsyncCacheCommand` is a simple command that asynchronously executes to produce a value `T`.
///
/// The idea of this protocol is similar to ``WorkflowAction``. So why another protocol with
/// effectively the same signature? Mostly context. Even though the ``AsyncCacheCommand`` has a
/// similar definition, its use case is different from a ``WorkflowAction`` and a ``ContextualActor``.
/// A big difference is that an ``AsyncCacheCommand`` is meant to represent a value that does
/// not require progress reporting.
public protocol AsyncCacheCommand<T>: Sendable {

    associatedtype T: Sendable

    /// Implementations should throw a `CancellationError` if the workflow action cancels.
    ///
    /// - Returns: `T` upon success.
    /// - Throws: `CancellationError` if the workflow action cancels
    func execute() async throws -> T
}
