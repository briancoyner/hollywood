import Foundation
import Hollywood

extension ContextualActor.State: Equatable where T: Equatable {

    public static func == (lhs: ContextualActor.State, rhs: ContextualActor.State) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready):
            return true
        case (.busy(let lhsValue, let lhsProgress), .busy(let rhsValue, let rhsProgress)):
            /// TODO: Revisit this.
            return lhsValue == rhsValue
                && lhsProgress.isIndeterminate == rhsProgress.isIndeterminate
                && lhsProgress.isCancelled == rhsProgress.isCancelled
                && lhsProgress.isFinished == rhsProgress.isFinished
                && lhsProgress.isCancellable == rhsProgress.isCancellable
                && lhsProgress.isCancelled == rhsProgress.isCancelled
                && lhsProgress.totalUnitCount == rhsProgress.totalUnitCount
                && lhsProgress.completedUnitCount == rhsProgress.completedUnitCount
        case (.success(let lhsValue), .success(let rhsValue)):
            return lhsValue == rhsValue
        case (.failure(let lhsError, let lhsValue), .failure(let rhsError, let rhsValue)):
            return lhsError as NSError == rhsError as NSError && lhsValue == rhsValue
        case (.ready, _), (.busy, _), (.success, _), (.failure, _):
            return false
        }
    }
}
