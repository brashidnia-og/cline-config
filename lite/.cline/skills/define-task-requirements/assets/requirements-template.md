# Task / feature requirements template

Use this as a **structure**, not boilerplate to leave unfilled. The final document must satisfy the requirements contract and Git-workspace reference. Replace all placeholders or explain non-applicability. Name it `YYYYMMDDTHHMMSSZ-<task-name>.md` in `product/work/requirements/`.

```markdown
---
requirements_schema_version: 1
kind: feature
id: FEATURE-001
requirements_status: DRAFT
delivery_status: DEFINING
parent_product: none
---
# Feature: <user-visible objective>

## Objective and users
## Scope and non-goals
## Behavioral scenarios
## Interfaces and data
## Quality and constraints
## Acceptance criteria
## Verification strategy
## Dependencies and delivery
## Decisions and defaults
## Open gaps

## Delivery tracking
The canonical current statuses are in frontmatter.
- **Primary owner:** <owner>
- **Current blocker:** <specific question / None>
- **Next action:** <one action>
- **Branches:** None yet
- **Pull requests:** None yet
- **Related requirements:** None
- **Acceptance evidence:** Not started

### Status history
| UTC timestamp | From | To | Actor | Evidence / reason |
|---|---|---|---|---|
```

Do not mark requirements READY until no blocking product decisions remain; do not mark delivery COMPLETE without reviewed acceptance evidence.
