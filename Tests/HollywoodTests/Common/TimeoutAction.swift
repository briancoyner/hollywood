import Foundation
import Hollywood

/// https://vorpus.org/blog/timeouts-and-cancellation-for-humans/
/// https://twitter.com/pathofshrines/status/1405976017525673984
struct TimeoutAction: WorkflowAction {

    let duration: Int
    let timeoutCallback: @Sendable () -> Void

    func execute() async throws {
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        try Task.checkCancellation()

        timeoutCallback()
        throw TimeOutError()
    }
}
