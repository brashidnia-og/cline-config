---
name: cli-subagent-progress-logging
description: Preserve CLI-launched sub-agent progress in a per-run log while keeping it visible live. Use when launching a child through the shell — `hermes chat`, test runners, build/lint/release tools, any long CLI job — instead of a native sub-agent tool. Covers `2>&1 | tee` dual output, `set -o pipefail`, unbuffered output, exit-status recording, and concise completion summaries.
---

# CLI sub-agent progress logging

Goal: a sub-agent launched as a shell child keeps durable per-run progress in a log without losing the live view — and its failure is never masked by a successful wrapper process.

Scope: children launched from the shell (`hermes chat`, test runners, build/lint/release tools, any long-running CLI job). Native sub-agent tools (Task, `delegate_task`, `use_subagents`) already report progress and results through their own mechanisms — do not wrap those in `tee`.

## 1. Per-run log

- One log per run: `runs/<YYYYmmdd-HHMMSS>-<label>.log` (or the workflow's equivalent). Do not share a log across runs unless an existing workflow deliberately appends to one.
- Never put secrets in the log: pass credentials through the environment or flags the child does not echo, and redact before sharing the log.

## 2. Dual output

Forward the child's combined output to the parent terminal (or the harness's process capture) and to the run log at the same time:

```bash
set -o pipefail
LOG="runs/20261006-041500-hermes-chat.log"
hermes chat "the goal" 2>&1 | tee "$LOG"
```

- Redirect with `2>&1` before the pipe so stderr joins stdout in one stream.
- Continuing an existing log: `tee -a "$LOG"`.
- `set -o pipefail` is required in the launching shell or wrapper script. Without it, the pipeline's exit status is `tee`'s — a failed child is reported as a successful run.
- Where the child supports it and live progress matters, enable unbuffered output (`python -u`, `stdbuf -oL -eL`, or the tool's own `--unbuffered`/`--no-buffer` flag). Check the tool's docs before forcing TTY tricks.

## 3. Record the outcome

- Capture the pipeline's exit status immediately (`rc=$?`). With `set -o pipefail` it reflects the child's failure; without it, a zero `tee` status is not child success — verify the child's status independently.
- Record the child command, exit status, and log path in your task notes or state so a later cycle can resume from the log.

## 4. Report progress and completion

- While the child is running, report progress from the live stream; if the parent view shows nothing, tail the log instead.
- On completion, return a concise summary: child command, exit status, elapsed time, key outcome, and the log path for follow-up.

When available, record observed start/end timestamps and elapsed time, model/backend/variant, tool and repair-attempt counts, usage metrics, plus command, exit status, and log path. Mark unavailable or non-comparable usage/cache metrics as `unknown` (never zero). Do not infer hidden reasoning usage, store hidden reasoning, or log secrets. These optional fields supplement — and never replace — combined stdout/stderr capture, `pipefail`, and the actual child exit status.

## 5. Failure and capture handling

- A log that is moving but shows no visible parent output is a capture problem (buffering, a wrong redirection, the harness consuming stdout) — diagnose the capture path before assuming the child is hung.
- `tee` does not extend or disable independent turn limits, watchdogs, or tool timeouts. If a child outlives the parent's limits, that is a timeout-policy decision (longer limit, managed background job, checkpointing) — never claim the log keeps the session alive.
- When a child fails, keep the log, report the exit status and the log tail, and diagnose from the log rather than from memory.
