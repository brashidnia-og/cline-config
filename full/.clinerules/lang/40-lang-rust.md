---
paths:
  - "**/*.rs"
---

# Rust language rules

Follow repository conventions and use the type system to encode invariants without gratuitous complexity.

## Errors and panics
- Avoid `unwrap()`/`expect()` in production paths when failure is realistically possible; propagate or model errors with useful context (`thiserror`/`anyhow` as the repo uses).
- Do not convert recoverable errors into panics for convenience.
- Prefer `?` with context mapping at API boundaries; preserve error chains callers depend on.

## Ownership and types
- Minimize unnecessary cloning, but prefer a clear correct ownership model over lifetime gymnastics that obscure behavior.
- Use newtypes when they prevent real unit/identity/domain mistakes, not mechanically for every primitive.
- Prefer borrowing/`AsRef`/`Cow` when it matches existing patterns and clarifies ownership.

## Unsafe
Treat `unsafe` as an explicit proof obligation: document invariants, bounds, aliasing/lifetime assumptions, and why safe alternatives are insufficient. Keep unsafe blocks small and reviewable.

## Concurrency and async
- Check `Send`/`Sync`, lock ordering, blocking-in-async behavior, task cancellation, channel closure, and resource cleanup.
- Do not hold locks across `.await` unless the repo’s pattern requires it and deadlock risk is understood.
- Prefer structured concurrency / join patterns already used in the crate.

## Data and compatibility
- Consider integer overflow, precision, ordering, time, serialization (`serde`) and feature-flag behavior.
- Preserve public API and serialized data compatibility when required.
- Be careful with `#[derive(Clone, Copy)]` on types that should not be trivially copied.

## Change review
Before finalizing, inspect panic paths, error conversion/context, concurrency assumptions, `unsafe` boundaries, and platform/feature-specific code touched by the change. Use the repository’s Cargo toolchain and `rust-toolchain` / `.cargo` config as source of truth.
