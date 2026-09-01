---
name: smart-contract-security-audit
description: Security audit for CosmWasm smart contracts on Provenance and Cosmos chains — execute auth, cw20 hooks, migrate/reply/submessage safety, marker/metadata semantics, provwasm v2 Stargate dispatch, and Rust tooling. Use with security-audit-core for WASM contracts. Not for EVM/Solidity (Slither/Mythril/Foundry are EVM-only) or backend APIs (backend-security-audit).
---

# Smart contract security audit

Load `security-audit-core` first.

**No CosmWasm static analyzer exists.** Slither, Mythril, and Foundry are EVM-only. This audit is checklist + call-graph tracing + toolchain validation.

## 1. CosmWasm taxonomy

### Authorization
- No implicit authorization — every `execute` match arm needs an explicit predicate.
- **Trail of Bits / Provenance (Aug 2026):** an auth predicate must never be satisfiable from the attacker's default state (e.g. "sender is contract" when attacker can deploy a contract).
- `migrate`: require `cw2` version gating; old state must not deserialize into incompatible layouts.

### Submessages and replies
- `reply_id` collisions across code paths.
- `SubMsgResult::Err` swallowing — funds/state divergence.
- Reply-based reentrancy and ordering assumptions.
- IBC entrypoints (`ibc_packet_receive`, etc.) if present — same auth and state discipline.

### CW20 receiver hooks
- `info.sender` is the **token contract**; `wrapper.sender` is the original user (attacker-controlled in hook context).
- When token address is user-supplied, verify balance delta against expected contract.
- `SendFrom` credits the **spender** — audit allowance semantics.

### Funds and denoms
- Use `cw-utils` (`must_pay`, `one_coin`, `nonpayable`) — do not hand-roll `info.funds` checks.
- Denom confusion across chains/markers; decimal normalization.
- `overflow-checks = true` in release profile; multiply before divide; round in favor of protocol; zero-divisor guards.

### Storage and types
- Unbounded `range` / loops — permanent freeze / block gas exhaustion.
- Storage namespace collisions; mutations not persisted (`save` forgotten).
- `Addr` not validated on deserialization — typos become black holes.
- Panics on withdrawal paths — liveness failure.
- Non-determinism (floating point, system time without bounds, external RNG).

### Oracles and swaps
- TWAP manipulation, stale prices, missing slippage/deadline on swaps.

## 2. Provenance-specific deltas

- **Governance-gated code upload** changes severity: permissionless-upload classes de-risked; slow governance patch latency makes missing **pause/emergency** switch a finding. Per-instance `wasmd` admin can bypass governance — note deployment model.
- **Marker module:** access grants and restricted-coin transfer semantics. `BankMsg::Send` of a restricted coin to an address lacking required attributes **reverts the whole tx** — refund/payout paths are liveness bugs. Forced transfers cannot pull from contract accounts.
- **Metadata:** value ownership bank-tracked as `nft/<scope_id>`; distinguish `Ownership` vs `ValueOwnership` queries.
- **Attribute-gated access:** who can write the attribute (under `Restricted` parent or not); TOCTOU on revocation.
- **Quarantine / sanction / hold** break push payouts — prefer pull patterns.
- **nhash:** 9 decimals.
- **msgfees:** custom-fee recipient and bounds.

## 3. provwasm v2

- v2.x removed `ProvenanceMsg` / `ProvenanceQuery` / `CosmosMsg::Custom` — match `type_url: "/provenance.<module>.v1.Msg*"` and `provwasm_std::types::provenance::*`.
- Stargate / `Any` messages are **not** handled by `cw-multi-test` — unit tests passing prove nothing about marker behavior. Use `provwasm-mocks` and testnet validation.
- Stargate query allowlist — unlisted queries fail at runtime.
- **Verify before asserting:** exact `cosmwasm-check` capability flag string for provwasm — confirm against current provwasm docs.

## 4. Tooling (read-only)

```bash
command -v cargo >/dev/null || exit 0
cargo clippy --all-targets -- \
  -D warnings \
  -D clippy::arithmetic_side_effects \
  -D clippy::indexing_slicing \
  -D clippy::unwrap_used \
  2>&1 | tee .audit/scans/clippy.txt

command -v cargo-audit >/dev/null && cargo audit --deny warnings -q 2>&1 | tee .audit/scans/cargo-audit.txt
command -v cargo-deny >/dev/null && cargo deny check 2>&1 | tee .audit/scans/cargo-deny.txt
command -v osv-scanner >/dev/null && osv-scanner scan -r . -f json -o .audit/scans/osv-rust.json
```

| Tool | Role |
|------|------|
| `cargo clippy` | Hardened lint set above |
| `cargo audit` / `cargo deny` | RustSec / license / bans |
| `osv-scanner` | Transitive CVEs |
| `cosmwasm-check` | WASM artifact validator (not a bug finder); provwasm may need capability flag — verify flag string |
| `cargo llvm-cov` | Uncovered `reply` / error branches |
| `cargo fuzz` | Fuzz `from_json::<ExecuteMsg>` and pure math |
| `cargo schema` | Diff JSON schema on migrate — breaking field changes |
| Kani | Optional on extracted pure functions |
| Reproducible build | Compare local WASM checksum vs on-chain code hash (Provenance proposals carry WASM) |

```bash
command -v cosmwasm-check >/dev/null && cosmwasm-check artifacts/*.wasm 2>&1 | tee .audit/scans/cosmwasm-check.txt
```

## 5. Manual trace procedure

1. List all `ExecuteMsg` variants and entrypoints (`instantiate`, `execute`, `migrate`, `reply`, IBC).
2. For each variant: who can call, what state changes, what external messages sent.
3. Follow `SubMsg` / `reply` chains to completion.
4. Map fund flows in/out of contract and escrow patterns.
5. Cross-check schema vs stored state version in `migrate`.

## 6. Recent vulnerability classes

_Dated notes — verify before asserting._

- **2026-08 (Trail of Bits / Provenance):** auth predicates satisfiable from attacker default state — review every `execute` arm.
- **provwasm v2:** Stargate `Any` dispatch — `cw-multi-test` insufficient for marker integration tests.
