#!/usr/bin/env python3
"""Install cline-config profiles into Codex, Claude Code, and Hermes."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import time
import tomllib

ROOT = Path(__file__).resolve().parents[2]
MARKER = "cline-config:managed"
SKILL_MARKER = ".cline-config-managed"
BEGIN = "# cline-config:begin mcp"
END = "# cline-config:end mcp"


def note(message):
    print(f"  {message}")


def backup(path):
    target = path.with_name(path.name + ".bak-" + time.strftime("%Y%m%d-%H%M%S"))
    shutil.copy2(path, target)
    note(f"backed up {path} -> {target}")


def write(path, content, dry):
    if path.is_file() and path.read_text(encoding="utf-8") == content:
        note(f"unchanged {path}")
        return
    note(("[dry-run] write " if dry else "wrote ") + str(path))
    if dry:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".cline-config-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(content)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def managed_file(path):
    return path.is_file() and (MARKER in path.read_text(encoding="utf-8")[:500]
                               or "cline-config:generated" in path.read_text(encoding="utf-8")[:500])


def sync_skills(source, destination, dry, tool):
    names = {p.name for p in source.iterdir() if (p / "SKILL.md").is_file()}
    if destination.exists():
        for existing in destination.iterdir():
            if existing.is_dir() and (existing / SKILL_MARKER).is_file() and existing.name not in names:
                note(("[dry-run] remove stale " if dry else "removed stale ") + str(existing))
                if not dry:
                    shutil.rmtree(existing)
    for skill in sorted(names):
        src, target = source / skill, destination / skill
        if target.exists() and not (target / SKILL_MARKER).is_file():
            note(f"preserved personal skill {target}")
            continue
        note(("[dry-run] sync " if dry else "synced ") + f"{src} -> {target}")
        if dry:
            continue
        destination.mkdir(parents=True, exist_ok=True)
        staged = Path(tempfile.mkdtemp(prefix=f".{skill}-", dir=destination))
        shutil.copytree(src, staged, dirs_exist_ok=True)
        skill_file = staged / "SKILL.md"
        skill_text = skill_file.read_text(encoding="utf-8")
        guide = ("\nTool adaptation: Follow the installed tool-specific core instructions when this skill says "
                 "`00-core-global`. Use named custom agents for `@role` references when available; "
                 "otherwise perform that step on the primary.\n")
        if tool == "Hermes":
            guide = ("\nHermes adaptation: `00-core-global` refers to project `AGENTS.md` when present. "
                     "For `@role` references, read `cline-config-delegation` and pass the named role's "
                     "instructions as context to `delegate_task`; perform the step yourself if delegation "
                     "is unavailable.\n")
        split = skill_text.find("\n---", 4)
        if split >= 0:
            skill_text = skill_text[:split + 4] + "\n" + guide + skill_text[split + 4:]
            skill_file.write_text(skill_text, encoding="utf-8")
        (staged / SKILL_MARKER).write_text("Managed by cline-config.\n")
        if target.exists():
            shutil.rmtree(target)
        staged.rename(target)


def split_agent(path):
    raw = path.read_text(encoding="utf-8")
    front, body = raw.split("---", 2)[1:]
    meta = {}
    for line in front.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            meta[key.strip()] = value.strip()
    return meta, body.strip()


def sync_agents(profile, destination, kind, dry):
    ids = [line.strip() for line in (ROOT / "agents" / f"{profile}.list").read_text().splitlines()
           if line.strip() and not line.lstrip().startswith("#")]
    if len(ids) != len(set(ids)):
        raise ValueError(f"duplicate agent in {profile}.list")
    ext = ".toml" if kind == "codex" else ".md"
    if destination.exists():
        for old in destination.glob("*" + ext):
            if managed_file(old) and old.stem not in ids:
                note(("[dry-run] remove stale " if dry else "removed stale ") + str(old))
                if not dry:
                    old.unlink()
    for agent_id in ids:
        meta, body = split_agent(ROOT / "agents" / "catalog" / f"{agent_id}.md")
        readonly = meta.get("readonly", "true").lower() == "true"
        shell = meta.get("shell", "false").lower() == "true"
        description = meta.get("description", agent_id)
        if kind == "codex":
            if not shell:
                body = "Do not run shell commands.\n\n" + body
            content = (f"# {MARKER}\nname = {json.dumps(agent_id)}\n"
                       f"description = {json.dumps(description)}\n"
                       + ("sandbox_mode = \"read-only\"\n" if readonly and not shell else "")
                       + f"developer_instructions = {json.dumps(body + chr(10))}\n")
        else:
            # Claude's tools field is an allowlist; Bash is omitted for shell=false.
            tools = "Read, Glob, Grep" + (", Bash" if shell else "")
            if not readonly:
                tools += ", Edit, Write"
            content = (f"---\nname: {agent_id}\ndescription: {json.dumps(description)}\n"
                       f"tools: {tools}\nmodel: inherit\n---\n\n<!-- {MARKER} -->\n\n{body}\n")
        target = destination / (agent_id + ext)
        if target.exists() and not managed_file(target):
            note(f"preserved personal agent {target}")
            continue
        write(target, content, dry)


def render_rules(profile, tool):
    rules = ROOT / profile / ".clinerules"
    core = (rules / "00-core-global.md").read_text(encoding="utf-8")
    start = core.index("## Skill execution (subagents)")
    following = core.index("\n## ", start + 3)
    intro = core[:start].replace("You are running through Cline with a local model.",
                                 f"You are running through {tool}.")
    intro = intro.replace("Assume the model is capable but more context-limited and less reliable than a frontier hosted model. ", "")
    if tool == "Hermes":
        delegation = ("## Skill execution (subagents)\n\nSkills run on the primary. "
                      "When useful, use `delegate_task` with a specific goal, context, and role from "
                      "the `cline-config-delegation` skill. Keep decisions and final verification on the primary. "
                      "If delegation is unavailable or the user says solo, perform the steps yourself.\n")
    else:
        delegation = ("## Skill execution (subagents)\n\nSkills run on the primary. "
                      "Use the installed named agents for focused tasks when useful; give each an explicit scope. "
                      "Keep decisions and final verification on the primary. "
                      "If agents are unavailable or the user says solo, perform the steps yourself.\n")
    core = intro + delegation + core[following:]
    pieces = [core]
    for rule in sorted(rules.rglob("*.md")):
        if rule.name == "00-core-global.md":
            continue
        raw = rule.read_text(encoding="utf-8")
        paths = []
        if raw.startswith("---\n"):
            _, front, raw = raw.split("---", 2)
            paths = re.findall(r"^\s*-\s+([^\n]+)", front, re.M)
        if paths and tool == "Claude Code":
            continue
        if paths:
            pieces.append("Apply this section only when work matches: " + ", ".join(paths) + ".\n")
        pieces.append(raw.strip())
    return f"<!-- {MARKER} profile={profile} tool={tool} -->\n\n" + "\n\n".join(pieces) + "\n"


def sync_rules(profile, root, tool, dry, force=False):
    target = (root / "CLAUDE.md") if tool == "Claude Code" else (root / "AGENTS.md")
    replace_main = True
    if target.exists() and not managed_file(target):
        if not force:
            note(f"preserved personal rules {target} (use --force to replace)")
            replace_main = False
        elif dry:
            note(f"[dry-run] back up personal rules {target}")
        else:
            backup(target)
    if replace_main:
        write(target, render_rules(profile, tool), dry)
    if tool == "Claude Code":
        source = ROOT / profile / ".clinerules"
        destination = root / ".claude" / "rules" if root.name != ".claude" else root / "rules"
        selected = set()
        for rule in sorted(source.rglob("*.md")):
            raw = rule.read_text(encoding="utf-8")
            if not raw.startswith("---\n"):
                continue
            _, front, body = raw.split("---", 2)
            if not re.search(r"^paths:", front, re.M):
                continue
            name = "cline-config-" + rule.stem + ".md"
            selected.add(name)
            output = "---" + front + "---\n\n<!-- " + MARKER + " -->\n\n" + body.lstrip()
            dest = destination / name
            if dest.exists() and not managed_file(dest):
                note(f"preserved personal rule {dest}")
            else:
                write(dest, output, dry)
        if destination.exists():
            for old in destination.glob("cline-config-*.md"):
                if old.name not in selected and managed_file(old):
                    note(("[dry-run] remove stale " if dry else "removed stale ") + str(old))
                    if not dry:
                        old.unlink()


def hermes_role_skill(profile, root, dry):
    ids = [x.strip() for x in (ROOT / "agents" / f"{profile}.list").read_text().splitlines() if x.strip()]
    lines = ["---", "name: cline-config-delegation", "description: Use the cline-config specialist role catalog when delegating work with Hermes delegate_task.", "---", "", "# Specialist roles", "", "When delegating, include the appropriate role instructions below in the task context. These are task roles, not Hermes profiles.", ""]
    for agent_id in ids:
        meta, body = split_agent(ROOT / "agents" / "catalog" / f"{agent_id}.md")
        lines += [f"## {agent_id}", "", meta.get("description", ""), "", body, ""]
    target = root / "skills" / "cline-config-delegation"
    if target.exists() and not (target / SKILL_MARKER).is_file():
        note(f"preserved personal skill {target}")
        return
    write(target / "SKILL.md", "\n".join(lines), dry)
    write(target / SKILL_MARKER, "Managed by cline-config.\n", dry)


def hermes_core_skill(profile, root, dry):
    target = root / "skills" / "cline-config-core"
    if target.exists() and not (target / SKILL_MARKER).is_file():
        note(f"preserved personal skill {target}")
        return
    content = ("---\nname: cline-config-core\n"
               "description: Apply the selected cline-config engineering rules and MCP routing in Hermes sessions.\n"
               "---\n\n" + render_rules(profile, "Hermes"))
    write(target / "SKILL.md", content, dry)
    write(target / SKILL_MARKER, "Managed by cline-config.\n", dry)


def remove_legacy_game_skills(parent, dry):
    if not parent.is_dir():
        return
    for target in parent.iterdir():
        if target.is_dir() and (target / SKILL_MARKER).is_file():
            note(("[dry-run] remove legacy managed " if dry else "removed legacy managed ") + str(target))
            if not dry:
                shutil.rmtree(target)


def install(args):
    src = ROOT / args.profile / ".cline" / "skills"
    home = Path.home()
    project = Path(args.project).resolve() if args.project else None
    if not args.skip_codex:
        base = project or home / ".codex"
        sync_rules(args.profile, base, "Codex", args.dry_run, args.force)
        sync_skills(src, (project / ".agents" / "skills") if project else home / ".agents" / "skills", args.dry_run, "Codex")
        sync_agents(args.profile, base / ".codex" / "agents" if project else base / "agents", "codex", args.dry_run)
        remove_legacy_game_skills((project / ".codex" / "skills") if project else home / ".codex" / "skills", args.dry_run)
    if not args.skip_claude:
        base = project or home / ".claude"
        sync_rules(args.profile, base, "Claude Code", args.dry_run, args.force)
        sync_skills(src, base / ".claude" / "skills" if project else base / "skills", args.dry_run, "Claude Code")
        sync_agents(args.profile, base / ".claude" / "agents" if project else base / "agents", "claude", args.dry_run)
    if not args.skip_hermes:
        hroot = home / ".hermes"
        if args.hermes_profile:
            hroot = hroot / "profiles" / args.hermes_profile
            if not hroot.is_dir():
                raise ValueError(f"Hermes profile does not exist: {hroot}")
        if project:
            # AGENTS.md is shared with Codex/OpenCode; avoid competing generators.
            if args.skip_codex:
                sync_rules(args.profile, project, "Hermes", args.dry_run, args.force)
            else:
                note("Hermes reads the project AGENTS.md generated for Codex")
        sync_skills(src, hroot / "skills" / "cline-config", args.dry_run, "Hermes")
        hermes_core_skill(args.profile, hroot, args.dry_run)
        hermes_role_skill(args.profile, hroot, args.dry_run)
        remove_legacy_game_skills(hroot / "skills" / "game-development", args.dry_run)


def server_entries():
    data = json.loads((ROOT / "mcp" / "cline_mcp_settings.template.json").read_text())
    return data["mcpServers"]


def converted(server, kind):
    cfg = {key: value for key, value in server.items() if key in ("command", "args", "env", "url")}
    if "env" in cfg:
        cfg["env"] = {k: v.replace("__CLINE_CONFIG_BUN_PATH__", str(Path.home() / ".bun" / "bin") + ":" + os.environ.get("PATH", "")) for k, v in cfg["env"].items()}
    if kind == "claude" and "url" in cfg:
        cfg["type"] = "http"
    if kind == "hermes":
        cfg["enabled"] = not server.get("disabled", False)
    if kind == "codex":
        cfg["enabled"] = not server.get("disabled", False)
    return cfg


def toml_scalar(value):
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, list):
        return "[" + ", ".join(toml_scalar(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{k} = {toml_scalar(v)}" for k, v in value.items()) + " }"
    return json.dumps(value)


def merge_codex_mcp(path, servers, dry):
    original = path.read_text() if path.exists() else ""
    if (BEGIN in original) != (END in original):
        raise ValueError(f"broken managed MCP markers in {path}")
    outside = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), "", original, flags=re.S)
    known = tomllib.loads(outside).get("mcp_servers", {}) if outside.strip() else {}
    blocks = []
    for name, server in servers.items():
        if name in known:
            note(f"preserved personal Codex MCP server {name}")
            continue
        cfg = converted(server, "codex")
        blocks.append(f"[mcp_servers.{json.dumps(name)}]\n" + "\n".join(f"{k} = {toml_scalar(v)}" for k, v in cfg.items()))
    merged = outside.rstrip() + "\n\n" + BEGIN + "\n" + "\n\n".join(blocks) + "\n" + END + "\n"
    tomllib.loads(merged)
    write(path, merged, dry)


def merge_claude_mcp(path, servers, dry, project=False):
    data = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(data, dict):
        raise ValueError(f"invalid Claude config root: {path}")
    entries = data.setdefault("mcpServers", {})
    for name, server in servers.items():
        if server.get("disabled"):
            continue  # Claude has no portable disabled field; opt-in is documented.
        if name in entries:
            note(f"preserved existing Claude MCP server {name}")
        else:
            entries[name] = converted(server, "claude")
    merged = json.dumps(data, indent=2) + "\n"
    if path.exists() and path.read_text() != merged and not dry:
        backup(path)
    write(path, merged, dry)


def merge_hermes_mcp(path, servers, dry):
    try:
        import yaml
    except ImportError as exc:
        raise ValueError("PyYAML is required to merge Hermes config.yaml") from exc
    data = yaml.safe_load(path.read_text()) if path.exists() else {}
    data = data or {}
    if not isinstance(data, dict):
        raise ValueError(f"invalid Hermes config root: {path}")
    entries = data.setdefault("mcp_servers", {})
    for name, server in servers.items():
        if name in entries:
            note(f"preserved existing Hermes MCP server {name}")
        else:
            entries[name] = converted(server, "hermes")
    merged = yaml.safe_dump(data, sort_keys=False)
    if path.exists() and path.read_text() != merged and not dry:
        backup(path)
    write(path, merged, dry)


def mcp(args):
    servers = server_entries()
    home = Path.home()
    project = Path(args.project).resolve() if args.project else None
    if not args.skip_codex:
        merge_codex_mcp((project / ".codex" / "config.toml") if project else home / ".codex" / "config.toml", servers, args.dry_run)
    if not args.skip_claude:
        merge_claude_mcp((project / ".mcp.json") if project else home / ".claude.json", servers, args.dry_run, bool(project))
    if not args.skip_hermes and not project:
        hroot = home / ".hermes"
        if args.hermes_profile:
            hroot = hroot / "profiles" / args.hermes_profile
        merge_hermes_mcp(hroot / "config.yaml", servers, args.dry_run)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("install", "mcp"))
    parser.add_argument("--profile", choices=("full", "lite"), default="full")
    parser.add_argument("--project")
    parser.add_argument("--hermes-profile")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--skip-codex", action="store_true")
    parser.add_argument("--skip-claude", action="store_true")
    parser.add_argument("--skip-hermes", action="store_true")
    args = parser.parse_args()
    try:
        (install if args.action == "install" else mcp)(args)
    except (ValueError, OSError, json.JSONDecodeError, tomllib.TOMLDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
