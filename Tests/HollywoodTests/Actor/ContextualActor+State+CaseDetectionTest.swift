import XCTest

import Hollywood

final class ContextualActor_State_CaseDetectionTest: XCTestCase {

    let ready: ContextualActor<String>.State = .ready
    let busyNoValue: ContextualActor<String>.State = .busy(nil, Progress())
    let busyWithValue: ContextualActor<String>.State = .busy("Value", Progress())
    let success: ContextualActor<String>.State = .success("Value")
    let failureNoValue: ContextualActor<String>.State = .failure(MockError(), nil)
    let failureWithValue: ContextualActor<String>.State = .failure(MockError(), "Value")
}

extension ContextualActor_State_CaseDetectionTest {

    func testIsReady_MatchesExpectedState() {
        XCTAssertEqual(true, ready.isReady)
        XCTAssertEqual(false, busyNoValue.isReady)
        XCTAssertEqual(false, busyWithValue.isReady)
        XCTAssertEqual(false, success.isReady)
        XCTAssertEqual(false, failureNoValue.isReady)
        XCTAssertEqual(false, failureWithValue.isReady)
    }
    func testIsBusy_MatchesExpectedState() {
        XCTAssertEqual(false, ready.isBusy)
        XCTAssertEqual(true, busyNoValue.isBusy)
        XCTAssertEqual(true, busyWithValue.isBusy)
        XCTAssertEqual(false, success.isBusy)
        XCTAssertEqual(false, failureNoValue.isBusy)
        XCTAssertEqual(false, failureWithValue.isBusy)
    }

    func testValue_MatchesExpectedState() {
        XCTAssertEqual(nil, ready.value)
        XCTAssertEqual(nil, busyNoValue.value)
        XCTAssertEqual("Value", busyWithValue.value)
        XCTAssertEqual("Value", success.value)
        XCTAssertEqual(nil, failureNoValue.value)
        XCTAssertEqual("Value", failureWithValue.value)
    }

    func testError_MatchesExpectedState() {
        XCTAssertEqual(nil, ready.error as? NSError)
        XCTAssertEqual(nil, busyNoValue.error as? NSError)
        XCTAssertEqual(nil, busyWithValue.error as? NSError)
        XCTAssertEqual(nil, success.error as? NSError)
        XCTAssertEqual(MockError() as NSError, failureNoValue.error as? NSError)
        XCTAssertEqual(MockError() as NSError, failureWithValue.error as? NSError)
    }
}
