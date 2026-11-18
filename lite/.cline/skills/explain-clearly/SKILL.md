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

Explain unfamiliar terms at first use, avoid unexplained acronyms and long paragraphs. Use active voice, ordinary verbs and specific nouns. Prefer one example over an elaborate list. For "TLDR only", answer even shorter; for deep technical requests, expand after the plain-English overview. Do not talk down to the user or sacrifice nuance for a cute analogy.

## Truth boundary
Inspect code or confirmed design when describing an actual implementation. Distinguish **currently works** from **proposed behavior**. Never invent a runtime sequence, performance claim, implemented feature, test result, or tool capability. If evidence is missing, say what is known and what would verify the rest. Avoid turning an explicit hypothetical into a factual assertion.

## Example: how does a Git-based product builder work?
**TL;DR:** The requirements file is the to-do contract. The builder finishes one testable piece at a time and records proof before moving on.

**How it works:** A requirements file tells the builder what users should be able to do. The builder chooses the first task whose dependencies are complete, writes code, runs checks and requests review. It updates the tracked task status only when it has the required evidence, then starts the next task.

**Example:** Imagine renovating a house from a checked blueprint. You finish and inspect the plumbing before closing the walls. If the inspection fails, you fix it instead of telling the owner the room is finished.

**Analogy limit:** A coding agent still needs real test and review evidence; a checked box in Markdown cannot prove software correctness.

## Handoff and status messages
When asked "what happened?" or "how will X work?", lead with the meaningful outcome or expected behavior—not tool logs, plan narration or role lists. Name the next action only if helpful. Link supporting details rather than dumping them. Do not force this format onto code review findings or required structured artifacts.
