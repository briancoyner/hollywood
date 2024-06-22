# Welcome To Hollywood

The **Hollywood** library enables tracking the state of an asynchronous workflow (with optional progress reporting).

There are two core types: ``ContextualActor`` and ``WorkflowAction``.

A ``ContextualActor`` executes a ``WorkflowAction`` and handles transitioning between the following well-known ``ContextualActor/State-swift.enum``s:
- ``ContextualActor/State-swift.enum/ready``
- ``ContextualActor/State-swift.enum/busy(_:_:)`` 
- ``ContextualActor/State-swift.enum/success(_:)``
- ``ContextualActor/State-swift.enum/failure(_:_:)``

The ``ContextualActor/state-swift.property`` property is ``Observation/Observable``.

![GeneralDiagram](GeneralDiagram.png)

A ``WorkflowAction`` is a simple command (think GoF command) implementation that asynchronously executes to produce a value `T`. A good way to think about this protocol is that it forces you to give a discoverable name (via a concrete type) to an asynchronous function. For a large code base, with multiple developers contributing code, this enables development teams to organize business logic into reusable, composable, and testable types.

``WorkflowAction``s are composable. This means it's super easy to stitch together `WorkflowAction`s into a complex asynchronous execution graph. 

To further help with discoverability, testing, and future maintenance, you can leverage the ``CompositeWorkflowAction``.

