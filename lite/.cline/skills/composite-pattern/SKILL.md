---
name: composite-pattern
description: Design, implement, or review Composite structures where leaves and groups share meaningful operations, including UI/document trees, rule groups, scene objects, and hierarchical calculations. Use for recursive ownership, traversal, aggregation, cycle handling, or partial-failure decisions. Skip flat collections, arbitrary graphs, or tree-shaped data that needs only a recursive function.
---

# Composite pattern

Goal: give leaves and groups a shared contract only where callers can meaningfully treat them alike.

## 1. Inspect the actual structure

Respect the requested mode. Inspect node types, callers, mutation/traversal code, serialization, and existing engine/framework hierarchy support. Determine whether the domain is a strict tree, a DAG with shared descendants, or a general graph; do not silently impose tree assumptions.

- Use Composite for meaningful uniform operations across leaves and groups. A recursive function over a typed tree may be simpler than a class hierarchy.
- Keep child management on groups when it has no meaning for leaves. Do not force every leaf to expose throwing/no-op `addChild` methods for interface symmetry.
- Reuse an existing scene/UI/document tree when its ownership and lifecycle fit; avoid a parallel hierarchy that duplicates the source of truth.

## 2. Define structural and behavioral invariants

- Name node identity and the minimum shared operations. Specify which operations apply only to groups or particular leaf capabilities.
- For a tree, enforce one parent, no ancestor/self attachment, and a clear root. For shared nodes, define multiple-parent ownership, traversal visitation, and repeated contribution semantics.
- Define insertion/removal/reparenting invariants, including atomicity: a failed move must not leave a node detached, duplicated, or referenced by conflicting parents.
- Specify child order and traversal order, aggregation rules, empty-group identity, and short-circuit behavior. For permission/rule trees, define allow/deny precedence and empty groups explicitly; a mathematical empty `all` result may be an unsafe authorization default.
- State inherited context rules (transforms, visibility, permissions, units), overrides, and cache invalidation. Do not rely on ambient mutable traversal state leaking between siblings.
- Define behavior for malformed, unknown, cyclic, or excessively deep serialized input. Validate at import and mutation boundaries; do not trust deserialized parent links.

## 3. Assign ownership and traversal limits

- Name the tree/graph mutation owner and whether children are owned or borrowed. Define detach versus destroy, resource cleanup, listener teardown, and lifetime of shared descendants.
- Choose snapshot, version-check, lock, or deferred-mutation semantics when traversal and edits can overlap. Do not mutate a live child list during iteration without a defined protocol.
- Bound depth, total visited nodes, and work per request/frame. Use iterative traversal when stack depth is untrusted; detect cycles according to the actual graph contract.
- Define fail-fast versus accumulated errors, cancellation, and partial effects for group operations. A composite operation does not create a transaction automatically.
- Keep serialization IDs/references and old/new schema behavior explicit when persistence changes; use existing migration guidance rather than silently changing saved documents.

## 4. Trace examples before implementing

Illustrative pricing tree: leaves return costs and groups sum child costs. Decide whether a shared leaf contributes once per edge or once per identity, whether order affects rounding, and what an empty group costs. Shared descendants make this a graph contract, not automatically an ownership tree.

Illustrative document move: check the target is not inside the moving subtree, validate ownership/version, then update parent links under the chosen atomic mutation boundary. Cleanup belongs to destruction, not necessarily a temporary detach.

Counterexample: summing a flat list does not require leaf and group classes. A permission tree should not inherit arithmetic aggregation defaults without an explicit security policy.

## 5. Verify and report

Use the project's checks for leaf/group equivalence on valid operations, empty/deep structures, traversal order, cycle rejection, reparent rollback, shared-node accounting, concurrent mutation, and cleanup as applicable. For persisted trees, check malformed/legacy input. For permission composites, check explicit denial and empty-group behavior.

Report structure and identity, shared versus group-only contract, mutation/lifetime owner, aggregation and traversal semantics, limits/failure behavior, and checks run or planned. Return this structure decision to `design-for-change`; apply the core quality gate.
