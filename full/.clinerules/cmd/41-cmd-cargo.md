---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
  - "**/build.rs"
  - "**/.cargo/**"
---

# Cargo command policy

Inspect `Cargo.toml`, `Cargo.lock`, `.cargo/config*`, toolchain files, and unfamiliar `build.rs` before assuming build behavior. `cargo check/build/test` can execute `build.rs`.

## Generally safe inspection
```bash
rustc --version
cargo --version
rustup show
cargo metadata
cargo tree
cargo pkgid
cargo tree -i <crate>
cargo tree -p <crate>
```

## Generally safe local validation after inspection
```bash
cargo check
cargo check --all-targets
cargo fmt --check
cargo clippy
cargo clippy --all-targets
cargo test <test-name>
cargo test --test <integration-test>
cargo test --lib
cargo test --all-targets
cargo test <test-name> -- --nocapture
cargo nextest run
cargo deny check
```

Use `cargo nextest` / `cargo deny` only when configured in the repository. Prefer targeted test → `cargo check` → clippy → broader tests according to risk.

Inspect `build.rs` more closely when it invokes shell commands, performs network access, writes outside normal build directories, or the repository is untrusted.

## Not auto-approved
Do not automatically run `cargo install`, uninstall, update, add, remove, publish, login, yank, or clean. `cargo clean` is not source-destructive but removes build caches and should not be a generic debugging reflex.
