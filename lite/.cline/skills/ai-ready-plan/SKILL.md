---
name: ai-ready-plan
description: >-
  Turn a vague feature or change request into one development-ready plan an
  implementing agent can execute. Interviews the requester until the observable
  outcome, non-goals, failure behavior, and regression obligations are
  decidable, then writes testable acceptance criteria, a regression contract,
  repository-grounded tasks, and embedded agent rules. Use when the user asks
  for an AI-ready plan, a development-ready plan, requirements before
  implementation, or describes a feature without a testable outcome. Skip
  trivial typos, renames, and one-line fixes.
---

# AI-ready plan

Goal: one document that states what must become true, what must stay true, how to prove both, and the exact tasks an implementing agent may perform. The implementer must not invent product behavior or redesign the feature.

Do not implement the feature while this skill is running. Do not edit product code.

## 1. Decide whether to ask

Read the request once and classify it.

**Ready to plan** when all of these are already stated or trivially implied by a single behavior: the actor, the observable outcome, what is out of scope, and the unhappy path that matters. Inspect the repo and write the document. Quote the user's words as decisions.

**Vague** when a missing answer would change a MUST criterion, a non-goal, or a regression row. Typical signals: no actor, no observable done-state, or words such as "better", "properly", "appropriate", "robust", "handle errors", "improve", "support", or "make X work" with more than one plausible behavior.

Repo facts are not interview questions. Skim the relevant code first so options name real current behavior. Ask only what inspection cannot answer.

## 2. One clarification round

Ask before drafting a plan that could be mistaken for approved. One batch, at most six questions. Use a structured question tool when the host has one; otherwise one chat message. Question shapes, the default six, and a worked vague request: [references/clarify.md](references/clarify.md).

Each question names the decision it unlocks and offers two to four concrete options when the choice is closed, plus a way to answer "something else" or "you decide".

Drop questions the user already answered. Prefer, in order: observable success, non-goals, failure behavior, untouchable current behavior, compatibility, and the smallest first slice.

When the user says "you decide" or "assume and proceed", pick the smallest option consistent with their words, label it **Assumed**, and continue. Otherwise leave the gap open. Do not invent product policy to finish the document.

Ask a second time only when an answer contradicts another answer or still leaves a MUST criterion untestable. Ask only about that contradiction.

Do not ask the user to choose files, patterns, libraries, or task splits.

If any product decision is still open and the user has not allowed assumptions, stop. Reply with the questions (or the contradiction) and a short recap of what is already decided. Status stays `clarifying` or `blocked`. Do not write `plans/<slug>.md` yet.

## 3. Inspect, then resolve design

Read the code, tests, config, and commands the change will touch. Cite paths. Trace behavior that will change and behavior that shares state, callers, schema, or contracts with it. Copy validation commands from the project. Never invent APIs, folders, or commands. If the tree is unavailable, say so and omit file-level tasks rather than guessing paths.

Record design decisions in the plan. Do not restate specialist procedures:

- Code-level responsibility, variation, or ownership: follow `design-for-change`. Task bodies use its handoff schema (`references/design-handoff.md`).
- Service, data, or deployment boundaries: follow `architecture-review` when that skill is installed. Otherwise cover invariants, failure and partial success, compatibility, migration, and rollback inline. Follow `00-core-global` for execution mode. Do not require a role the profile does not install.

`change-planning` sequences work whose requirements are already decidable. This skill owns the interview and the single handoff document. Do not emit a second plan format.

## 4. Write the document

Fill [references/plan-template.md](references/plan-template.md). Copy section 11, Agent execution rules, unchanged so the file stands alone when a later agent does not have this skill loaded.

Write `plans/<kebab-slug>.md` in the workspace. Also name that path in the reply. Status is `ready` only when the gate below passes. If the user allowed assumptions but a fact is still unknown, status is `blocked` and the unknown stays in Open decisions.

Terminology, used the same way throughout the document:

- **Acceptance criterion (AC)** — a new or changed observable behavior.
- **Regression row (RG)** — a current behavior that must remain true.
- **Decision** — a product or design choice with a source: user, assumed, or inspected.
- **Task** — one independently verifiable implementation slice with owned files.

Every AC uses a named trigger and a named observable result. Given / When / Then is the proof sentence. Add an EARS "shall" line only when the condition would otherwise be implicit (state, unwanted behavior, optional feature). Reject criteria that a test author could not fail on purpose.

Every behavior the change can affect gets an RG row, or one row that records why inspection found no shared risk. "No regression risk" without an inspected reason fails the gate.

Every task lists `ac_ids`, `regression_ids`, owned files, acceptance, a validation command copied from the repo (or an explicit manual check), and `escalate_if`.

## 5. Gate before calling it ready

The document is not ready when any of these are true:

- A MUST criterion still depends on "properly", "appropriate", "better", "robust", or unspecified error handling.
- A criterion has no evidence: an existing test, a named new test, or an explicit manual check.
- A task omits owned files, acceptance, validation, `ac_ids`, or `escalate_if`.
- An open product decision is buried in an implementation step.
- An assumption is unlabeled.
- A file path or command was not found in the repo.

Apply the profile quality gate and plan gate from `00-core-global`. Label Verified, Inferred, Assumed, and Unknown. The reply points at the file, states status, and lists open decisions. It does not start implementation.
