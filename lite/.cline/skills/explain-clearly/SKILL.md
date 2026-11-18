---
name: explain-clearly
description: Give clear, concise, no-fluff TLDR and ELI5 explanations of how a system, technology, feature, design choice, or workflow works. Use when a user asks "how does X work?", "how will Y work?", "explain", "ELI5", "TLDR", or requests simpler language, especially in coding-agent status updates and technical decision discussions. Skip when they request only code, raw data or a specified formal format.
---

# Explain clearly

Purpose: make complex systems genuinely understandable **without losing critical correctness**. Use this as a focused user-facing communication skill; it does not replace repository inspection or the research and decision procedures.

## Default answer
1. **TL;DR:** 1–2 direct sentences answering the actual question.
2. **How it works:** 2–5 short, plain-English sentences in causal order: who/what starts it, what happens, why it matters, what the user sees.
3. **Concrete example:** one realistic scenario grounded in known system behavior, written for a non-expert. When a direct example would be misleading or impossible, use an analogy and clearly label the analogy's limits.
4. **Important caveat:** at most 1–2 high-impact constraints/unknowns when material. Don't bury a blocker, side effect or security caveat in an upbeat summary.

Explain unfamiliar terms at first use, avoid unexplained acronyms and long paragraphs. Use active voice, ordinary verbs and specific nouns. For one mechanism, prefer one example over an elaborate list; **for multiple compared options, give one parallel example per option**. For "TLDR only", answer even shorter; for deep technical requests, expand after the plain-English overview. Do not talk down to the user or sacrifice nuance for a cute analogy.

## Explaining and comparing multiple options

When the user asks "how would A vs B work?", "what's different?", "what's similar?" or is choosing between proposed designs, explain **each option in the same real-world scenario**. Do not collapse alternatives into a single analogy or list abstract pros/cons without showing what actually happens.

1. **TL;DR:** State the main practical difference in one or two sentences; add a recommendation only if supported by evidence and the user's goals.
2. **Shared situation:** Choose one concrete, realistic scenario with the same actors, input, constraints and desired outcome for every option. If no direct scenario works, use parallel analogies and label their limits.
3. **Option A:** Explain in layman's terms what starts the action, the sequence, what the user experiences, and one material tradeoff.
4. **Option B (and each additional option):** Walk through that **same** situation with equal clarity and comparable detail, not a different example that unfairly favors it.
5. **How they are similar / how they differ:** State the common purpose, shared steps and guarantees, then the key difference in behavior, complexity, cost, timing, risk or reversibility, as relevant. Use a tiny table when it makes multiple dimensions easier to scan.
6. **Which to choose:** Connect the distinction to the user's actual priorities and evidence. If performance or behavior is unverified, say what test would decide; never invent numeric benefits.

Keep comparisons proportionate: two options usually need only two short scenarios, a similarities/differences summary and a one-line takeaway. Don't use an analogy instead of a concrete case when a concrete case is available. Keep hypothetical and existing behavior clearly labeled.

### Example: event processing in a phone game (illustrative designs, not measured outcomes)

**TL;DR:** Both designs can deliver the same opponent move. They differ in when the game notices an arriving message.

**Shared scenario:** Two people play a phone game; one moves their character, and the other phone receives that move between display updates.

**Option A — Polling:** The game checks its inbox on each scheduled game update. If the move arrives just after a check, it sits in the inbox until the next check—like checking the mailbox every morning.

**Option B — Event-driven:** A network handler is alerted when the move arrives and can pass it into a safe queue for the game to apply at the appropriate point—like a doorbell alerting you that mail arrived. The game may still apply the move on its next simulation update.

**Similar:** Both need network transport, message validation, ordered game-state application and recovery from failures. Neither by itself guarantees lower end-to-end latency.

**Different:** Polling couples when messages are *noticed* to scheduled checks; event-driven reception can notice arrivals sooner but needs explicit concurrency and queue ownership. The right choice depends on measured delay, complexity and reliability.

## Truth boundary
Inspect code or confirmed design when describing an actual implementation. Distinguish **currently works** from **proposed behavior**. Never invent a runtime sequence, performance claim, implemented feature, test result, or tool capability. If evidence is missing, say what is known and what would verify the rest. Avoid turning an explicit hypothetical into a factual assertion.

## Example: how does a Git-based product builder work?
**TL;DR:** The requirements file is the to-do contract. The builder finishes one testable piece at a time and records proof before moving on.

**How it works:** A requirements file tells the builder what users should be able to do. The builder chooses the first task whose dependencies are complete, writes code, runs checks and requests review. It updates the tracked task status only when it has the required evidence, then starts the next task.

**Example:** Imagine renovating a house from a checked blueprint. You finish and inspect the plumbing before closing the walls. If the inspection fails, you fix it instead of telling the owner the room is finished.

**Analogy limit:** A coding agent still needs real test and review evidence; a checked box in Markdown cannot prove software correctness.

## Handoff and status messages
When asked "what happened?" or "how will X work?", lead with the meaningful outcome or expected behavior—not tool logs, plan narration or role lists. Name the next action only if helpful. Link supporting details rather than dumping them. Do not force this format onto code review findings or required structured artifacts.
