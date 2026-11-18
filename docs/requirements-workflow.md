# Requirements-driven agent workflow and skill research

## Objective

Make cline-config's existing design, code quality, testing, security and subagent capabilities useful across a complete product lifecycle: product intent -> decision-complete requirements -> independent technical plan -> bounded implementation -> test -> review -> repair -> durable checkpoint -> next phase. Hermes is the primary execution target, but skill sources remain portable.

## Evidence-based repository audit (2026-11-17)

Reviewed the repository skill inventory, full/lite rules, planner/orchestrator/verifier/architecture reviewer roles, design-for-change handoff, checkpointed-analysis, persistent-analysis-store, subagent-model-routing, installer scripts and skill tests.

1. **Missing product elicitation (high priority).** The existing planner and change-planning skills start with task contracts, but did not define the adaptive interview, gap classifications, behavioral acceptance and strict readiness gate needed to hand a complete specification to a separate builder.
2. **Missing product-wide composition (high).** Existing design planning is code-oriented and bounded. There was no skill responsible for building a complete product PRD with linked features, integration journeys, product decision provenance and dependency gates.
3. **Missing implementation continuation owner (high).** Checkpointed-analysis already instructs *analysis* to continue after saving state, while orchestrator is deliberately read-only. There was no builder procedure that persisted acceptance evidence and continued implementation across milestones, review and repair.
4. **Useful foundations to reuse (strong).** Design-for-change has a versioned worker handoff; model routing protects the lead's judgment; verifier/test runner enforce evidence; CLI logging captures status; .ai/analysis supports research memory. Do not replace these with redundant new frameworks.
5. **Discoverability and testing (medium).** The profile installers already distribute skills to Hermes/OpenCode/etc. New workflows need to be included in both profiles, Cursor shared skills, the generated core routing guidance and the fixed-membership test suite. Existing pattern guides include scenario eval JSON, but this is not a measure of live skill success until agents actually run and are graded.

## Public research used

- [Agent Skills specification](https://github.com/agentskills/agentskills): portable SKILL.md/metadata contract.
- [Anthropic skill creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator): realistic trigger/eval cases, grading, variance and iterative skill improvement.
- [OpenAI skill creator](https://github.com/openai/skills/tree/main/skills/.system/skill-creator): clear trigger descriptions, compact instructions and progressive disclosure through references/scripts.
- [Hermes skills documentation](https://hermes-agent.nousresearch.com/docs/user-guide/features/skills): installed skills as slash commands, nested skill directories, skill precedence and native grouping.
- [Hermes slash commands](https://hermes-agent.nousresearch.com/docs/reference/slash-commands): skill/built-in name collision and fallback `/skill <name>`.
- [OpenAI writing skills methodology](https://github.com/openai/plugins/tree/main/plugins/superpowers/skills/writing-skills): test skill behavior with realistic failure cases.

External skills are *design references*, not copied into the repository. Inspect their licenses and security implications before vendoring code or third-party scripts.

## Skill scope and invocation

| Skill | Input | Output / invariant |
|---|---|---|
| define-task-requirements | bounded user request or feature intent | READY/DRAFT `FEATURE.md`, gap register, stable acceptance IDs; no code |
| define-product-requirements | new/large product intent | PRD, feature specs, cross-feature requirements, dependency order, E2E acceptance |
| build-from-requirements | READY PRD/FEATURE path | sequential milestone execution, acceptance ledger, review/repair, handoff and continued execution |
| product-builder | same path | shallow alias only |

Do **not** equate `READY` with guaranteed implementation feasibility or permission to perform unsafe operations. The purpose is to remove **known missing product choices** from the builder's critical path; unexpected real-world issues are documented and escalated only where they impact the contract.

## Evaluation protocol: measure real behavior

Run three types of evaluations separately for each skill/model/tool combination (Hermes lead, OpenCode lead, a small local worker):

1. **Trigger selection:** user asks for vague task, broad product, approved spec, and trivial edit. Confirm only the appropriate skill loads, and the short alias resolves correctly; test negative controls.
2. **Artifact quality:** give realistic requests and an existing repo fixture. Score behavior coverage, contradictions, traceability of decisions, acceptance specificity, failure/recovery, integration seams, and refusal to promote DRAFT to READY. Use blind independent reviewers with explicit grading criteria.
3. **Builder execution:** give a READY mock product with dependent features, intentionally failing tests, a review-detected defect, an unavailable hardware check and a seeded conflicting user edit. Grade milestone coverage, assertion evidence, reviewer independence, diff safety, bounded retries, checkpoint consistency and next-session resumption.

At least three seeds/runs per meaningful case; compare baseline (existing skills) and proposed skills with the **same** tasks/models/budgets. Record correctness, user questions after READY, tokens/latency, phase completion, regressions, verified acceptance coverage and unnecessary delegation. A static presence check or eval JSON fixture is *not* a run. Do not optimize solely for fewer questions if that increases undocumented guesses or silent security decisions.

## Follow-on optimization opportunities

- Replace redundant always-on full-profile prose with lightweight routing to targeted skills to reduce context consumption.
- Audit the generated Hermes `cline-config-delegation` payload for token overhead and verify actual skill discovery after installation with `hermes skills list`; benchmark before changing installation layout.
- Add deterministic PRD structural and dependency graph validation and live evaluations into CI once stable fixtures exist.
- Run real end-to-end Hermes sessions against a disposable demo repository, measuring restart/handoff integrity and developer intervention requirements.
- Test full/lite installation and upgrades in a clean HOME (the current suite already exercises these paths).
- Review the rest of the skill catalog for duplicates, inconsistent frontmatter, non-actionable commands, and missing negative-eval cases.

## Git-native work tracking design

The externally supplied Shortcut ticketing skill was used as **a reference for methodology**, not copied. Transferable ideas: digest sources, inspect code, resolve decision dependencies before tickets, treat the ticket as the prompt, sequence thin end-to-end slices, challenge plans and reconcile after implementation. Non-transferable assumptions: Shortcut/Notion/Figma connectors must exist, forced publication before drafting, ownership by specific coworkers, one-pass agent limits, and fixed multi-system workflow regardless of task size. The implementation here instead uses tracked `product/work/requirements/YYYYMMDDTHHMMSSZ-task-name.md` files, separate requirements readiness vs delivery progress, timestamped transitions and direct branch/PR links. See `define-task-requirements/references/git-workspace.md`.

**Tradeoff:** a Markdown tracker can be versioned and queried by any agent without additional services, but simultaneous edits may conflict. Avoid duplicate status fields, use a designated single writer for each requirement, store evidence separately, and validate Git links rather than assuming they're current.

## Smaller-model research and decision quality (PR #1)

Four narrow, optional skills are added on top of the requirements workflow: `evidence-driven-research`, `engineering-decision-analysis`, `agent-skill-evaluation`, `explain-clearly`. Their role is to improve **verified outcomes per cost**, not enforce long reasoning for trivial work. Research returns compact cited packets; decision analysis rejects options violating hard constraints before considering opportunity costs and reversibility; evaluations compare a baseline and individual interventions on the same tasks, models and budgets; user explanations use TLDR, plain causal steps and one representative example/analogy.

Public skill sources reviewed as inspiration (no copied scripts or skill contents): https://github.com/obra/superpowers (MIT), https://github.com/OthmanAdi/planning-with-files (MIT), https://github.com/anthropics/skills/tree/main/skills/skill-creator (Apache-2.0 for the skill), https://github.com/anthropics/knowledge-work-plugins (Apache-2.0), and https://github.com/samber/cc-skills (MIT). A public skill's existence or popularity is not evidence of gains on local Qwen or cheaper hosted models. The eval JSON files contain **proposed scenarios only**, not measured outcomes.

### OpenCode V2 compatibility

The role renderer now emits V2 `permissions` action/resource/effect records and denies shell for all roles with `shell: false` (including write-capable general). See https://opencode.ai/docs/agents/ and https://opencode.ai/docs/permissions. Always verify the installed OpenCode version and real tool permissions in a sandbox before treating an agent as securely read-only; prompt instructions alone are not a security boundary.
