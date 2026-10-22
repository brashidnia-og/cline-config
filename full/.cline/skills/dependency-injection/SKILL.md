---
name: dependency-injection
description: Design, implement, or review dependency injection when collaborator boundaries, application wiring, instance lifetimes, resource cleanup, or testability need a real decision. Use for captive scoped dependencies in singletons, circular dependencies, hidden service locators, ambiguous registrations, async initialization, and container wiring bugs. Cover IoC and dependency inversion without requiring a container or interfaces everywhere; skip trivial constructor arguments and pure helpers with no wiring problem.
---

# Dependency injection

Goal: make required collaborators explicit and give every instance, scope, and resource a deliberate owner without adding unnecessary abstraction.

## 1. Inspect the actual dependency graph

Respect the requested explanation, plan, review, or implementation mode. Inspect constructors/functions, callers, bootstrap/registration code, framework/container version, scopes, teardown, and existing tests. Trace both direct and transitive dependencies, including factories, closures, background tasks, and ambient request context. Do not assume a registration name proves the actual lifetime.

Keep the related concepts distinct:
- **Dependency injection (DI):** a caller or wiring boundary supplies collaborators rather than the component constructing or locating them itself.
- **Inversion of Control (IoC):** the broader transfer of construction/execution control to an external owner; framework callbacks can be IoC without constructor injection.
- **Dependency Inversion Principle (DIP):** high-level policy and low-level details depend on suitable abstractions. DI alone does not establish DIP; injecting a concrete collaborator can still be the simplest correct choice.
- **Composition root:** the application's existing wiring/lifetime boundary. Factory/Builder/composition-root selection remains owned by [construction guidance](../design-for-change/references/construction.md); reuse that decision rather than creating a second bootstrap design.
- **DI container:** optional automation for resolution and lifetimes, not a requirement for DI or a substitute for a dependency contract.

When called by `design-for-change`, resolve the injection/lifetime concern and return there. Keep provider translation with `adapter-pattern` and interchangeable behavior selection with `polymorphism-and-strategy` if those distinct decisions are unresolved.

## 2. Choose explicit injection boundaries

- Prefer constructor parameters for required, stable collaborators so the object is valid when exposed. Function parameters or closures can serve the same purpose in functional code; inspect what closures retain.
- Pass per-operation values/context explicitly at execution when appropriate. Request principal, tenant, deadline, and transaction/session context must not accidentally become permanent service state. Injecting an identity does not perform authorization.
- Use method injection for a collaborator genuinely supplied for that operation; property/setter injection needs a verified framework/lifecycle reason and an explicit valid-initialization protocol. Do not leave required dependencies nullable merely to satisfy wiring.
- Prefer a narrow callable, existing concrete type, protocol, or interface according to repository conventions. Introduce an abstraction for a real policy boundary/capability or substitution need, not automatically for every class or constructor parameter.
- Avoid passing a container or broad service bag into business code to resolve dependencies on demand. Resolve at the composition/scope boundary; a narrow typed factory can express justified deferred creation without exposing the whole container.
- Distinguish optional behavior from a required dependency missing because of misconfiguration. Reject missing/ambiguous required registrations visibly; do not silently instantiate a fallback that changes policy.

## 3. Prove lifetime and resource ownership

Make a small graph/table: component → collaborators → instance scope → owned/borrowed resources → cleanup owner. State the actual scope (application, request, job, entity/session, operation, pooled, or transient), not just a framework label.

- A long-lived component must not retain a shorter-lived instance past its scope. A singleton capturing a request session, tenant value, scoped service through a closure, or factory result creates a captive dependency even if the container accepts it.
- For background jobs, acquire a job/operation scope and its handler inside execution, finish owned work or cancel and await its termination before closing the scope, then release owned resources. A request scope must not escape through a queued callback/task. A factory only fixes capture when it creates the right scope and the result does not outlive it.
- Do not hide lifetime mismatch with `Lazy`, a global provider, ambient mutable context, or nested root containers. Verify framework scope propagation, pooling/reset semantics, and cancellation where those facilities are used.
- Shared instances require concurrency-safe state. Keep per-call mutable fields isolated; thread/task safety and correct tenant isolation do not follow from a singleton registration.
- Identify who disposes owned clients, sessions, subscriptions, and tasks; wrappers borrowing them must not double-close them. Reuse the construction owner's cleanup policy, including partial acquisition failure and dependency-safe shutdown.
- For async startup/teardown, avoid exposing partially initialized objects; propagate cancellation and preserve the primary failure if cleanup also fails. Inspect whether the container owns externally supplied instances before relying on automatic disposal.

## 4. Challenge cycles and container assumptions

- Trace a circular graph to its responsibilities and actual calls. Prefer correcting ownership, separating a cohesive responsibility, or passing a narrower capability. Lazy lookup can defer a cycle without resolving its temporal coupling.
- Use an event boundary only when notification semantics fit; do not replace a mandatory ordered call with asynchronous events merely to make the container build.
- Reuse the repository's manual wiring or existing container. Add no container dependency solely for testing, and do not build a new root provider per resolution.
- For container-specific APIs, inspect the installed version and verified documentation for registration precedence, duplicate/keyed registrations, scope validation, factory behavior, and disposal. Do not invent configuration methods or claim equivalent lifetimes across frameworks.
- Startup graph validation may instantiate resources or contact services. Use the existing safe validation mechanism and disposable test wiring; a successful graph build alone does not establish runtime scope isolation or cleanup.

## 5. Trace examples and verify behavior

Illustrative lifetime bug: an application-wide worker stores a request-created database session in its constructor. Changing the parameter to a factory that returns the same captured session does not fix it. Instead, the worker obtains a fresh operation scope for each job; that scope creates the handler/session, owns their completion and cleanup, and never escapes into the next job. The concrete mechanism depends on the inspected framework.

Illustrative ordinary DI: an order service receives a mail-sending callable from bootstrap. A recording fake can verify the intended notification outcome in a test. This alone needs no DI container, new interface hierarchy, command bus, or global Singleton.

Use existing checks for actual caller behavior with injected collaborators, missing/ambiguous registrations, scope isolation across requests/jobs, concurrent tenant separation, captured closures, cycles, initialization failure/cancellation, and owned-versus-borrowed disposal as applicable. Verify real bootstrap/container wiring in a disposable integration fixture when it matters; testing only a mocked resolver does not validate the graph. Do not replace a real database/transaction test with a fake merely because DI makes that easy.

## Result / handoff

Report why injection analysis is needed, the chosen boundaries and graph, scopes/state/resource owners, any cycle or lifetime corrections, container-specific evidence/unknowns, and meaningful checks run or planned. Keep construction decisions with their existing owner and apply the core quality gate.
