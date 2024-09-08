import XCTest

import Hollywood

final class AsyncCacheTest: XCTestCase {
}

// MARK: - Basic Tests

extension AsyncCacheTest {

    func testAwaitInitialValueReturnedValueFromTheCommand() async throws {
        let expectedInitialValue = 98
        let actor = AsyncCache<Int>(command: IncrementingIntegerCommand(initialValue: expectedInitialValue))

        let initialValue = try await actor.value
        XCTAssertEqual(expectedInitialValue, initialValue)
    }

    func testAwaitValueMultipleTimesSerially_EachCallerReceivesTheCachedValue() async throws {
        let expectedInitialValue = 98
        let actor = AsyncCache<Int>(command: IncrementingIntegerCommand(initialValue: expectedInitialValue))

        let initialValue = try await actor.value
        XCTAssertEqual(expectedInitialValue, initialValue)

        let valueA = try await actor.value
        let valueB = try await actor.value
        let valueC = try await actor.value

        XCTAssertEqual(expectedInitialValue, valueA)
        XCTAssertEqual(expectedInitialValue, valueB)
        XCTAssertEqual(expectedInitialValue, valueC)
    }

    func testAwaitValueConcurrentlyUsingAsyncLet_EachCallerReceivesTheCachedValue() async throws {
        let expectedInitialValue = 98
        let actor = AsyncCache<Int>(command: IncrementingIntegerCommand(initialValue: expectedInitialValue))

        let initialValue = try await actor.value
        XCTAssertEqual(expectedInitialValue, initialValue)

        async let a = actor.value
        async let b = actor.value
        async let c = actor.value

        let valueA = try await a
        let valueB = try await b
        let valueC = try await c

        XCTAssertEqual(expectedInitialValue, valueA)
        XCTAssertEqual(expectedInitialValue, valueB)
        XCTAssertEqual(expectedInitialValue, valueC)
    }

    func testAwaitValueConcurrentlyUsingATaskGroup_EachCallerReceivesTheCachedValue() async throws {
        let expectedInitialValue = 98
        let actor = AsyncCache<Int>(command: IncrementingIntegerCommand(initialValue: expectedInitialValue))

        let initialValue = try await actor.value
        XCTAssertEqual(expectedInitialValue, initialValue)

        // At this point the cache has a value. Now let's submit a bunch concurrent calls to
        // grab the cached value. The cached value from the initial load is always returned.

        let numberOfCallsToValue = 2000
        let results = try await withThrowingTaskGroup(of: (Int, Int).self) { group in
            for counter in 1...numberOfCallsToValue {
                group.addTask {
                    return (counter, try await actor.value)
                }
            }

            var results = [Int: Int]()
            for try await (key, value) in group {
                results[key] = value
            }
            return results
        }

        XCTAssertEqual(numberOfCallsToValue, results.count)
        for result in results {
            XCTAssertEqual(expectedInitialValue, result.value)
        }
    }
}

// MARK: - Error Tests

extension AsyncCacheTest {

    func testAwaitInitialValueThrowsAnError() async throws {
        final class TestError: Error {
        }

        let expectedError = TestError()

        let actor = AsyncCache<Int>(command: ThrowErrorCommand(error: expectedError))

        do {
            let unexpectedValue = try await actor.value
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        // Do it again to ensure the cache's state can continue to deal with multiple errors.
        do {
            let unexpectedValue = try await actor.value
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }
    }

    func testAwaitInitialValueThrowsAnError_AwaitSecondCallReturnsValueFromTheCommand() async throws {
        final class TestError: Error {
        }

        let expectedError = TestError()
        let expectedInitialValue = 151

        let actor = AsyncCache<Int>(command: CompositeCommand(commands: [
            // The first call to retrieve the value throws an error.
            ThrowErrorCommand(error: expectedError),
            // The second call to retrieve the value succeeds and caches the `expectedInitialValue`.
            IncrementingIntegerCommand(initialValue: expectedInitialValue)
        ]))

        // The first call to `value` ends up throwing the `expectedError`. This leaves the cache
        // in a state where the next call to `value` returns the `expectedInitialValue`.
        do {
            let unexpectedValue = try await actor.value
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        // The second call to `value` re-executes the command, which returns the `expectedInitialValue`.
        let initialValue = try await actor.value
        XCTAssertEqual(expectedInitialValue, initialValue)
    }

    func testAwaitInitialValueThrowsAnError_OtherCallsAreInterleavedAndCatchTheSameError() async throws {
        final class TestError: Error {
        }

        let expectedError = TestError()
        let expectedInitialValue = 151

        let executingSemaphore = XCTestExpectation()
        let waitingSemaphore = XCTestExpectation()

        let actor = AsyncCache<Int>(command: CompositeCommand(commands: [
            // The first call to retrieve the value throws an error. The expectations are
            // used to interleave additional concurrent calls to `value`. These interleaved
            // calls catch the same error thrown from the first call.
            TrackedCommand(
                value: .failure(expectedError),
                executingSemaphore: executingSemaphore,
                waitingSemaphore: waitingSemaphore
            ),
            // The second call to retrieve the value succeeds and caches the `expectedInitialValue`.
            IncrementingIntegerCommand(initialValue: expectedInitialValue)
        ]))

        // This call ends up throwing the `expectedError`.
        async let throwingInitialValue = actor.value

        // The `async let` allows the test to continue executing.
        //
        // Now let's wait for the `TrackedCommand` to begin execution.
        await fulfillment(of: [executingSemaphore])

        // The `TrackedCommand`, which throws the `expectedError` is now executing and
        // suspended waiting on the test to signal it to continue.
        //
        // Let's now submit a bunch of other calls that will end up throwing the same error.
        async let throwingValueA = actor.value
        async let throwingValueB = actor.value
        async let throwingValueC = actor.value

        // The calls to `value` above are now tracked by the `AsyncCache` and should end up throwing
        // the `expectedError` once the initial call to `value` completes.
        //
        // Now let's signal the `TrackedCommand` to continue and throw the `expectedError`.
        //
        // Note: The three calls to `value` above do not execute the command.
        waitingSemaphore.fulfill()

        // All suspended calls to `value` should throw the `expectedError`.
        do {
            let unexpectedValue = try await throwingInitialValue
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        do {
            let unexpectedValue = try await throwingValueA
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        do {
            let unexpectedValue = try await throwingValueB
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        do {
            let unexpectedValue = try await throwingValueC
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        // Finally, let's verify the cache can now load its value from the `IncrementingIntegerCommand`.
        // This call to value executes the command again because all suspended awaits completed.
        // The `AsyncCache` is now sitting in its "initial" state, which means this call to `value`
        // executes the command again.
        let actualValue = try await actor.value
        XCTAssertEqual(expectedInitialValue, actualValue)
    }
}

// MARK: - Reset

extension AsyncCacheTest {

    func testAwaitResetWhenInitialValueHasNotBeenCached_InitialValueIsReturned() async throws {
        let expectedInitialValue = 98
        let actor = AsyncCache<Int>(command: IncrementingIntegerCommand(initialValue: expectedInitialValue))

        // Calling `reset` here behaves exactly the same as calling `value`.
        let initialValue = try await actor.reset()
        XCTAssertEqual(expectedInitialValue, initialValue)
    }

    func testAwaitResetMultipleTimesSerially_EachResetExecutesTheCommand_UpdatedValuesAreReturned() async throws {
        let expectedInitialValue = 98
        let cache = AsyncCache<Int>(command: IncrementingIntegerCommand(initialValue: expectedInitialValue))

        let initialValue = try await cache.value
        XCTAssertEqual(expectedInitialValue, initialValue)

        let updatedValueA = try await cache.reset()
        let updatedValueB = try await cache.reset()
        let updatedValueC = try await cache.reset()

        XCTAssertEqual(expectedInitialValue + 1, updatedValueA)
        XCTAssertEqual(expectedInitialValue + 2, updatedValueB)
        XCTAssertEqual(expectedInitialValue + 3, updatedValueC)
    }

    func testAwaitResetConcurrentlyUsingAsyncLet_EachResetSuspendsWaitingForTheInitialValue() async throws {
        let expectedInitialValue = 98
        let executingSemaphore = XCTestExpectation()
        let waitingSemaphore = XCTestExpectation()
        let expectedResetValue = 151

        let cache = AsyncCache<Int>(command: CompositeCommand(commands: [
            IncrementingIntegerCommand(initialValue: expectedInitialValue),
            TrackedCommand(
                value: .success(expectedResetValue),
                executingSemaphore: executingSemaphore,
                waitingSemaphore: waitingSemaphore
            ),
            IncrementingIntegerCommand(initialValue: expectedInitialValue + 1),
        ]))

        let initialValue = try await cache.value
        XCTAssertEqual(expectedInitialValue, initialValue)

        async let updatedA = cache.reset()

        await fulfillment(of: [executingSemaphore])

        // The first reset call is executing and waiting for the test to signal the tracked command
        // to continue. We now call reset two more times while the cache is in the "busy" state.
        async let updatedB = cache.reset()
        async let updatedC = cache.reset()

        waitingSemaphore.fulfill()

        let valueA = try await updatedA
        let valueB = try await updatedB
        let valueC = try await updatedC

        XCTAssertEqual(151, valueA)
        XCTAssertEqual(151, valueB)
        XCTAssertEqual(151, valueC)

        // This call to `value` executes the command again because all suspended awaits completed.
        // The value should now be set to the `expectedInitialValue + 1` as set up in the
        // `CompositeCommand` above.
        let updatedValue = try await cache.reset()
        XCTAssertEqual(expectedInitialValue + 1, updatedValue)
    }

    func testAwaitResetWhenCacheIsBusyAwaitingTheCommandToThrowAnError_ResetRequestAwaitsErrorThenExecutesTheCommandWhichReturnsAValue() async throws {
        final class TestError: Error {
        }

        let expectedError = TestError()
        let expectedInitialValue = 98

        let executingSemaphore = XCTestExpectation()
        let waitingSemaphore = XCTestExpectation()

        let cache = AsyncCache<Int>(command: CompositeCommand(commands: [
            TrackedCommand(
                value: .failure(expectedError),
                executingSemaphore: executingSemaphore,
                waitingSemaphore: waitingSemaphore
            ),
            IncrementingIntegerCommand(initialValue: expectedInitialValue)
        ]))

        async let initialValue = cache.value

        await fulfillment(of: [executingSemaphore])

        // The first reset call is executing and waiting for the test to signal the tracked command
        // to continue. We now call reset to enqueue a reset call of the value.
        async let updatedA = cache.reset()

        waitingSemaphore.fulfill()

        do {
            let unexpectedValue = try await initialValue
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        let valueA = try await updatedA

        XCTAssertEqual(expectedInitialValue, valueA)

        let currentValue = try await cache.value
        XCTAssertEqual(expectedInitialValue, currentValue)
    }

    func testResetWhenCacheIsBusyAwaitingTheCommandToReturnTheInitialValue_ResetRequestAwaitsAndReturnsTheInitialValue() async throws {
        final class TestError: Error {
        }

        let expectedError = TestError()
        let expectedInitialValue = 98

        let executingSemaphore = XCTestExpectation()
        let waitingSemaphore = XCTestExpectation()

        let cache = AsyncCache<Int>(command: CompositeCommand(commands: [
            TrackedCommand(
                value: .success(expectedInitialValue),
                executingSemaphore: executingSemaphore,
                waitingSemaphore: waitingSemaphore
            ),
            ThrowErrorCommand(error: expectedError),
            IncrementingIntegerCommand(initialValue: expectedInitialValue + 1)
        ]))

        async let initialValue = cache.value

        await fulfillment(of: [executingSemaphore])

        // The first reset call is executing and waiting for the test to signal the tracked command
        // to continue. We now call reset to enqueue a reset call of the value.
        async let updatedA = cache.reset()

        waitingSemaphore.fulfill()

        let actualInitialValue = try await initialValue
        XCTAssertEqual(expectedInitialValue, actualInitialValue)

        let valueA = try await updatedA
        XCTAssertEqual(expectedInitialValue, valueA)

        do {
            let unexpectedValue = try await cache.reset()
            XCTFail("Expected '\(expectedError)' to be thrown, but received result '\(unexpectedValue)'.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        let currentValue = try await cache.reset()
        XCTAssertEqual(expectedInitialValue + 1, currentValue)
    }

    func testResetThrowsAnErrorWhenThereIsACurrentValue_CurrentValueIsThrownAwayBecauseTheValueIsAssumedToBeStale() async throws {
        final class TestError: Error {
        }

        let expectedInitialValue = 98
        let expectedError = TestError()

        let cache = AsyncCache<Int>(command: CompositeCommand(commands: [
            IncrementingIntegerCommand(initialValue: expectedInitialValue),
            ThrowErrorCommand(error: expectedError),
            IncrementingIntegerCommand(initialValue: expectedInitialValue + 100),
        ]))

        let initialValue = try await cache.value
        XCTAssertEqual(expectedInitialValue, initialValue)

        // Now let's initiate a reset that ends up throwing an error. In this case, the cache
        // throws away the current value because the value is assumed to be stale (hence the
        // reset). The next call to `value` will attempt to retrieve the value again from the
        // command.
        do {
            let unexpectedValue = try await cache.reset()
            XCTFail("Task should have been cancelled, but a value \(unexpectedValue) was returned.")
        } catch let error as TestError {
            XCTAssertIdentical(expectedError, error)
        }

        // The reset successfully canceled. The cache should still return its initial value.
        let currentValue = try await cache.value
        XCTAssertEqual(expectedInitialValue + 100, currentValue)
    }
}

// MARK: - Cancellation

extension AsyncCacheTest {

    func testCancelInitialValue_AwaitingTheValueAgainExecutesTheCommand() async throws {
        let expectedInitialValue = 98

        let executingSemaphore = XCTestExpectation()
        let waitingSemaphore = XCTestExpectation()

        let cache = AsyncCache<Int>(command: CompositeCommand(commands: [
            // The first call to `value` executes this command, which is cancelled.
            // This means the load of the initial value fails, and the cache effectively remains
            // without a value.
            TrackedCommand(
                value: .success(expectedInitialValue),
                executingSemaphore: executingSemaphore,
                waitingSemaphore: waitingSemaphore
            ),
            // The next call to `value` executes this command, which returns a value.
            IncrementingIntegerCommand(initialValue: expectedInitialValue)
        ]))

        //
        // Now let's initiate a call to `value` to attempt to load the initial value.
        // However, the task is cancelled while the command executes. The cancellation ends
        // up throwing a `CancellationError`, which puts the cache back into the "no value"
        // state. This means the next call to `value` attempts to load the initial value again.
        let task = Task {
            return try await cache.value
        }

        await fulfillment(of: [executingSemaphore])

        task.cancel()
        waitingSemaphore.fulfill()

        do {
            let unexpectedValue = try await task.value
            XCTFail("Task should have been cancelled, but a value \(unexpectedValue) was returned.")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }

        // Calling `value` again executes the `IncrementingIntegerCommand` noted above, which
        // returns the expected initial value.
        let initialValue = try await cache.value
        XCTAssertEqual(expectedInitialValue, initialValue)
    }

    func testCancelResetWhenThereIsACurrentValue_CurrentValueRemainsSet() async throws {
        let expectedInitialValue = 98
        let executingSemaphore = XCTestExpectation()
        let waitingSemaphore = XCTestExpectation()

        let cache = AsyncCache<Int>(command: CompositeCommand(commands: [
            IncrementingIntegerCommand(initialValue: expectedInitialValue),
            TrackedCommand(
                value: .success(expectedInitialValue + 100),
                executingSemaphore: executingSemaphore,
                waitingSemaphore: waitingSemaphore
            )
        ]))

        let initialValue = try await cache.value
        XCTAssertEqual(expectedInitialValue, initialValue)

        // Now let's initiate a reset and then cancel the reset while the command is executing.
        // The cancellation ends up throwing a `CancellationError`. The caller of the reset
        // method catches the `CancellationError` and the cache remembers the current value.
        //
        // Basically, cancelling a reset does not lose the current value.
        let task = Task {
            return try await cache.reset()
        }

        await fulfillment(of: [executingSemaphore])

        task.cancel()
        waitingSemaphore.fulfill()

        do {
            let unexpectedValue = try await task.value
            XCTFail("Task should have been cancelled, but a value \(unexpectedValue) was returned.")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }

        // The reset successfully canceled. The cache should still return its initial value.
        let currentValue = try await cache.value
        XCTAssertEqual(expectedInitialValue, currentValue)
    }

    func testCancelUnstructuredTaskAwaitingResultOfValueBeingRetrievedFromAnotherCall() async throws {
        let expectedInitialValue = 98
        let executingSemaphore = XCTestExpectation()
        let waitingSemaphore = XCTestExpectation()

        // This test only expects the command to execute once.
        let cache = AsyncCache<Int>(command: CompositeCommand(commands: [
            TrackedCommand(
                value: .success(expectedInitialValue),
                executingSemaphore: executingSemaphore,
                waitingSemaphore: waitingSemaphore
            )
        ]))

        // First, let's asynchronously load the value.
        async let initialValue = cache.value

        // Now let's wait for the command that loads the initial value to begin execution.
        await fulfillment(of: [executingSemaphore])

        // Next let's initiate a call to `value` from three different unstructured `Task`s.
        let taskA = Task {
            return try await cache.value
        }

        let taskB = Task {
            return try await cache.value
        }

        let taskC = Task {
            return try await cache.value
        }

        // We'll cancel "B", and allow "A" and "C" to finish and return a result.
        taskB.cancel()

        // Let's signal that the test is ready to continue execution and verify the results of
        // each call to `value`.
        waitingSemaphore.fulfill()

        // The initial call to `value` should match the expected result.
        let currentValue = try await initialValue
        XCTAssertEqual(expectedInitialValue, currentValue)

        // The unstructured Task "A" call to `value` should match the expected result.
        let currentValueA = try await taskA.value
        XCTAssertEqual(expectedInitialValue, currentValueA)

        // The unstructured Task "B" call to `value` should have thrown a `CancellationError`
        // because the task was cancelled.
        do {
            let unexpectedValue = try await taskB.value
            XCTFail("Task should have been cancelled, but a value \(unexpectedValue) was returned.")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }

        // The unstructured Task "C" call to `value` should match the expected result.
        let currentValueC = try await taskC.value
        XCTAssertEqual(expectedInitialValue, currentValueC)

        // Finally, calling `value` again should return the cached value with no further
        // calls to the command (as verified by the `CompositeCommand` implementation).
        let cachedValue = try await cache.value
        XCTAssertEqual(expectedInitialValue, cachedValue)
    }
}
