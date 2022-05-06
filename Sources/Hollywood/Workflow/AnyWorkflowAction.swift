///- Note: This "any" type erasure should be able to be dropped in favor of  `[any WorkflowAction<T>]`.
///
/// - SeeAlso: https://github.com/apple/swift-evolution/blob/main/proposals/0353-constrained-existential-types.md
struct AnyWorkflowAction<T: Sendable>: WorkflowAction {

    private let proxy: @Sendable () async throws -> T
    private let _description: @Sendable () -> String

    init<C: WorkflowAction>(_ command: C) where C.T == T {
        self.proxy = {
            try await command.execute()
        }

        self._description = {
            return String(describing: command)
        }
    }
}

extension AnyWorkflowAction {

    func execute() async throws -> T {
        return try await proxy()
    }
}

extension AnyWorkflowAction: CustomStringConvertible {
    var description: String {
        return _description()
    }
}
