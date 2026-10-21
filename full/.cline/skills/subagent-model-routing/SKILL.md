---
name: subagent-model-routing
description: Decide what the main-thread model keeps and what it delegates, and pick a sub-agent model from the models the user says are active — typically a strong hosted lead plus smaller, slower local LLM workers. Covers capability tiers, routing rules, concurrency, inference budgets, worker briefs, report schema, stop rules, and lead verification. Use when the user lists available or active models, asks which model should do a sub-task, or delegates work to local models (vLLM, llama.cpp, Ollama, custom endpoints).
---

# Sub-agent model routing

Goal: maximize correct, independently verified work per hour by keeping hard judgment on the main-thread (lead) model and sending bounded, checkable work to cheaper or local workers.

This skill is lead-only guidance. Never paste it into a worker prompt; workers receive only the brief (§5) and return the report (§6).

## 1. Inputs: which models are usable

The user's prompt (or project notes) names the active models. For each, establish before routing:

- **Name and endpoint** — how the harness reaches it (native sub-agent tool with a model setting, custom endpoint, CLI child).
- **Tier** — lead-capable hosted model, or limited worker (local, quantized, small, or slow).
- **Limits** — context window, per-inference reasoning budget, answer/output cap, measured tokens/sec and prefill speed, tool-calling reliability.
- **Concurrency** — how many requests the backend serves at once (one GPU/host usually means one active worker).

If the active set is not stated and cannot be read from configuration, ask once. Do not assume a model from an earlier session is still loaded. Do not assume one local backend is stronger than another — measure.

## 2. Default capability assumptions

Treat local models as **more limited** than the lead unless measured otherwise: shorter reliable reasoning, weaker cross-file synthesis, less dependable tool calls, slower prefill on large prompts, and higher confident-error rates. They are strong at focused, well-specified work on code you point them at.

## 3. Routing

**Lead keeps:**
- Architecture, trust boundaries, threat models, defining invariants.
- Cross-module, cross-service, or cross-contract reasoning; economic and concurrency/state-consistency problems.
- Novel or ambiguous scenarios; resolving conflicting evidence.
- Severity, exploitability, and impact judgments; security-sensitive patch design.
- Acceptance decisions, final verification, final report.

**Delegate to a worker when the task is** well-defined, independently executable, and produces a checkable result:
- Summarize or trace named files, call chains, state transitions, data/fund flows.
- Check named code paths against explicit invariants; search the codebase for a known pattern.
- Hunt for unexpected defects within an assigned scope — not only confirm the lead's hypothesis.
- Write focused unit, negative, property, or fuzz tests; implement a clearly specified fix.
- Run and interpret targeted lint/static analysis.
- Independently review another worker's change.

**Do not delegate:** "audit the whole repo", "fix all bugs", open-ended design, or anything whose result the lead cannot verify faster than doing it.

**Picking among workers:** prefer the idle backend with the best measured throughput for the task shape (long prompt → fastest prefill; long reasoning → largest reasoning budget; tool-heavy → most reliable tool calls). If no worker fits, the lead does it. Do not delegate merely to keep workers busy.

**Explicit selection wins.** When the user explicitly selects a model or reasoning effort for a worker (CLI flags, a named worker, or a handoff `model_selection`), that selection overrides the heuristics above. If the harness cannot honor it (no model/effort setting, no delegation tool), report the limitation and keep the work on the lead — never silently run a different model.

Workers may report findings of any severity; never suppress a finding because of which model raised it. Workers escalate on architectural ambiguity, unclear assumptions, conflicting evidence, or work beyond the brief.

## 4. Concurrency, writes, and state

- One active worker per backend unless the backend is measured to serve more without slowdown.
- Investigations are read-only. **Implementation writers are serial by default** (one writer at a time); parallel writers in separate worktrees are an explicitly enabled opt-in experiment, and still never two writers on one file.
- **Single writer for durable state:** only the lead writes analysis stores (`.ai/analysis/`, `STATE.md`), ledgers, and reports. Workers return reports — or proposed content/diffs for implementation work; the lead verifies, then checkpoints.
- The lead keeps working (planning, verifying, integrating) while workers run.

## 5. Inference budgets and the worker brief

- Use each model's supported reasoning mode and its configured per-inference reasoning ceiling — a ceiling, not a target.
- Budget final-answer/tool-call tokens separately from reasoning. If a backend caps total output, reasoning can starve the answer.
- Before first real use of a backend, run one probe: confirm the reasoning budget is enforced and long answers and tool calls are not truncated. Record the result.
- Keep distinct: per-inference reasoning tokens, answer tokens, total task tokens, context size, harness tool iterations, wall-clock limits.
- Never send backend-specific parameters (e.g. vLLM sampling extras) to hosted endpoints.
- Send focused excerpts and paths, not whole repositories or histories. A large context window does not make large prompts cheap on local hardware.

**For implementation work, use the structured, versioned handoff** owned by `design-for-change` (`references/design-handoff.md`): `schema_version` (currently 1; treat an unknown version as a reason to clarify, not to guess) plus `role`, `mode`, `objective`, `depends_on`, `owned_files`, `contracts_and_invariants`, `acceptance`, `validation_commands`, `model_selection {model, reasoning_effort}`, `budgets {tool_iterations, wall_clock_seconds}`, `escalate_if`, and `response`. The text fields below remain the minimum for research briefs; the handoff supersedes them for implementation tasks.

```text
OBJECTIVE:   one sentence
SCOPE:       files / functions / code paths (paths + line ranges)
INVARIANTS:  specific properties to check
NON-GOALS:   what not to touch or investigate
ALSO:        "Report any other defect you find within SCOPE."
MODE:        read-only | write (worktree path)
DELIVERABLE: findings report | tests | patch
ACCEPTANCE:  concrete check (e.g. test fails before fix, passes after; every claim cites file:line)
BUDGET:      tool iterations N; wall clock M minutes
```

Starting iteration budgets for limited workers: simple inspection 4–8, focused analysis or implementation 8–12, complex bounded work 12–20. Target tasks that return useful results in roughly 15–40 minutes; split larger ones. Tune from measured runtimes.

## 6. Worker report schema

```text
STATUS:      done | partial | blocked (reason)
FINDINGS:    per item: claim; file:line; violated invariant; attacker/caller-controlled input
             and prerequisites; reachable path; evidence (code quote / test output);
             confidence: confirmed-by-test | strong | speculative
TESTS:       commands run and the meaningful assertions they check
CHANGED:     files modified (write mode only)
NOT CHECKED: what in scope was not covered
ESCALATE:    questions for the lead
```

## 7. Observability and stopping

- Track per worker: ID, model/backend, objective, elapsed time, current activity, files touched, preliminary findings, tests run, blockers.
- Use the harness's native progress view. For CLI-launched children, follow `cli-subagent-progress-logging`.
- Slow but producing new evidence → let it run.
- **Unproductive** = two consecutive progress checks with no new files, evidence, or findings. Diagnose (prefill, slow decode, tool latency, repeated discovery, missing information, real blocker), preserve output, then narrow the brief and retry once, or escalate. No unbounded retries.
- For long tasks, continue from durable checkpoints (see `checkpointed-analysis`) rather than restarting discovery.

## 8. Lead verification

All worker output is untrusted until the lead verifies it. For each suspected defect:

1. Read the exact code; name the violated invariant.
2. Establish caller/attacker inputs, prerequisites, and the reachable path.
3. Validate the mechanism, preferably with a reproducible test whose assertions are meaningful.
4. Check existing mitigations.
5. Assess realistic impact.

Classify each as confirmed, strongly supported, speculative, or false positive. Contradictory worker results get an independent lead investigation. Accept a patch only after the lead verifies it fixes the root cause and preserves intended behavior. Passing tests or clean scans are not proof of correctness or security. Never run exploit-style tests against live or production systems without explicit authorization. Do not trade correctness for token savings.

## 9. Final report

State which model did what, then: confirmed issues; unconfirmed potential issues; false positives; invariants tested; areas reviewed; areas not adequately reviewed; reproduction evidence; remediations; residual risk.
