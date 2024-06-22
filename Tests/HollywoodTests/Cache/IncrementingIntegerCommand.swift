import Hollywood

actor IncrementingIntegerCommand: AsyncCacheCommand {

    private(set) var value: Int

    init(initialValue: Int) {
        self.value = initialValue
    }
}

extension IncrementingIntegerCommand {

    func execute() async throws -> Int {
        try Task.checkCancellation()
        defer { value += 1 }
        return value
    }
}
