import XCTest

import Hollywood

@MainActor
final class ContextualActorStateObserver<T> where T: Sendable, T: Equatable {

    let semaphore: XCTestExpectation

    private let contextualActor: ContextualActor<T>
    private let waitForState: ContextualActor<T>.State
    private var collected: [ContextualActor<T>.State] = []

    init(
        contextualActor: ContextualActor<T>,
        waitForState: ContextualActor<T>.State,
        ignoreInitialState: Bool = false
    ) {
        self.contextualActor = contextualActor
        self.waitForState = waitForState
        self.semaphore = XCTestExpectation()

        if !ignoreInitialState {
            collected.append(contextualActor.state)
        }

        observeNextStateChange()
    }
}

extension ContextualActorStateObserver {

    func verify(expectedStates: [ContextualActor<T>.State]) async throws {
        await XCTWaiter().fulfillment(of: [semaphore], timeout: 3)

        XCTAssertEqual(expectedStates, collected)
        collected.removeAll()
    }
}

extension ContextualActorStateObserver {

    private func observeNextStateChange() {
        withObservationTracking {
            _ = contextualActor.state
        } onChange: {
            DispatchQueue.main.async { [self] in
                collected.append(contextualActor.state)

                if contextualActor.state == waitForState {
                    semaphore.fulfill()
                } else {
                    observeNextStateChange()
                }
            }
        }
    }
}
