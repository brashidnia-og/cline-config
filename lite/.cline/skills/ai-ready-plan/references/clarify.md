# Clarifying a vague request

Ask in one batch. Six questions is the ceiling, not the target. Delete any question the user already answered or the repo already settles.

## What counts as vague

| Signal | Why it blocks a plan |
|---|---|
| No actor | Success for an admin, an API client, and an end user are different criteria |
| No observable outcome | "Better" cannot be failed by a test |
| Several plausible readings | The agent will pick one silently |
| No boundary | Nearby improvements get implemented as scope |
| Happy path only | Failure, empty, duplicate, and permission behavior get invented |
| Shared behavior unnamed | A "small" change edits a contract other callers need |

Words that almost always mean the decision was deferred: **properly**, **appropriate**, **better**, **robust**, **seamless**, **handle errors**, **optimize**, **support**.

## Default questions

Use only the ones that would change the document. Offer real options from the skim of the code when they exist.

1. **Success.** What can someone observe when this is done? Options are the plausible readings of the user's words, not a design menu.
2. **Boundary.** Which nearby behaviors are outside this change? Include the tempting extras (redesign, new dependency, extra surface).
3. **Failure.** For the main unhappy path, what happens: reject with a named outcome, retry within a named budget, or leave prior state unchanged?
4. **Regression.** Which current behavior must keep working after the change? Name the real flows found nearby.
5. **Compatibility.** Which caller, stored data, config, or already-deployed version must keep working?
6. **First slice.** If only one outcome ships first, which MUST criterion is that?

Each question ends with an explicit escape: "something else" (they specify) or "you decide" (the planner may assume the smallest consistent option and label it Assumed).

## How to phrase an option

Name the observable result, the actor, and what will not happen.

Weak: "Should sharing be improved?"
Strong: "When the owner shares an item, which outcome is required? A) A recipient with an account can open it. B) Anyone with the link can open it until the owner revokes it. C) Both, and revoke is required in this change. D) Something else. E) You decide."

## Second round

Allowed only for a contradiction or a MUST criterion that is still untestable after the answer. Quote both sides. Do not add new topics.

## Worked request

User: "Make export better."

Skim finds one CSV export used by the billing job and an admin button that downloads it.

Ask:

1. Success — which outcome? A) The admin download includes the new invoice fields. B) The billing job's CSV gains those fields. C) Both must change together. D) Something else. E) You decide.
2. Boundary — confirm these are out of scope: PDF export, emailing the file, changing invoice calculation.
3. Failure — if a row is missing a required field, should that export abort with a named error, skip the row and report a count, or stay as it is today?
4. Regression — the billing job parses column order. Must today's columns stay in today's order and meaning?
5. First slice — if one of A or B has to wait, which one is required now?

Do not ask whether to use a streaming writer or a new package. That is an implementation decision after the criteria exist.
