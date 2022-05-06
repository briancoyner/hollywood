import Combine
import XCTest

import Hollywood

@MainActor
final class ContextualActorStateObserver<T> where T: Sendable, T: Equatable {

    let semaphore: Semaphore

    private let statePublisher: Published<ContextualActor<T>.State>.Publisher
    private var observer: AnyCancellable?
    private var collected: [ContextualActor<T>.State] = []

    init(
        statePublisher: Published<ContextualActor<T>.State>.Publisher,
        waitForState: ContextualActor<T>.State,
        ignoreInitialState: Bool = false
    ) {
        self.statePublisher = statePublisher
        self.semaphore = Semaphore()

        self.observer = statePublisher
            .dropFirst(ignoreInitialState ? 1 : 0)
            .sink { [weak self, semaphore] state in
                self?.collected.append(state)

                if state == waitForState {
                    semaphore.signal()
                }
            }
    }
}

extension ContextualActorStateObserver {

    func verify(expectedStates: [ContextualActor<T>.State]) async throws {
        try await semaphore.wait(forAtLeast: 3)

        XCTAssertEqual(expectedStates, collected)
        collected.removeAll()
    }
}
