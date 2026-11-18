---
name: product-builder
description: Alias for build-from-requirements. Use /product-builder followed by a READY PRD.md or FEATURE.md path to continuously implement, test, independently review, repair, checkpoint and advance through its acceptance criteria.
---

# Product builder

Load and follow the full sibling `build-from-requirements/SKILL.md` skill from the same installed profile, together with its linked references. In Hermes, use skill discovery (`skill_view` or equivalent) to load the sibling skill if it was not already injected. This is a short invocation alias, **not** a separate workflow or independent ruleset. Pass the user's `@path` argument unchanged. Do not start building from an unapproved DRAFT specification. If the referenced skill is not installed, report this as a configuration problem rather than inventing its procedure.
