---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
  - "**/Pipfile*"
  - "**/uv.lock"
  - "**/poetry.lock"
  - "**/setup.cfg"
  - "**/setup.py"
  - "**/tox.ini"
  - "**/pytest.ini"
  - "**/ruff.toml"
  - "**/mypy.ini"
---

# Python command policy

Inspect `pyproject.toml`, lockfiles, and test/lint config before unfamiliar commands. Prefer `uv run` when `uv.lock` or a uv project exists; otherwise follow the repository’s venv/`python -m` convention.

## Generally safe inspection
```bash
python --version
python3 --version
uv --version
uv pip list
python -m pip list
```

## Generally safe local validation after inspection
```bash
uv run pytest <path> -k <expr>
uv run pytest <path> -q
pytest <path> -k <expr>
ruff check <path>
ruff format --check <path>
mypy <path>
pyright <path>
python -m compileall -q <path>
python -m py_compile <file>
```

Run mypy/pyright only when the repo configures them. Prefer targeted tests over full-suite by default.

## Not auto-approved
Do not automatically run `pip install`, `pip uninstall`, `uv add`, `uv remove`, `uv sync` (unless the user explicitly asks), `poetry add`/`poetry install` mutating lockfiles, or `conda install`. Do not use formatters with write flags merely for inspection (`ruff format` without `--check`).
