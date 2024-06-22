import XCTest

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
        await XCTWaiter().fulfillment(of: [waitingSemaphore])

        try Task.checkCancellation()

        switch value {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
