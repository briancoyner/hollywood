import SwiftUI

import Hollywood

public struct ContextualActorView<T, Content>: View where Content: View {

    @ObservedObject
    var contextualActor: ContextualActor<T>

    @ViewBuilder
    private let content: (ContextualActor<T>.State) -> Content

    public init(
        contextualActor: ContextualActor<T>,
        @ViewBuilder content: @escaping (ContextualActor<T>.State) -> Content
    ) {

        self.contextualActor = contextualActor
        self.content = content
    }
}

extension ContextualActorView {

    public var body: some View {
        content(contextualActor.state)
    }
}
