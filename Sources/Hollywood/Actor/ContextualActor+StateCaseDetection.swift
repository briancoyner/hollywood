import Foundation

extension ContextualActor {

    /// - Returns: true if the contextual actor is currently in the ``State-swift.enum/busy(_:)`` state.
    public var isBusy: Bool {
        switch state {
        case .busy(_):
            return true
        default:
            return false
        }
    }
}
