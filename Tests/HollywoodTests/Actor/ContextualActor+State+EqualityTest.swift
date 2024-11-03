import Testing

import Hollywood

struct ContextualActor_State_EqualityTest {

    enum Failure: Error {
        case one
        case two
        case three
    }
}

extension ContextualActor_State_EqualityTest {

    @Test
    func allEqualStatesMatchAsExpected() {
        let all: [ContextualActor<String>.State] = [
            .ready,
            .busy(nil, .indeterminate),
            .busy("", .indeterminate),
            .busy("Bar", .indeterminate),
            .success(""),
            .success("Foo"),
            .failure(Failure.one, nil),
            .failure(Failure.two, ""),
            .failure(Failure.three, "Foo")
        ]

        // All reference types so creating another variable here "copies" the value.
        let allCopy = all
        #expect(all == allCopy)
    }

    /// Test each individual possible "standard" state is not equal to the other.
    @Test
    func roundRobinReturnsUnequal() {
        let ready: ContextualActor<String>.State = .ready
        let busyNoValue: ContextualActor<String>.State = .busy(nil, .indeterminate)
        let busyWithValue: ContextualActor<String>.State = .busy("Foo", .indeterminate)
        let success: ContextualActor<String>.State = .success("Foo")
        let failureNoValue: ContextualActor<String>.State = .failure(Failure.one, nil)
        let failureWithValue: ContextualActor<String>.State = .failure(Failure.one, "Foo")

        #expect(ready != busyNoValue)
        #expect(ready != busyWithValue)
        #expect(ready != success)
        #expect(ready != failureNoValue)
        #expect(ready != failureWithValue)
        #expect(busyNoValue != busyWithValue)
        #expect(busyNoValue != success)
        #expect(busyNoValue != failureNoValue)
        #expect(busyNoValue != failureWithValue)
        #expect(busyWithValue != success)
        #expect(busyWithValue != failureNoValue)
        #expect(busyWithValue != failureWithValue)
        #expect(success != failureNoValue)
        #expect(success != failureWithValue)
        #expect(failureNoValue != failureWithValue)
    }

    @Test
    func busyStates_WithDifferentValues_ReturnsUnequal() {
        let busyNoValue: ContextualActor<String>.State = .busy(nil, .indeterminate)
        let busyWithValue: ContextualActor<String>.State = .busy("Foo", .indeterminate)
        let busyWithOtherValue: ContextualActor<String>.State = .busy("", .indeterminate)

        #expect(busyNoValue != busyWithValue)
        #expect(busyNoValue != busyWithOtherValue)
        #expect(busyWithValue != busyWithOtherValue)

        #expect(busyNoValue == busyNoValue)
        #expect(busyWithValue == busyWithValue)
        #expect(busyWithOtherValue == busyWithOtherValue)
    }

    @Test
    func successStates_WithDifferentValues_ReturnsUnequal() {
        let successEmptyValue: ContextualActor<String>.State = .success("")
        let successWithValue: ContextualActor<String>.State = .success("Foo")
        let successWithOtherValue: ContextualActor<String>.State = .success("Bar")

        #expect(successEmptyValue != successWithValue)
        #expect(successEmptyValue != successWithOtherValue)
        #expect(successWithValue != successWithOtherValue)

        #expect(successEmptyValue == successEmptyValue)
        #expect(successWithValue == successWithValue)
        #expect(successWithOtherValue == successWithOtherValue)
    }

    @Test
    func failureStates_WithDifferentValues_ReturnsUnequal() {
        let failureNoValue: ContextualActor<String>.State = .failure(Failure.one, nil)
        let failureWithValue: ContextualActor<String>.State = .failure(Failure.one, "Foo")
        let failureWithOtherValue: ContextualActor<String>.State = .failure(Failure.one, "")

        #expect(failureNoValue != failureWithValue)
        #expect(failureNoValue != failureWithOtherValue)
        #expect(failureWithValue != failureWithOtherValue)

        #expect(failureNoValue == failureNoValue)
        #expect(failureWithValue == failureWithValue)
        #expect(failureWithOtherValue == failureWithOtherValue)
    }

    @Test
    func failureStates_WithDifferentErrors_ReturnsUnequal() {
        let failureOne: ContextualActor<String>.State = .failure(Failure.one, "Foo")
        let failureTwo: ContextualActor<String>.State = .failure(Failure.two, "Foo")
        let failureTest: ContextualActor<String>.State = .failure(Failure.three, "Foo")

        #expect(failureOne != failureTwo)
        #expect(failureOne != failureTest)
        #expect(failureTwo != failureTest)

        #expect(failureOne == failureOne)
        #expect(failureTwo == failureTwo)
        #expect(failureTest == failureTest)
    }
}
