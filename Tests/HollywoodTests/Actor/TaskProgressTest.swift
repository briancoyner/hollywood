import Foundation
import XCTest

import Hollywood

final class TaskProgressTest: XCTestCase {
}

extension TaskProgressTest {

    func testDefaultProgressIsInitiallyIndeterminate() async throws {
        let progress = TaskProgress.progress
        XCTAssertEqual(0, progress.totalUnitCount)
        XCTAssertEqual(0, progress.completedUnitCount)
        XCTAssertEqual(true, progress.isIndeterminate)
    }
}

extension TaskProgressTest {

    /// This test is mostly validating generating understanding of how the `TaskLocal` API works.
    func testGeneralTaskProgressUsage() async throws {

        let progressA = Progress(totalUnitCount: 50)
        async let asyncA = TaskProgress.$progress.withValue(progressA) {
            progressA.completedUnitCount = progressA.totalUnitCount
            return "ResultA"
        }

        let progressB = Progress(totalUnitCount: 100)
        async let asyncB = TaskProgress.$progress.withValue(progressB) {
            progressB.completedUnitCount = progressB.totalUnitCount
            return "ResultB"
        }

        let progressC = Progress(totalUnitCount: 150)
        async let asyncC = TaskProgress.$progress.withValue(progressC) {
            progressC.completedUnitCount = progressC.totalUnitCount
            return "ResultC"
        }

        let resultA = await asyncA
        let resultB = await asyncB
        let resultC = await asyncC

        XCTAssertEqual("ResultA", resultA)
        XCTAssertEqual("ResultB", resultB)
        XCTAssertEqual("ResultC", resultC)

        XCTAssertEqual(50, progressA.completedUnitCount)
        XCTAssertEqual(100, progressB.completedUnitCount)
        XCTAssertEqual(150, progressC.completedUnitCount)
    }
}
