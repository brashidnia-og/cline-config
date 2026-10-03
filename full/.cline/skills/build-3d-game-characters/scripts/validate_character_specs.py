#!/usr/bin/env python3
"""Validate the image-to-3D handoff without imposing one game's art choices."""

import json
import re
import sys
from pathlib import Path


def validate(path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"cannot read JSON: {exc}"]

    errors = []
    if not isinstance(data, dict):
        return ["top level must be an object"]
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    source = data.get("source")
    if not isinstance(source, dict) or not source.get("image"):
        errors.append("source.image is required")
    contract = data.get("contract")
    for key in ("units", "up", "forward", "parts", "export_format", "camera_context"):
        if not isinstance(contract, dict) or not contract.get(key):
            errors.append(f"contract.{key} is required")
    characters = data.get("characters")
    if not isinstance(characters, list) or not characters:
        return errors + ["characters must be a nonempty list"]

    seen = set()
    for index, item in enumerate(characters, 1):
        prefix = f"characters[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        char_id = item.get("id")
        if not isinstance(char_id, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", char_id):
            errors.append(f"{prefix}.id must be a stable lowercase snake_case ID")
        elif char_id in seen:
            errors.append(f"{prefix}.id duplicates {char_id}")
        else:
            seen.add(char_id)
        for key in ("display_name", "source_region", "observed", "interpretations", "construction", "anchors", "uncertainties", "status"):
            if key not in item:
                errors.append(f"{prefix}.{key} is required")
        if not isinstance(item.get("observed"), list) or not item["observed"]:
            errors.append(f"{prefix}.observed must contain visible evidence")
        if not isinstance(item.get("interpretations"), list):
            errors.append(f"{prefix}.interpretations must be a list (possibly empty)")
        if not isinstance(item.get("uncertainties"), list):
            errors.append(f"{prefix}.uncertainties must be a list (possibly empty)")
        construction = item.get("construction")
        if not isinstance(construction, dict) or not construction.get("body"):
            errors.append(f"{prefix}.construction.body is required")
        anchors = item.get("anchors")
        if not isinstance(anchors, dict) or any(not anchors.get(k) for k in ("face", "arms", "feet")):
            errors.append(f"{prefix}.anchors needs face, arms, and feet")
        if item.get("status") not in ("draft", "needs_review", "spec_ready"):
            errors.append(f"{prefix}.status must be draft, needs_review, or spec_ready")
    return errors


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: validate_character_specs.py character_specs.json")
    problems = validate(Path(sys.argv[1]))
    if problems:
        for problem in problems:
            print(f"ERROR: {problem}", file=sys.stderr)
        raise SystemExit(1)
    print("PASS: character spec handoff is structurally complete")
