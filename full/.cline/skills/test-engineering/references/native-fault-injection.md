# Native adapter fault injection

Use when the behavior depends on the real crypto/session/transport implementation and ordinary mocks would hide the failure mechanism. Prefer an existing injection seam; introduce test-only interception only when it can falsify a named invariant.

## Boundary and portability

- Inject the smallest failing boundary: backpressure, delayed/duplicate events, overlapping socket-local IDs, or a precise allocation failure after an operation is claimed. Keep the real implementation under test.
- On compatible ELF/linker builds, test-target-only `--wrap` can intercept selected symbols without adding production test branches. Verify the actual symbol, linkage, toolchain support, and whether the call is interceptable before relying on it; inlining or internal binding can bypass a wrapper.
- Preserve the real ABI. A wrapper returning a C++ object needs compatible C++ linkage; declaring a `std::vector` return as `extern "C"` can trigger Clang diagnostics under warnings-as-errors. Explicit assembler symbol labels are a toolchain-specific option, not a portable default.
- Guard platform/ABI-specific instrumentation and also run the portable suite unwrapped against the intended libraries. Use configured compiler/sanitizer gates for the supported toolchains; a successful wrapped build alone does not establish portability.

## Ownership and event invariants

- Once an operation is claimed, every path must either transfer it to an owner that outlives the initiating call or resolve/release the claim. Exercise route/backend exceptions and actual post-claim allocation failure, not just ordinary error returns. Avoid making a global allocator fail indiscriminately when a narrower seam exists.
- Verify termination/cleanup from actual native events, including peers not present in an application-local authorization map. Authorization and native resource lifetime can have different owners.
- For bounded invitation/session admission, verify capacity is reclaimed on termination without evicting replay-protection records prematurely. Name the lifetime and retention invariant rather than copying a specific application's data structures.

Record the injected boundary, why the scenario is reachable, observed ownership/cleanup outcome, and unwrapped/toolchain results. Apply [independent-oracle and negative-control guidance](../SKILL.md#independent-oracles-and-negative-controls) when using mutation evidence.
