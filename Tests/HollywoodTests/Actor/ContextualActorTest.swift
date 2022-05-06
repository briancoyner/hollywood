import XCTest
import AsyncAlgorithms

import Hollywood

final class ContextualActorTest: XCTestCase {
}

extension ContextualActorTest {

    override func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false
    }
}

// MARK: Initializer/ Initial State Tests

extension ContextualActorTest {

    @MainActor
    func testDefaultInitializer_InitialStateIsReady() throws {
        let contextualActor = ContextualActor<String>()
        XCTAssertEqual(.ready, contextualActor.state)
    }

    @MainActor
    func testInitialValueAutomaticallyTransitionsToASuccessStateWithTheInitialValue() throws {
        let value = "Brian"
        let contextualActor = ContextualActor<String>(initialValue: value)

        XCTAssertEqual(.success(value), contextualActor.state)
    }

    @MainActor
    func testInitialErrorWithDefaultInitialValueAutomaticallyTransitionsToAFailureStateWithTheInitialErrorAndDefaultInitialValue() throws {
        let error = MockError()
        let contextualActor = ContextualActor<String>(initialError: error)

        XCTAssertEqual(.failure(error, nil), contextualActor.state)
    }

    @MainActor
    func testInitialErrorWithExplicitNilInitialValueAutomaticallyTransitionsToAFailureStateWithTheInitialErrorAndNilInitialValue() throws {
        let error = MockError()
        let contextualActor = ContextualActor<String>(initialError: error, initialValue: nil)

        XCTAssertEqual(.failure(error, nil), contextualActor.state)
    }

    @MainActor
    func testInitialErrorWithExplicitNonNilInitialValueAutomaticallyTransitionsToAFailureStateWithTheInitialErrorAndInitialValue() throws {
        let error = MockError()
        let value = "Brian"
        let contextualActor = ContextualActor<String>(initialError: error, initialValue: value)

        XCTAssertEqual(.failure(error, value), contextualActor.state)
    }
}

// MARK: Success Tests

extension ContextualActorTest {

    @MainActor
    func testExecuteActionThatReturnsAValue_VerifyStateTransitionsToBusy_ThenToSuccessWithTheReturnValue() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        contextualActor.execute(MockWorkflowAction(state: .mockResult("Brian")))
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .success("Brian"),
            .busy("Brian"),
            .success(poisonPill)
        ])
    }

    @MainActor
    func testExecuteMultipleActionsThatReturnValues_VerifyActionsExecuteInOrderAndCorrectlyTransitionStates() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        contextualActor.execute(MockWorkflowAction(state: .mockResult("Brian")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Coyner")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Was Here")))
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .success("Brian"),
            .busy("Brian"),
            .success("Coyner"),
            .busy("Coyner"),
            .success("Was Here"),
            .busy("Was Here"),
            .success(poisonPill)
        ])
    }

    @MainActor
    func testExecuteAFloodOfActionsThatReturnValues_VerifyActionsExecuteInOrderAndCorrectlyTransitionStates() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        let count = 500
        for index in 1..<count {
            contextualActor.execute(MockWorkflowAction(state: .mockResult(index.formatted())))
        }
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        var expectedStates: [ContextualActor<String>.State] = []
        expectedStates.append(.ready)
        expectedStates.append(.busy(nil))

        for index in 1..<count {
            let value = index.formatted()
            expectedStates.append(.success(value))
            expectedStates.append(.busy(value))
        }

        expectedStates.append(.success(poisonPill))

        try await observer.verify(expectedStates: expectedStates)
    }
}

// MARK: Cancellation Tests

extension ContextualActorTest {

    @MainActor
    func testCancelWhenInReadyState_VerifyNoStateTransitions_StateRemainsInReady() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        // The contextual actor is currently in the `.ready` state. Therefore, calling `cancel`
        // should be a no-op (i.e. no events from cancellation should be generated/ published).
        contextualActor.cancel()

        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil), // caused by the `PoisonPillWorkflowAction`
            .success(poisonPill) // caused by the `PoisonPillWorkflowAction`
        ])
    }

    @MainActor
    func testExecuteActionThatIsCancelled_ThenSubmitPoisonPillActionAfterActionIsCancelled_VerifyCancelledActionCausesATransitionToTheReadyState() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        let executingExpectation = Semaphore()
        let waitForCancellationExpectation = Semaphore()
        let actionThatIsCancelled = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))

        contextualActor.execute(actionThatIsCancelled)

        // Suspend the test until the `actionThatIsCancelled` is executing.
        // At this point, the `actionThatIsCancelled` is now waiting for the test
        // to signal the `waitForCancellationExpectation` (see below).
        try await executingExpectation.wait()

        XCTAssertEqual(.busy(nil), contextualActor.state)
        // Calling cancel immediately puts the contextual actor in the `.ready` state.
        contextualActor.cancel()
        XCTAssertEqual(.ready, contextualActor.state)

        // The underlying `Task` should now be cancelled, so let's signal the `actionThatIsCancelled`
        // to continue executing. The `MockWorkflowAction` at this point checks the `Task`'s cancellation
        // state and should throw `CancellationError`. The contextual resource ignores the `CancellationError`
        // because the poison pill action is now the active workflow.
        waitForCancellationExpectation.signal()

        // Now let's finalize the test by submitting a poison pill so that the state observer knows
        // when we are finished.
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .ready, // This is caused by the `ContextualActor.cancel` call.
            .busy(nil),
            .success(poisonPill)
        ])
    }

    @MainActor
    func testExecuteActionThatIsCancelled_ThenSubmitPoisonPillActionBeforeActionIsCancelled_VerifyCancelledActionCausesATransitionToTheReadyState() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        let executingExpectation = Semaphore()
        let waitForCancellationExpectation = Semaphore()
        let actionThatIsCancelled = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))

        contextualActor.execute(actionThatIsCancelled)

        // Suspend the test until the `actionThatIsCancelled` is executing.
        // At this point, the `actionThatIsCancelled` is now waiting for the test
        // to signal the `waitForCancellationExpectation` (see below).
        try await executingExpectation.wait()

        XCTAssertEqual(.busy(nil), contextualActor.state)
        contextualActor.cancel()
        XCTAssertEqual(.ready, contextualActor.state)

        // Important... the poison pill action begins execution before the `actionThatIsCancelled` knows that
        // it's been cancelled. The contextual resource ignores the `CancellationError` because the poison
        // pill action is now the active workflow.
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        waitForCancellationExpectation.signal()

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .ready, // This is caused by the `ContextualActor.cancel` call.
            .busy(nil),
            .success(poisonPill)
        ])
    }
}

extension ContextualActorTest {

    @MainActor
    func testExecuteActionThatIsCancelledWhenPreviousStateIsSuccess_VerifyCapturedStates() async throws {

        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        // Note: This puts the contextual actor into the `.success("Brian")` state.
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Brian")))

        let executingExpectation = Semaphore()
        let waitForCancellationExpectation = Semaphore()
        let action = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))
        contextualActor.execute(action)
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await executingExpectation.wait()

        XCTAssertEqual(.busy("Brian"), contextualActor.state)
        contextualActor.cancel()
        XCTAssertEqual(.ready, contextualActor.state)

        waitForCancellationExpectation.signal()

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .success("Brian"),
            .busy("Brian"),
            .ready,
            .busy(nil),
            .success(poisonPill)
        ])
    }

    @MainActor
    func testCancelDoesNotExecuteEnqueuedWorkflowActions() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        let executingExpectation = Semaphore()
        let waitForCancellationExpectation = Semaphore()
        let action = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))
        contextualActor.execute(action)

        try await executingExpectation.wait()

        // The current action is now executing.
        // Let's go ahead and enqueue a few workflow actions.

        contextualActor.execute(MockWorkflowAction(state: .mockResult("Apple")), cancelIfBusy: true)
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Orange")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Pineapple")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Banana")))

        waitForCancellationExpectation.signal()

        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

//        Ready, Busy: nil, Ready, Busy: nil, Success: Apple, Busy: Optional("Apple"), Ready, Busy: Optional("Apple"), Ready, Busy: Optional("Apple"), Success: PoisonPill]")
        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .ready,
            .busy(nil),
            .success("Apple"),
            .busy("Apple"),
            .success("Orange"),
            .busy("Orange"),
            .success("Pineapple"),
            .busy("Pineapple"),
            .success("Banana"),
            .busy("Banana"),
            .success(poisonPill)
        ])
    }
}

// MARK: Errors

extension ContextualActorTest {

    @MainActor
    func testExecuteActionThatThrowsAnError_VerifyErrorIsCaptured() async throws {
        let contextualActor = ContextualActor<String>(initialValue: "Brian")

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        let error = MockError()
        contextualActor.execute(MockWorkflowAction(state: .mockError(error)))
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .success("Brian"),
            .busy("Brian"),
            .failure(error, "Brian"),
            .busy("Brian"),
            .success(poisonPill)
        ])
    }
}

// MARK: Reset

extension ContextualActorTest {

    @MainActor
    func testResetWhenInReadyState_NoAdditionalReadyStateChangesArePublished() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        contextualActor.reset()
        contextualActor.reset()
        contextualActor.reset()
        contextualActor.reset()
        contextualActor.reset()
        contextualActor.reset()

        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .success(poisonPill)
        ])
    }

    @MainActor
    func testResetWhenInSuccessState_TransitionsToReadyState() async throws {
        let contextualActor = ContextualActor<String>()

        try await transition(contextualActor: contextualActor, toValue: "Brian")

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill),
            ignoreInitialState: true
        )

        contextualActor.reset()
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .success(poisonPill)
        ])
    }

    @MainActor
    func testResetWhenInErrorState_TransitionsToReadyState() async throws {
        let contextualActor = ContextualActor<String>()

        let error = MockError()
        try await transition(contextualActor: contextualActor, toError: error)

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill),
            ignoreInitialState: true
        )

        contextualActor.reset()
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .success(poisonPill)
        ])
    }

    @MainActor
    func testResetDoesNotExecuteEnqueuedWorkflowActions() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(poisonPill)
        )

        let executingExpectation = Semaphore()
        let waitForCancellationExpectation = Semaphore()
        let action = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))
        contextualActor.execute(action)

        try await executingExpectation.wait()

        // The current action is now executing.
        // Let's go ahead and enqueue a few workflow actions.

        contextualActor.execute(MockWorkflowAction(state: .mockResult("Apple")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Orange")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Pineapple")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Banana")))

        contextualActor.reset()
        XCTAssertEqual(.ready, contextualActor.state)

        waitForCancellationExpectation.signal()

        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil),
            .ready,
            .busy(nil),
            .success(poisonPill)
        ])
    }
}

extension ContextualActorTest {

    @MainActor
    private func transition(
        contextualActor: ContextualActor<String>,
        toValue value: String
    ) async throws {

        let initialState = contextualActor.state
        let currentValue = initialBusyStateValue(basedOn: contextualActor.state)

        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .success(value)
        )

        contextualActor.execute(MockWorkflowAction(state: .mockResult(value)))

        try await observer.verify(expectedStates: [
            initialState,
            .busy(currentValue),
            .success(value)
        ])
    }

    @MainActor
    private func transition(contextualActor: ContextualActor<String>, toError error: Error) async throws {

        let initialState = contextualActor.state
        let currentValue = initialBusyStateValue(basedOn: contextualActor.state)

        let observer = ContextualActorStateObserver(
            statePublisher: contextualActor.$state,
            waitForState: .failure(error, currentValue)
        )

        contextualActor.execute(MockWorkflowAction(state: .mockError(error)))

        try await observer.verify(expectedStates: [
            initialState,
            .busy(currentValue),
            .failure(error, currentValue)
        ])
    }

    private func initialBusyStateValue(basedOn initialState: ContextualActor<String>.State) -> String? {
        switch initialState {
        case .ready:
            return nil
        case .busy(_):
            XCTFail("Invalid initialState")
            return nil
        case .success(let value):
            return value
        case .failure(_, let value):
            return value
        }
    }
}
