# Design examples (illustrative)

These are explicitly illustrative patterns, not APIs from a real project. Each states what varies, what was chosen, what was rejected, and the resulting contract.

## 1. Provider endpoints — data, not classes

What varies: same algorithm (connect, send, retry with backoff, disconnect), different endpoints, timeouts, and limits.

- **Chosen:** one `providers` table (endpoint, timeout, max retries) read by a single connection implementation.
- **Rejected:** `AlphaProvider`, `BetaProvider`, … — five forwarding classes duplicating the same algorithm; every fix is made five times.
- **Contract:** `connect(provider) -> session`; configuration is data, the algorithm is code; unknown/invalid entries fail at load with a named error.

## 2. Transports — strategy behind a common contract

What varies: different algorithms (in-process, socket, message queue) behind one `send / recv / close` contract.

- **Chosen:** a small interface with two or more real implementations; a registry picks by name at construction; lifecycle state (open/closed, in-flight messages) belongs to each transport.
- **Rejected:** one class with `if transport == …` branches in every method — branches multiply with each addition and each implementation is untestable in isolation.
- **Contract:** shared `send / recv / close` semantics including cancellation and failure; per-transport failure modes are documented and each is tested, including one shared-behavior test per implementation.

## 3. Godot weapon variants — data + composition, no god hierarchy

What varies: weapons/abilities share a tick contract but differ in damage profile, cooldowns, projectile behavior, and effects.

- **Chosen:** weapon *data* in a Resource (stats, timings) plus a few behavior scripts composed onto the weapon node; enemy behavior uses an exhaustive `match` over a closed state enum.
- **Rejected:** a `WeaponBase` hierarchy with one subclass per weapon — each new weapon is a new class and shared behavior drifts between subclasses.
- **Contract:** data defines *what* (numbers, timings), scripts define *how*; state transitions are the closed enum; adding a variant means new data or a small script, not a new class.
- **Evaluation:** run the same tick/cooldown assertions for each weapon variant, then cover one variant-specific failure (for example invalid projectile configuration or collision cleanup). A sixth weapon should add data or one focused behavior without changing unrelated owners.

## 4. Rust connection state — exhaustive match, not a trait

What varies: a closed state set (connecting, open, closing, closed) with different allowed transitions per state.

- **Chosen:** an enum plus an exhaustive `match` in the transition function — the compiler forces every transition to be handled.
- **Rejected:** a trait with one implementation per state — dynamic dispatch obscures the closed, auditable state space and allows silent omissions.
- **Contract:** every transition is explicit in one `match`; adding a state is a closed-set change the compiler surfaces at every use site.

## 5. React feature — composition, not imperative conversion (counterexample)

What varies: a list feature whose filtering, sorting, and pagination can each change independently.

- **Chosen:** plain components + hooks (`useFilteredItems(items, filter)`, …) composed in the page component; data ownership explicit (URL for filters, component state for selection, server cache for data).
- **Rejected:** converting the composition into an imperative class hierarchy or a `ListManager` interface — it fights React's model, duplicates state, and adds a layer that owns nothing.
- **Contract:** each concern has one owner; derived data is computed, not synchronized; adding a variation touches one hook or component.
