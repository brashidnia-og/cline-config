---
paths:
  - "**/contracts/**/*.rs"
  - "**/schema/**"
  - "**/artifacts/*.wasm"
---

# CosmWasm language rules

Apply when editing or reviewing CosmWasm contracts (especially on Provenance). For full audits, also load `smart-contract-security-audit`.

## Entrypoints and auth
- Every `ExecuteMsg` variant needs an explicit authorization check — no implicit trust in `info.sender` without a predicate.
- Auth must not be satisfiable from the attacker's default state (e.g. unprivileged deploy of a malicious contract).
- `migrate` must gate on `cw2` contract version; validate old state layout.

## Arithmetic and funds
- Enable `overflow-checks = true` in release builds.
- Prefer `cw-utils` (`must_pay`, `one_coin`, `nonpayable`) over manual `info.funds` parsing.
- Multiply before divide; guard zero divisors; normalize decimals explicitly.

## Storage and iteration
- Bound loops and `range` queries — unbounded iteration is a freeze/gas risk.
- Validate `Addr` on deserialize; persist all state mutations.
- Namespace storage keys to avoid collisions between modules.

## Submessages and replies
- Unique `reply_id` per logical operation; handle `SubMsgResult::Err` without silent fund loss.
- In CW20 hooks: `info.sender` is the token contract; verify balance deltas when token address is caller-supplied.

## provwasm v2 (Provenance)
- Dispatch Provenance messages via Stargate `Any` (`type_url: "/provenance.<module>.v1.Msg*"`) and `provwasm_std::types::provenance::*` — not `CosmosMsg::Custom`.
- `cw-multi-test` does not emulate marker/Stargate behavior — use `provwasm-mocks` or testnet for integration proofs.

## Before merge
- Run `cargo fmt --check`, hardened `clippy`, `cargo test`, and `cosmwasm-check` on release WASM when configured.
- Diff `cargo schema` output when message or state types change.
