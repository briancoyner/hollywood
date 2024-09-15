import XCTest  // XCTWaiter + XCTestExpectation
import Testing

import Hollywood

struct ContextualActorTest {
}

// MARK: - Initializer/ Initial State Tests

extension ContextualActorTest {

    @Test @MainActor
    func defaultInitializer_InitialStateIsReady() throws {
        let contextualActor = ContextualActor<String>()
        #expect(contextualActor.state == .ready)
        #expect(contextualActor.state.isBusy == false)
    }

    @Test @MainActor
    func initialValueAutomaticallyTransitionsToASuccessStateWithTheInitialValue() throws {
        let value = "Brian"
        let contextualActor = ContextualActor<String>(initialValue: value)

        #expect(contextualActor.state == .success(value))
        #expect(contextualActor.state.isBusy == false)
    }

    @Test @MainActor
    func initialErrorWithDefaultInitialValueAutomaticallyTransitionsToAFailureStateWithTheInitialErrorAndDefaultInitialValue() throws {
        let error = MockError()
        let contextualActor = ContextualActor<String>(initialError: error)

        #expect(contextualActor.state == .failure(error, nil))
        #expect(contextualActor.state.isBusy == false)
    }

    @Test @MainActor
    func initialErrorWithExplicitNilInitialValueAutomaticallyTransitionsToAFailureStateWithTheInitialErrorAndNilInitialValue() throws {
        let error = MockError()
        let contextualActor = ContextualActor<String>(initialError: error, initialValue: nil)

        #expect(contextualActor.state == .failure(error, nil))
        #expect(contextualActor.state.isBusy == false)
    }

    @Test @MainActor
    func initialErrorWithExplicitNonNilInitialValueAutomaticallyTransitionsToAFailureStateWithTheInitialErrorAndInitialValue() throws {
        let error = MockError()
        let value = "Brian"
        let contextualActor = ContextualActor<String>(initialError: error, initialValue: value)

        #expect(contextualActor.state == .failure(error, value))
        #expect(contextualActor.state.isBusy == false)
    }
}

// MARK: - Success Tests

extension ContextualActorTest {

    @Test @MainActor
    func executeActionThatReturnsAValue_VerifyStateTransitionsToBusy_ThenToSuccessWithTheReturnValue() async throws {
        let contextualActor = ContextualActor<String>()

        let value = "Brian"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(value)
        )

        contextualActor.execute(MockWorkflowAction(state: .mockResult("Brian")))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil, .indeterminate),
            .success("Brian")
        ])
    }

    @Test @MainActor
    func executeMultipleActionsThatReturnValues_VerifyActionsExecuteInOrderAndCorrectlyTransitionStates() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        contextualActor.execute(MockWorkflowAction(state: .mockResult("Brian")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Coyner")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Was Here")))
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil, .indeterminate),
            .busy("Brian", .indeterminate),
            .busy("Coyner", .indeterminate),
            .busy("Was Here", .indeterminate),
            .success(poisonPill)
        ])
    }

    @Test @MainActor
    func executeAFloodOfActionsThatReturnValues_VerifyActionsExecuteInOrderAndCorrectlyTransitionStates() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        let count = 500
        for index in 1..<count {
            contextualActor.execute(MockWorkflowAction(state: .mockResult(index.formatted())))
        }
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        var expectedStates: [ContextualActor<String>.State] = []
        expectedStates.append(.ready)
        expectedStates.append(.busy(nil, .indeterminate))

        for index in 1..<count {
            let value = index.formatted()
            expectedStates.append(.busy(value, .indeterminate))
        }

        expectedStates.append(.success(poisonPill))

        try await observer.verify(expectedStates: expectedStates)
    }
}

// MARK: - Cancellation Tests

extension ContextualActorTest {

    @Test @MainActor
    func cancelWhenInReadyState_VerifyNoStateTransitions_StateRemainsInReady() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        // The contextual actor is currently in the `.ready` state. Therefore, calling `cancel`
        // should be a no-op (i.e. no events from cancellation should be generated/ published).
        contextualActor.cancel()

        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil, .indeterminate), // caused by the `PoisonPillWorkflowAction`
            .success(poisonPill) // caused by the `PoisonPillWorkflowAction`
        ])
    }

    @Test @MainActor
    func executeActionThatIsCancelled_ThenSubmitPoisonPillActionAfterActionIsCancelled_VerifyCancelledActionCausesATransitionToTheReadyState() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        let executingExpectation = XCTestExpectation()
        let waitForCancellationExpectation = XCTestExpectation()
        let actionThatIsCancelled = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))

        contextualActor.execute(actionThatIsCancelled)

        // Suspend the test until the `actionThatIsCancelled` is executing.
        // At this point, the `actionThatIsCancelled` is now waiting for the test
        // to signal the `waitForCancellationExpectation` (see below).
        let result = await XCTWaiter().fulfillment(of: [executingExpectation], timeout: 3)
        #expect(result == .completed)

        #expect(contextualActor.state == .busy(nil, .indeterminate))
        // Calling cancel immediately puts the contextual actor in the `.ready` state.
        contextualActor.cancel()
        #expect(contextualActor.state == .ready)

        // The underlying `Task` should now be cancelled, so let's signal the `actionThatIsCancelled`
        // to continue executing. The `MockWorkflowAction` at this point checks the `Task`'s cancellation
        // state and should throw `CancellationError`. The contextual resource ignores the `CancellationError`
        // because the poison pill action is now the active workflow.
        waitForCancellationExpectation.fulfill()

        // Now let's finalize the test by submitting a poison pill so that the state observer knows
        // when we are finished.
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil, .indeterminate),
            // Internally, the ContextualResource transitions to the `.ready` state, but due to how the
            // @Observable macro works with the `withObservationTracking(apply:onChange:)` function, only the
            // last state at the end of the main run loop is observed.
            // .ready,
                .busy(nil, .indeterminate),
            .success(poisonPill)
        ])
    }

    @Test @MainActor
    func executeActionThatIsCancelled_ThenSubmitPoisonPillActionBeforeActionIsCancelled_VerifyCancelledActionCausesATransitionToTheReadyState() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        let executingExpectation = XCTestExpectation()
        let waitForCancellationExpectation = XCTestExpectation()
        let actionThatIsCancelled = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))

        contextualActor.execute(actionThatIsCancelled)

        // Suspend the test until the `actionThatIsCancelled` is executing.
        // At this point, the `actionThatIsCancelled` is now waiting for the test
        // to signal the `waitForCancellationExpectation` (see below).
        let result = await XCTWaiter().fulfillment(of: [executingExpectation], timeout: 3)
        #expect(result == .completed)

        #expect(contextualActor.state == .busy(nil, .indeterminate))
        contextualActor.cancel()
        #expect(contextualActor.state == .ready)

        // Important... the poison pill action begins execution before the `actionThatIsCancelled` knows that
        // it's been cancelled. The contextual resource ignores the `CancellationError` because the poison
        // pill action is now the active workflow.
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        waitForCancellationExpectation.fulfill()

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil, .indeterminate),
            // Internally, the ContextualResource transitions to the `.ready` state, but due to how the
            // @Observable macro works with the `withObservationTracking(apply:onChange:)` function, only the
            // last state at the end of the main run loop is observed.
            // .ready,
            .busy(nil, .indeterminate),
            .success(poisonPill)
        ])
    }
}

extension ContextualActorTest {

    @Test @MainActor
    func executeActionThatIsCancelledWhenPreviousStateIsSuccess_VerifyCapturedStates() async throws {

        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        // Note: This puts the contextual actor into the `.success("Brian")` state.
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Brian")))

        let executingExpectation = XCTestExpectation()
        let waitForCancellationExpectation = XCTestExpectation()
        let action = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))
        contextualActor.execute(action)
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        let result = await XCTWaiter().fulfillment(of: [executingExpectation], timeout: 3)
        #expect(result == .completed)

        #expect(contextualActor.state == .busy("Brian", .indeterminate))
        contextualActor.cancel()
        #expect(contextualActor.state == .ready)

        waitForCancellationExpectation.fulfill()

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil, .indeterminate),
            .busy("Brian", .indeterminate),
            .ready,
            .busy(nil, .indeterminate),
            .success(poisonPill)
        ])
    }

    @Test @MainActor
    func cancelDoesNotExecuteEnqueuedWorkflowActions() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        let executingExpectation = XCTestExpectation()
        let waitForCancellationExpectation = XCTestExpectation()
        let action = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))
        contextualActor.execute(action)

        let result = await XCTWaiter().fulfillment(of: [executingExpectation], timeout: 3)
        #expect(result == .completed)

        // The current action is now executing.
        // Let's go ahead and enqueue a few workflow actions.

        contextualActor.execute(MockWorkflowAction(state: .mockResult("Apple")), cancelIfBusy: true)
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Orange")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Pineapple")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Banana")))

        waitForCancellationExpectation.fulfill()

        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil, .indeterminate),
            .busy(nil, .indeterminate),
            .busy("Apple", .indeterminate),
            .busy("Orange", .indeterminate),
            .busy("Pineapple", .indeterminate),
            .busy("Banana", .indeterminate),
            .success(poisonPill)
        ])
    }
}

// MARK: - Errors

extension ContextualActorTest {

    @Test @MainActor
    func executeActionThatThrowsAnError_VerifyErrorIsCaptured() async throws {
        let contextualActor = ContextualActor<String>(initialValue: "Brian")

        let error = MockError()
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .failure(error, "Brian")
        )

        contextualActor.execute(MockWorkflowAction(state: .mockError(error)))

        try await observer.verify(expectedStates: [
            .success("Brian"),
            .busy("Brian", .indeterminate),
            .failure(error, "Brian")
        ])
    }
}

// MARK: - Reset

extension ContextualActorTest {

    @Test @MainActor
    func resetWhenInReadyState_NoAdditionalReadyStateChangesArePublished() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
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
            .busy(nil, .indeterminate),
            .success(poisonPill)
        ])
    }

    @Test @MainActor
    func resetWhenInSuccessState_TransitionsToReadyState() async throws {
        let contextualActor = ContextualActor<String>()

        try await transition(contextualActor: contextualActor, toValue: "Brian")

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        contextualActor.reset()
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .success("Brian"), // This is the initial state.
            .busy(nil, .indeterminate), // The reset cleared the "Brian" result.
            .success(poisonPill)
        ])
    }

    @Test @MainActor
    func resetWhenInErrorState_TransitionsToReadyState() async throws {
        let contextualActor = ContextualActor<String>()

        let error = MockError()
        try await transition(contextualActor: contextualActor, toError: error)

        let resetObserver = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .ready,
            ignoreInitialState: true
        )

        contextualActor.reset()
        try await resetObserver.verify(expectedStates: [
            .ready
        ])

        let poisonPill = "PoisonPill"
        let executionObserver = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill),
            ignoreInitialState: true
        )
        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await executionObserver.verify(expectedStates: [
            .busy(nil, .indeterminate),
            .success(poisonPill)
        ])
    }

    @Test @MainActor
    func resetDoesNotExecuteEnqueuedWorkflowActions() async throws {
        let contextualActor = ContextualActor<String>()

        let poisonPill = "PoisonPill"
        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .success(poisonPill)
        )

        let executingExpectation = XCTestExpectation()
        let waitForCancellationExpectation = XCTestExpectation()
        let action = MockWorkflowAction<String>(state: .mockCancellation(
            executingExpectation: executingExpectation,
            waitForCancellationExpectation: waitForCancellationExpectation
        ))
        contextualActor.execute(action)

        let result = await XCTWaiter().fulfillment(of: [executingExpectation], timeout: 3)
        #expect(result == .completed)

        // The current action is now executing.
        // Let's go ahead and enqueue a few workflow actions.

        contextualActor.execute(MockWorkflowAction(state: .mockResult("Apple")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Orange")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Pineapple")))
        contextualActor.execute(MockWorkflowAction(state: .mockResult("Banana")))

        contextualActor.reset()
        #expect(contextualActor.state == .ready)

        waitForCancellationExpectation.fulfill()

        contextualActor.execute(PoisonPillWorkflowAction(poisonPill: poisonPill))

        try await observer.verify(expectedStates: [
            .ready,
            .busy(nil, .indeterminate),
            .busy(nil, .indeterminate),
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
            contextualActor: contextualActor,
            waitForState: .success(value)
        )

        contextualActor.execute(MockWorkflowAction(state: .mockResult(value)))

        #expect(contextualActor.state.isBusy)

        let progress = Progress()
        try await observer.verify(expectedStates: [
            initialState,
            .busy(currentValue, progress),
            .success(value)
        ])
    }

    @MainActor
    private func transition(contextualActor: ContextualActor<String>, toError error: any Error) async throws {

        let initialState = contextualActor.state
        let currentValue = initialBusyStateValue(basedOn: contextualActor.state)

        let observer = ContextualActorStateObserver(
            contextualActor: contextualActor,
            waitForState: .failure(error, currentValue)
        )

        contextualActor.execute(MockWorkflowAction(state: .mockError(error)))

        try await observer.verify(expectedStates: [
            initialState,
            .busy(currentValue, .indeterminate),
            .failure(error, currentValue)
        ])
    }

    private func initialBusyStateValue(basedOn initialState: ContextualActor<String>.State) -> String? {
        switch initialState {
        case .ready:
            return nil
        case .busy(_, _):
            Issue.record("Invalid initialState")
            return nil
        case .success(let value):
            return value
        case .failure(_, let value):
            return value
        }
    }
}
