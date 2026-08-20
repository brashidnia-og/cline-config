---
paths:
  - "**/*.kt"
  - "**/*.kts"
  - "**/*.java"
---

# Kotlin and JVM language rules

Follow repository conventions before generic style advice. Keep domain behavior explicit and types strong.

## Kotlin
- Prefer clear explicit code over dense scope-function chains. Use `let/run/apply/also/takeIf` only when they improve ownership/nullability/configuration clarity.
- Use nullability and sealed types to encode valid states rather than defensive stringly-typed logic.
- Prefer domain-specific value types when they prevent meaningful unit/identity mistakes; do not wrap every primitive ceremonially.
- Avoid unnecessary `!!`; establish why a value is non-null or represent the state correctly.
- Preserve structured concurrency. Understand coroutine parent/child lifecycle, cancellation, exception propagation, and dispatcher/context semantics.
- Use an I/O dispatcher for blocking I/O when appropriate; do not switch dispatchers around non-blocking or framework-managed transaction contexts without verifying the framework contract.
- Mapping/parser extensions should be narrowly scoped and explicit about null/missing/legacy/unknown values.

## Java interoperability
When Java is involved:
- respect nullability/platform types across the boundary,
- avoid exposing Kotlin-only semantics that Java callers cannot safely consume without documentation,
- preserve checked/runtime exception contracts where callers depend on them,
- verify generated JVM signatures for public APIs when compatibility matters.

## JVM change review
For non-trivial changes consider:
- nullability and default values,
- serialization/deserialization compatibility,
- coroutine/thread safety,
- transaction context and lazy loading,
- equals/hashCode/data-class changes,
- numeric precision and time-zone behavior,
- public binary/source compatibility where relevant.

Use the repository's Gradle wrapper and configured toolchain as source of truth rather than assuming global Kotlin/Java versions.
