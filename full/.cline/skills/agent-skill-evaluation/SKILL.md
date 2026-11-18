---
name: agent-skill-evaluation
description: Evaluate and improve agent skills, tool workflows and smaller-model coding performance with reproducible baseline-vs-skill tests, negative trigger cases, task-level outcome metrics and controlled ablations. Use when creating/changing skills or optimizing Qwen, local models, inexpensive frontier models or harness configuration; not during ordinary code changes.
---

# Agent skill evaluation

Objective: select only changes that measurably improve **correct verified outcomes per cost and time**. A fixture JSON or a successful syntax check is not evidence that a model follows a skill.

## 1. Define the failure and baseline
Name a real observed failure: misrouted skill, too many irrelevant file reads, invented API, weak recommendation, repeated tool errors, missing tests, or premature completion. Choose representative tasks and observable acceptance criteria. Record exact model/version, quantization, provider, context, tool schema, prompt, runtime, budgets, git base and hardware when relevant.

## 2. Build a paired evaluation
Use the *same* task cases, available tools and budgets for:
A. baseline (current config);
B. one candidate change;
C. combined interventions only after their individual effects are measured.
Include simple tasks (skill should NOT trigger), complex cases, intentionally misleading evidence, contradictory docs, a failure requiring tool feedback, and a context-compaction/restart case where relevant. Prefer multiple runs or seeds when possible; report run count and variance. Keep a frozen holdout set to avoid optimizing prompts for known fixtures.

## 3. Score outcomes, not verbosity
Primary: behavioral correctness and verified acceptance, safety and instruction compliance, false-positive/false-completion rate. Secondary: relevant-source recall, false claims, tool-call success/errors, redundant calls, wall time, input/output tokens, prompt prefill, GPU throughput, peak memory and dollars/energy when available. Compare costs *per verified success*, not absolute token savings. A beneficial extra tool call may reduce expensive rework.

Separate task research, decision quality, implementation, tool reliability, and summarization. Don't attribute a change in one dimension to another without ablation. For local backends compare supported KV/context/quantization settings on the **same** workload and distinguish model from harness changes.

## 4. Inspect failures and revise
For each run save: minimal task prompt, skill revision, model/backend, exact grade assertions, observed artifacts/test output, relevant trace/cost and the cause of failure. Check if the skill activated and was actually loaded. Classify model reasoning failure vs missing evidence vs invalid tool schema vs bad permissions vs prompt conflict. Improve the smallest bottleneck; run again against both training and holdout cases. Stop when gains are unreliable or overhead outweighs benefits.

## 5. Output
Return a concise comparison table: variant, model, n, verified success, error/false-completion, median or distribution for cost/time/tool calls, caveats and recommendation. Say **NOT RUN** when scenarios were only authored, not executed. Do not claim one skill makes a model generally more intelligent based on a few coding tasks.

## Skill authoring
Use clear trigger descriptions, concise top-level steps, supporting references for rare cases, explicit negative examples and bounded outputs. Inspect and honor third-party licenses before copying files/scripts; prefer adaptation over competing near-duplicate skills. No unconditional autonomous or permission-bypass instructions.
