import Hollywood

struct ThrowErrorCommand: AsyncCacheCommand {

    private let error: any Error

    init(error: any Error) {
        self.error = error
    }
}

extension ThrowErrorCommand {

    func execute() async throws -> Int {
        throw error
    }
}
