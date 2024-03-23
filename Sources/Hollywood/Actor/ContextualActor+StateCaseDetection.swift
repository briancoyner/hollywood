import Foundation

extension ContextualActor.State {

    /// - Returns: `true` if currently in the ready state.
    public var isReady: Bool {
        switch self {
        case .ready:
            return true

        case .busy(_, _), .success(_), .failure(_, _):
            return false
        }
    }

    /// - Returns: `true` if currently in the busy state.
    public var isBusy: Bool {
        switch self {
        case .busy(_, _):
            return true

        case .ready, .success(_), .failure(_, _):
            return false
        }
    }

    /// - Returns: `T` if it is contained within the state, whether it be busy, success or failure.
    public var value: T? {
        switch self {
        case .ready:
            return nil

        case .busy(let value, _), .failure(_, let value):
            return value

        case .success(let value):
            return value
        }
    }

    /// - Returns: `any Error` if in the failure state, useful in cases the error is the only component needed for display.
    public var error: (any Error)? {
        switch self {
        case .ready, .busy(_, _), .success(_):
            return nil

        case .failure(let error, _):
            return error
        }
    }
}
