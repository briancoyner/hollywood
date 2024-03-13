import Foundation

extension Progress {

    /// Used by tests that don't care about tracking progress. This is effectively an indeterminate progress.
    static var indeterminate: Progress {
        return Progress(totalUnitCount: 0)
    }
}
