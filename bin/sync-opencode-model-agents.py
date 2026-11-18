#!/usr/bin/env python3
"""Generate model-bound OpenCode agents from the live OpenCode model catalog."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass


ROOT = Path(__file__).resolve().parents[1]
MARKER = "<!-- cline-config:model-agent:v1 -->"
NAME_LIMIT = 64
VALID_AGENT_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
# OpenCode V2 may expose a model variant with a #variant suffix.
MODEL_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]*/[A-Za-z0-9][A-Za-z0-9._+-]*(?:#[A-Za-z0-9][A-Za-z0-9._+-]*)?$")


@dataclass(frozen=True)
class Model:
    id: str
    name: str


@dataclass(frozen=True)
class AgentRole:
    id: str
    description: str
    readonly: bool
    shell: bool
    prompt: str


class SyncError(Exception):
    """Expected discovery, validation, or safe-write error."""


def parse_verbose_models(output: str) -> list[Model]:
    """Parse `opencode models --verbose` (model ID followed by JSON metadata)."""
    lines = output.splitlines()
    models: list[Model] = []
    seen: set[str] = set()
    index = 0
    while index < len(lines):
        line = lines[index].strip()
        index += 1
        if not line:
            continue
        if not MODEL_ID.fullmatch(line):
            raise SyncError(f"unexpected output from `opencode models --verbose` near: {line[:100]!r}")

        metadata_lines: list[str] = []
        while index < len(lines):
            if lines[index].lstrip().startswith("{"):
                break
            if lines[index].strip():
                raise SyncError(f"missing metadata object after model ID {line!r}")
            index += 1
        if index == len(lines):
            raise SyncError(f"missing metadata object after model ID {line!r}")

        depth = 0
        in_string = False
        escaped = False
        while index < len(lines):
            current = lines[index]
            metadata_lines.append(current)
            for char in current:
                if in_string:
                    if escaped:
                        escaped = False
                    elif char == "\\":
                        escaped = True
                    elif char == '"':
                        in_string = False
                elif char == '"':
                    in_string = True
                elif char == "{":
                    depth += 1
                elif char == "}":
                    depth -= 1
            index += 1
            if depth == 0:
                break
        if depth != 0:
            raise SyncError(f"unterminated metadata object for model {line!r}")

        try:
            metadata = json.loads("\n".join(metadata_lines))
        except json.JSONDecodeError as error:
            raise SyncError(f"invalid metadata JSON for model {line!r}: {error.msg}") from error
        if not isinstance(metadata, dict):
            raise SyncError(f"metadata for model {line!r} is not an object")
        provider = metadata.get("providerID")
        model_id = metadata.get("id")
        name = metadata.get("name")
        if not all(isinstance(value, str) and value.strip() for value in (provider, model_id, name)):
            raise SyncError(f"metadata for model {line!r} needs non-empty providerID, id, and name")
        canonical_id = f"{provider}/{model_id}"
        # Some OpenCode variant entries use the base model ID in metadata,
        # while the list entry itself includes a #variant suffix.
        if canonical_id != line and not line.startswith(canonical_id + "#"):
            raise SyncError(f"model ID {line!r} disagrees with metadata ID {canonical_id!r}")
        if line not in seen:
            models.append(Model(id=line, name=name.strip()))
            seen.add(line)

    if not models:
        raise SyncError("OpenCode returned no models; existing agents were left unchanged")
    return models


def normalized_name(value: str) -> str:
    """Normalize display-name spelling without doing fuzzy model matching."""
    return "".join(character.casefold() for character in value if character.isalnum())


def resolve_model(query: str, models: list[Model]) -> Model:
    """Resolve an exact model ID or a punctuation/case-insensitive display name."""
    exact_ids = [model for model in models if model.id == query]
    if exact_ids:
        return exact_ids[0]

    normalized_query = normalized_name(query)
    matches = [model for model in models if normalized_name(model.name) == normalized_query]
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        choices = ", ".join(model.id for model in matches)
        raise SyncError(f"model name {query!r} is ambiguous; use an exact ID: {choices}")
    raise SyncError(f"no available model matches {query!r}; use the exact display name or provider/model ID")


def read_profile_roles(profile: str) -> set[str]:
    if profile not in {"full", "lite"}:
        raise SyncError("profile must be 'full' or 'lite'")
    list_file = ROOT / "agents" / f"{profile}.list"
    try:
        return {
            line.split("#", 1)[0].strip()
            for line in list_file.read_text(encoding="utf-8").splitlines()
            if line.split("#", 1)[0].strip()
        }
    except OSError as error:
        raise SyncError(f"cannot read agent profile {list_file}: {error}") from error


def read_role(role_id: str, profile: str) -> AgentRole:
    if role_id not in read_profile_roles(profile):
        raise SyncError(f"role {role_id!r} is not installed in the {profile!r} profile")
    catalog_file = ROOT / "agents" / "catalog" / f"{role_id}.md"
    try:
        text = catalog_file.read_text(encoding="utf-8")
    except OSError as error:
        raise SyncError(f"cannot read agent role {catalog_file}: {error}") from error

    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise SyncError(f"agent role {role_id!r} has no frontmatter")
    try:
        end = next(index for index, line in enumerate(lines[1:], 1) if line.strip() == "---")
    except StopIteration as error:
        raise SyncError(f"agent role {role_id!r} has unterminated frontmatter") from error

    metadata: dict[str, str] = {}
    for line in lines[1:end]:
        if ":" in line:
            key, value = line.split(":", 1)
            metadata[key.strip()] = value.strip().strip("\"'")
    description = metadata.get("description")
    if not description:
        raise SyncError(f"agent role {role_id!r} has no description")
    readonly = metadata.get("readonly", "true").casefold() in {"true", "1", "yes"}
    shell = metadata.get("shell", "false").casefold() in {"true", "1", "yes"}
    prompt = "\n".join(lines[end + 1 :]).strip()
    if not prompt:
        raise SyncError(f"agent role {role_id!r} has an empty prompt")
    return AgentRole(role_id, description, readonly, shell, prompt)


def agent_name(role: AgentRole, model: Model) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", model.id.casefold()).strip("-")
    prefix = f"cline-model-{role.id}-"
    slug_limit = NAME_LIMIT - len(prefix) - 9
    if slug_limit < 1:
        raise SyncError(f"role name {role.id!r} is too long to create a model-bound agent")
    digest = hashlib.sha256(model.id.encode("utf-8")).hexdigest()[:8]
    slug = f"{slug[:slug_limit].rstrip('-')}-{digest}"
    name = prefix + slug
    if not VALID_AGENT_NAME.fullmatch(name):
        raise SyncError(f"generated invalid OpenCode agent name {name!r}")
    return name


def yaml_quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def render_agent(role: AgentRole, model: Model) -> tuple[str, str]:
    name = agent_name(role, model)
    description = f"{role.id} — {role.description} [model: {model.name} ({model.id})]"
    lines = [
        "---",
        f"description: {yaml_quote(description)}",
        "mode: subagent",
        f"model: {yaml_quote(model.id)}",
        # A hidden agent is omitted from OpenCode's subagent selection
        # catalog. Model-bound aliases must be visible to be routable.
        "hidden: false",
        "permissions:",
    ]
    # OpenCode V2: ordered action/resource/effect rules, not V1
    # permission.edit/bash/task. Restrict only capabilities disallowed
    # by the canonical role; defaults are otherwise supplied by OpenCode.
    if role.readonly:
        lines.extend([
            "  - action: edit",
            '    resource: "*"',
            "    effect: deny",
        ])
    if not role.shell:
        lines.extend([
            "  - action: shell",
            '    resource: "*"',
            "    effect: deny",
        ])
    # Task workers should not re-delegate by default; the orchestrator
    # role is the one whose purpose explicitly requires delegation.
    if role.id != "orchestrator":
        lines.extend([
            "  - action: subagent",
            '    resource: "*"',
            "    effect: deny",
        ])
    # No empty permissions list: the orchestrator with both capabilities
    # allowed should inherit the harness defaults.
    if lines[-1] == "permissions:":
        lines.pop()
    lines.extend([
        "---",
        "",
        MARKER,
        f"<!-- cline-config:role={role.id} model={model.id} display={model.name} -->",
        "",
        role.prompt.rstrip(),
        "",
    ])
    return name, "\n".join(lines)


def opencode_config_dir() -> Path:
    configured = os.environ.get("OPENCODE_CONFIG_DIR")
    if configured:
        return Path(configured).expanduser()
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg).expanduser() if xdg else Path.home() / ".config"
    return base / "opencode"


def discover_models() -> list[Model]:
    try:
        result = subprocess.run(
            ["opencode", "models", "--verbose"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except FileNotFoundError as error:
        raise SyncError("OpenCode CLI not found on PATH; no files were changed") from error
    except subprocess.TimeoutExpired as error:
        raise SyncError("`opencode models --verbose` timed out; no files were changed") from error
    if result.returncode != 0:
        raise SyncError(f"`opencode models --verbose` failed with exit code {result.returncode}; no files were changed")
    return parse_verbose_models(result.stdout)


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent, text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def is_owned(path: Path) -> bool:
    if path.is_symlink() or not path.is_file():
        return False
    try:
        return MARKER in path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return False


def sync_agents(
    role: AgentRole,
    models: list[Model],
    destination: Path,
    *,
    dry_run: bool,
    prune_stale: bool,
) -> tuple[list[str], list[str]]:
    rendered = [(agent_name(role, model), model, render_agent(role, model)[1]) for model in models]
    planned_paths = {destination / f"{name}.md" for name, _, _ in rendered}

    conflicts = [
        path for path in planned_paths
        if (path.exists() or path.is_symlink()) and not is_owned(path)
    ]
    if conflicts:
        paths = ", ".join(str(path) for path in sorted(conflicts))
        raise SyncError(f"personal or unowned agent file collision; nothing was written: {paths}")

    stale: list[Path] = []
    if prune_stale:
        prefix = f"cline-model-{role.id}-"
        if destination.exists():
            for path in sorted(destination.glob(f"{prefix}*.md")):
                if path not in planned_paths and is_owned(path):
                    stale.append(path)

    changed: list[str] = []
    unchanged: list[str] = []
    for name, _, content in rendered:
        path = destination / f"{name}.md"
        if path.exists() and path.read_text(encoding="utf-8") == content:
            unchanged.append(name)
            continue
        changed.append(name)
        if not dry_run:
            atomic_write(path, content)

    if stale:
        for path in stale:
            changed.append(f"remove {path.stem}")
            if not dry_run:
                path.unlink()
    return changed, unchanged


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Create model-bound OpenCode agents from `opencode models --verbose`."
    )
    parser.add_argument("--profile", choices=("full", "lite"), default="full")
    parser.add_argument("--role", default="scout", help="installed catalog role (default: scout)")
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--model", help="exact model ID or display name, e.g. 'GPT-6 Astra'")
    selection.add_argument("--all-models", action="store_true", help="bind the role to EVERY discovered model (creates many visible agents; prefer --model)")
    parser.add_argument(
        "--prune-stale",
        action="store_true",
        help="with --all-models, remove this role's owned agents for models no longer listed",
    )
    parser.add_argument("--dry-run", action="store_true", help="show planned changes without writing files")
    parser.add_argument("--list", action="store_true", help="list display-name to model-ID mappings; do not sync")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.list and (args.model is not None or args.all_models or args.prune_stale):
        parser.error("--list cannot be combined with model selection or --prune-stale")
    if not args.list and args.model is None and not args.all_models:
        parser.error("choose --model MODEL or --all-models (prefer a small explicit set)")
    if args.prune_stale and not args.all_models:
        parser.error("--prune-stale requires --all-models")
    try:
        models = discover_models()
        if args.list:
            for model in models:
                print(f"{model.name}\t{model.id}")
            return 0

        role = read_role(args.role, args.profile)
        selected = models if args.all_models else [resolve_model(args.model, models)]
        changed, unchanged = sync_agents(
            role,
            selected,
            opencode_config_dir() / "agents",
            dry_run=args.dry_run,
            prune_stale=args.prune_stale,
        )
    except SyncError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"error: file operation failed ({error}); inspect the OpenCode agents directory", file=sys.stderr)
        return 1

    action = "would change" if args.dry_run else "changed"
    print(f"{action}: {len(changed)} agent file(s); unchanged: {len(unchanged)}")
    changed_names = set(changed)
    unchanged_names = set(unchanged)
    for model in selected:
        name = agent_name(role, model)
        if name in changed_names:
            state = "write" if args.dry_run else "updated"
        elif name in unchanged_names:
            state = "unchanged"
        else:
            continue
        print(f"  {name}: {model.name} [{model.id}] ({state})")
    for name in changed:
        if name.startswith("remove "):
            print(f"  {name}")
    if not args.dry_run and changed:
        print("Restart OpenCode to load the updated agent definitions.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
