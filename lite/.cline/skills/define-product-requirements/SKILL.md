---
name: define-product-requirements
description: Discover and finalize a complete product vision and implementation-ready PRD with interconnected feature specifications. Use when starting a new app, game, service or larger product, redefining an MVP, interviewing stakeholders, or turning a broad idea into an autonomous-builder-ready roadmap. Composes the define-task-requirements contract for each feature; do not implement code.
---

# Define product requirements

**Mission:** transform a vision into a decision-complete, testable product requirements package. Read `define-task-requirements` and its `references/requirements-contract.md`; reuse that feature contract **per feature**. This is product discovery and systems-level product consistency, not code implementation.

## 1. Understand the whole product
Inspect the existing repo, user statements, prior product decisions, competitor/reference evidence if relevant, environment and platform constraints. Derive: intended users and jobs-to-be-done; positioning and user value; actors/roles; primary workflows; product boundaries and non-goals; MVP success metrics; operational and technical envelope; how first use, repeat use, failure, and recovery work.

Build a **journey map** before splitting into features: onboarding/installation, authentication or discovery, main interaction, saving/sync, exit/restart, error/degraded behavior, administration/security/abuse (as applicable). Explore how a complete user goal traverses multiple components. Ask what the user expects at launch vs deliberately later.

## 2. Interview for decision completeness
Maintain a decision/gap register using `define-task-requirements` classifications. For the most consequential unknowns, ask **1–3 grouped choices at a time**, with a recommendation, tradeoffs, and the affected user journey. Do not ask questions code/docs can answer; avoid repeat questions and speculative feature expansion.

Pay special attention to *hidden product requirements* absent from a happy-path prompt: onboarding, permissions, user-facing errors, persistence, multi-user coordination, networking/offline behavior, recovery, device coverage, accessibility, latency, data loss, costs, support, deployment and version migration. Only demand details applicable to the product. Distinguish user-selected intent from recommended safe defaults.

Do not fabricate consent or decide irreversible/high-impact product behavior. If unavailable, produce `DRAFT` plus concrete blocking decisions; a product that cannot pass the readiness gate is not autonomous-build ready.

## 3. Decompose into feature contracts
Write an umbrella `product/work/requirements/YYYYMMDDTHHMMSSZ-product-name.md` plus distinct, timestamped `product/work/requirements/YYYYMMDDTHHMMSSZ-feature-name.md` files (unless the repo already has an equivalent tracked convention). Follow the shared [Git-native workspace reference](../define-task-requirements/references/git-workspace.md) for statuses, links, dependency references and stable names. Each feature is authored with the `define-task-requirements` contract and independently testable acceptance IDs. Include cross-feature interface and state ownership, startup/shutdown, lifecycle, versioned data, integration failure paths and compatibility. Provide an ordered, acyclic feature index with dependencies; separate MVP from deferred work. For multi-repo products explicitly name canonical ownership, interface commitments, build order, integration repository and compatibility testing.

Define end-to-end acceptance in the **umbrella PRD** (not merely feature tests): representative complete journeys, security boundaries, performance on target devices, recovery, migration, rollout and rollback, plus what evidence proves an integrated product works.

## 4. Challenge the assembled specification
Perform an internal adversarial pass and, if supported, assign an **independent read-only** `requirements-reviewer` to find ambiguity/contradiction and untestable acceptance. Challenge every interface between features: sequencing, shared data definitions, permissions, version drift, state transitions, failure propagation and cross-repo integration. Reconcile findings; if a product decision is required, interview instead of assuming.

The PRD receives `requirements_status: READY` and `delivery_status: "READY TO BUILD"` only if **all in-scope MVP features are READY**, no blocking product questions remain, feature dependencies resolve, the end-to-end integration acceptance is testable, and non-goals and safe defaults are explicit. Review the [contract](../define-task-requirements/references/requirements-contract.md) and document evidence for the READY verdict. A structural validator does not replace this semantic audit.

## 5. Builder handoff
Return one entry point: the dated product requirements file, with `requirements_status: READY`, `delivery_status: "READY TO BUILD"`, linked feature specifications, decisions, risks, evidence, real branch/PR references when present and milestone order. The user should be able to invoke:

```text
/build-from-requirements @product/work/requirements/<UTC-timestamp>-product-name.md
```

or the `product-builder` alias. The builder should not have to clarify the *intended product*. If evidence changes or an unforeseen significant product choice emerges, it must raise a scoped change request and stop only affected work rather than silently guessing. Never claim a DRAFT is READY just to permit autonomous execution.
