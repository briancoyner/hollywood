import Foundation
import Testing

import Hollywood

struct TaskProgressTest {
}

extension TaskProgressTest {

    /// This test is mostly validating generating understanding of how the `TaskLocal` API works.
    @Test
    func generalTaskProgressUsage() async throws {

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

        #expect(resultA == "ResultA")
        #expect(resultB == "ResultB")
        #expect(resultC == "ResultC")

        #expect(progressA.completedUnitCount == 50)
        #expect(progressB.completedUnitCount == 100)
        #expect(progressC.completedUnitCount == 150)
    }
}
