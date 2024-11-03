import XCTest  // XCTWaiter + XCTestExpectation
import Testing

import Hollywood

struct TrackedCommand: AsyncCacheCommand {

    private let value: Result<Int, any Error>

    let executingSemaphore: XCTestExpectation
    let waitingSemaphore: XCTestExpectation

    init(
        value: Result<Int, any Error>,
        executingSemaphore: XCTestExpectation,
        waitingSemaphore: XCTestExpectation
    ) {
        self.value = value
        self.executingSemaphore = executingSemaphore
        self.waitingSemaphore = waitingSemaphore
    }
}

extension TrackedCommand {

    func execute() async throws -> Int {
        executingSemaphore.fulfill()
        let result = await XCTWaiter().fulfillment(of: [waitingSemaphore], timeout: 3)
        #expect(result == .completed)

        try Task.checkCancellation()

        switch value {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
