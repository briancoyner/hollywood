import Hollywood

actor CompositeCommand<T: Sendable>: AsyncCacheCommand {

    private var commands: [any AsyncCacheCommand<T>]

    init(commands: [any AsyncCacheCommand<T>]) {
        self.commands = commands.reversed()
    }
}

extension CompositeCommand {

    func execute() async throws -> T {
        guard let command = commands.popLast() else {
            throw NoCommandToExecuteError()
        }

        return try await command.execute()
    }
}

extension CompositeCommand {

    struct NoCommandToExecuteError: Error {
    }
}
