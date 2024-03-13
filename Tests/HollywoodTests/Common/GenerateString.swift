import Foundation

import Hollywood

struct GenerateString: CompositeWorkflowAction {

    func execute() async throws -> String {
        TaskProgress.progress.totalUnitCount = 100

        let numberString = try await execute(GenerateNumberString(iterations: 5, pendingUnitCount: 100))

        return numberString
    }
}

struct GenerateNumberString: ProgressReportingWorkflowAction {
    typealias T = String

    let iterations: Int
    let pendingUnitCount: Int64

    func execute(withProgress progress: Progress) async throws -> String {
        progress.totalUnitCount = Int64(iterations)

        var string = ""
        for index in 0..<iterations {
            string += "\(index),"
            progress.completedUnitCount = Int64(index + 1)
        }

        return string
    }
}
