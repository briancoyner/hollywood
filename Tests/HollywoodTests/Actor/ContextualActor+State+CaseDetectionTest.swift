import Testing
import Foundation

import Hollywood

struct ContextualActor_State_CaseDetectionTest {

    let ready: ContextualActor<String>.State = .ready
    let busyNoValue: ContextualActor<String>.State = .busy(nil, Progress())
    let busyWithValue: ContextualActor<String>.State = .busy("Value", Progress())
    let success: ContextualActor<String>.State = .success("Value")
    let failureNoValue: ContextualActor<String>.State = .failure(MockError(), nil)
    let failureWithValue: ContextualActor<String>.State = .failure(MockError(), "Value")
}

extension ContextualActor_State_CaseDetectionTest {

    @Test
    func isReady_MatchesExpectedState() {
        #expect(ready.isReady == true)
        #expect(busyNoValue.isReady == false)
        #expect(busyWithValue.isReady == false)
        #expect(success.isReady == false)
        #expect(failureNoValue.isReady == false)
        #expect(failureWithValue.isReady == false)
    }

    @Test
    func isBusy_MatchesExpectedState() {
        #expect(ready.isBusy == false)
        #expect(busyNoValue.isBusy)
        #expect(busyWithValue.isBusy)
        #expect(success.isBusy == false)
        #expect(failureNoValue.isBusy == false)
        #expect(failureWithValue.isBusy == false)
    }

    @Test
    func value_MatchesExpectedState() {
        #expect(ready.value == nil)
        #expect(busyNoValue.value == nil)
        #expect(busyWithValue.value == "Value")
        #expect(success.value == "Value")
        #expect(failureNoValue.value == nil)
        #expect(failureWithValue.value == "Value")
    }

    @Test
    func error_MatchesExpectedState() {
        #expect(ready.error == nil)
        #expect(busyNoValue.error == nil)
        #expect(busyWithValue.error == nil)
        #expect(success.error == nil)
        #expect(failureNoValue.error as? NSError == MockError() as NSError)
        #expect(failureWithValue.error as? NSError == MockError() as NSError)
    }
}
