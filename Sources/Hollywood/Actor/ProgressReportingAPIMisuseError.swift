import Foundation

/// An error indicating a developer failed to set up the ``TaskProgress`` task-local variable to correctly manage progress reporting.
/// This error is considered a programmer error to be discovered during development. The fix for this error is described below.
///
/// This error is thrown when accessing the ``TaskProgress/safeProgress`` property and the underlying task-local
/// ``TaskProgress/progress`` is `nil`. The Hollywood framework ensures this error is never thrown. However,
/// developers may are use ``TaskProgress`` independent of a ``ContextualActor``. Therefore, developers must wrap
/// a progress reporting async function in a call to `TaskProgress.$progress.withValue(...) { ... }`.
struct ProgressReportingAPIMisuseError: Error {
}
