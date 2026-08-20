---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
  - "**/Pipfile*"
  - "**/uv.lock"
  - "**/poetry.lock"
---

# Python language rules

Follow repository conventions before generic style advice. Prefer the project’s existing packaging and test stack.

## Types and boundaries
- Prefer type hints on public APIs; make `Optional` / `| None` explicit.
- Validate untrusted input at network, file, env, and user boundaries; types alone are not validation.
- Prefer clear dataclasses/pydantic/attrs models when the repo already uses them—do not invent a new modeling stack.

## Environment and packaging
- Use venv/`uv` as the repository documents; never install packages globally to “make it work.”
- Follow existing `pyproject.toml` / src layout; do not speculate new build backends.

## Errors and control flow
- Avoid bare `except:`; catch specific exceptions; preserve context with `raise … from e`.
- Prefer explicit failure modes over silent fallbacks.

## I/O and async
- Prefer `pathlib` for path manipulation.
- Do not hardcode secrets in code.
- In async code, do not mix blocking I/O into the event loop without care; respect cancellation and timeouts.

## Testing
- Prefer `pytest` fixtures and behavior assertions over testing private attributes.
- Keep tests deterministic; avoid arbitrary sleeps.
