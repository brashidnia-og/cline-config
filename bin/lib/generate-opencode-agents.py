#!/usr/bin/env python3
"""Generate OpenCode AGENTS.md by concatenating a profile's .clinerules.

Cline sources remain the source of truth. OpenCode has no path-gated rules,
so former `paths:` frontmatter becomes an always-on scope note.
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from pathlib import Path
from typing import Any

# Light tool-agnostic wording for text that hard-codes Cline.
WORDING_REPLACEMENTS: list[tuple[str, str]] = [
    (
        "You are running through Cline with a local model.",
        "You are a coding agent with a local/context-limited model.",
    ),
]


def die(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def split_frontmatter(text: str) -> tuple[dict[str, Any] | None, str]:
    """Parse optional YAML-ish frontmatter. Returns (meta_or_None, body).

    Only understands the `paths:` list used by this repo's .clinerules.
    Avoids a PyYAML dependency.
    """
    if not text.startswith("---\n") and not text.startswith("---\r\n"):
        return None, text

    # Find closing --- on its own line
    match = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n(.*)$", text, re.DOTALL)
    if not match:
        return None, text

    raw_fm, body = match.group(1), match.group(2)
    meta: dict[str, Any] = {}
    paths: list[str] = []
    in_paths = False

    for line in raw_fm.splitlines():
        stripped = line.strip()
        if stripped == "paths:":
            in_paths = True
            continue
        if in_paths:
            # list item: - "pattern" or - pattern
            m = re.match(r"^-\s*(.+)$", stripped)
            if m:
                item = m.group(1).strip()
                if (item.startswith('"') and item.endswith('"')) or (
                    item.startswith("'") and item.endswith("'")
                ):
                    item = item[1:-1]
                paths.append(item)
                continue
            # non-list line ends paths block
            in_paths = False
        if ":" in stripped and not stripped.startswith("-"):
            key, _, val = stripped.partition(":")
            meta[key.strip()] = val.strip().strip("\"'")

    if paths:
        meta["paths"] = paths
    return meta, body


def apply_wording(text: str) -> str:
    for old, new in WORDING_REPLACEMENTS:
        text = text.replace(old, new)
    return text


def collect_rule_files(rules_dir: Path) -> list[Path]:
    files = sorted(rules_dir.rglob("*.md"))
    return [p for p in files if p.is_file()]


def render_section(rel: str, meta: dict[str, Any] | None, body: str) -> str:
    parts: list[str] = []
    parts.append(f"<!-- source: {rel} -->")
    parts.append("")
    if meta and meta.get("paths"):
        paths = meta["paths"]
        joined = ", ".join(f"`{p}`" for p in paths)
        parts.append(f"**Scope (originally path-gated in Cline):** apply when working with: {joined}")
        parts.append("")
    body = body.strip("\n")
    if body:
        parts.append(body)
        parts.append("")
    return "\n".join(parts)


def generate(rules_dir: Path, profile: str) -> str:
    if not rules_dir.is_dir():
        die(f"rules directory not found: {rules_dir}")

    files = collect_rule_files(rules_dir)
    if not files:
        die(f"no .md rule files under {rules_dir}")

    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    out: list[str] = []
    out.append("# OpenCode agent instructions")
    out.append("")
    out.append(
        f"Generated from the `{profile}` Cline profile at install time ({now}). "
        "Do not edit by hand — re-run `install-full.sh` or `install-lite.sh`. "
        "Path-gated Cline rules are included as always-on sections with scope notes "
        "(OpenCode has no path-conditional rule loading)."
    )
    out.append("")
    out.append("---")
    out.append("")

    for path in files:
        rel = path.relative_to(rules_dir).as_posix()
        text = path.read_text(encoding="utf-8")
        meta, body = split_frontmatter(text)
        body = apply_wording(body)
        out.append(render_section(rel, meta, body))
        out.append("")
        out.append("---")
        out.append("")

    return "\n".join(out).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Concatenate a profile's .clinerules into OpenCode AGENTS.md"
    )
    parser.add_argument(
        "--rules-dir",
        required=True,
        type=Path,
        help="Path to profile .clinerules directory",
    )
    parser.add_argument(
        "--profile",
        required=True,
        help="Profile name (full or lite) for the header",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Write AGENTS.md here (default: stdout)",
    )
    parser.add_argument(
        "--count-only",
        action="store_true",
        help="Print number of rule files and exit",
    )
    args = parser.parse_args()

    rules_dir = args.rules_dir.resolve()
    if args.count_only:
        files = collect_rule_files(rules_dir) if rules_dir.is_dir() else []
        print(len(files))
        return

    content = generate(rules_dir, args.profile)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(content, encoding="utf-8")
    else:
        sys.stdout.write(content)


if __name__ == "__main__":
    main()
