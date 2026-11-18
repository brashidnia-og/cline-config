# Network and codec invariants

## Input admission and bounded work

When making input acceptance transactional, keep logical/per-seat token reservation separate from ingress parse-work limits. A malformed packet may correctly leave gameplay tokens unchanged while still consuming host CPU. Preserve a bounded allowance per authenticated sender before expensive telemetry decoding or protocol JSON parsing, alongside the transport's size/rate limits. Verify healthy-peer isolation and the existing supported per-seat burst; do not silently replace one bound with the other.

## Replicated timers and standalone codecs

- Keep replicated timers within the **wire contract's allowed range** at the correct ownership boundary. An expired negative ability timer may be a meaningful **internal** sentinel; do not clamp or rewrite that local state without checking its semantics. If the authoritative replicated state is required to be valid at every mutation, normalize there; if internal and wire representations differ, convert explicitly during snapshot projection/serialization. For example, a negative internal timer can invalidate an otherwise valid snapshot carrying acknowledgements when copied directly into a nonnegative wire field. Exercise real input/world updates through expiry, snapshot validation, and packet encoding over post-expiry frames, including any intentional sentinel transitions.
- Keep pure wire codecs independent of gameplay Node scripts and autoload availability. Put genuinely shared range/timer constants in a small pure leaf, preserving gameplay aliases where compatibility requires them. Test codec use in a minimal fixture without gameplay autoloads; a normal game launch can hide dependency-order failures.
- When enforcing exact dictionary schemas, check the installed GDScript behavior for both `String` and `StringName` keys. Dot assignment can produce `StringName` keys. Accept the intended string-like representations explicitly and reject non-string keys without relying on typed-loop coercion.

Use the existing native/transport integration tests where those mechanisms matter. When `test-engineering` is installed, its `references/native-fault-injection.md` covers safe fault injection and ownership checks; otherwise apply those checks directly using the project's established test seams.
