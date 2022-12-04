import Foundation
import Hollywood

/// https://vorpus.org/blog/timeouts-and-cancellation-for-humans/
/// https://twitter.com/pathofshrines/status/1405976017525673984
struct TimeoutAction: WorkflowAction {

    let duration: Duration
    let timeoutCallback: @Sendable () -> Void

    func execute() async throws {
        try await Task.sleep(for: duration)
        try Task.checkCancellation()

        timeoutCallback()
        throw TimeOutError()
    }
}
