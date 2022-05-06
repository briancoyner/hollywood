import Hollywood

struct PoisonPillWorkflowAction<T: Sendable>: WorkflowAction {

    let poisonPill: T
}

extension PoisonPillWorkflowAction {

    func execute() async -> T {
        return poisonPill
    }
}
