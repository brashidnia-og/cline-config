#!/usr/bin/env python3
"""Architecture-first rollout tests (design guidance, reviewer role, renderers).

Source-tree invariants run directly against the repository. Installer behavior
is exercised through the real entry points with a disposable temporary HOME:

  HOME                 -> <tmp>/home
  OPENCODE_CONFIG_DIR  -> <tmp>/home/occonfig
  LLM_URL               -> dead local port (the best-effort OpenCode model
                           refresh must warn, never touch a live server)

Live user configuration is never read or written.
"""

import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MULTITOOL = ROOT / "bin" / "lib" / "multitool.py"

AGENT_MARKER = "cline-config:managed"
SKILL_DIR_MARKER = ".cline-config-managed"

PATTERN_SKILLS = {
    "adapter-pattern", "pipeline-and-chain-of-responsibility", "command-pattern",
    "observer-and-events", "composite-pattern", "idempotency-and-retries",
    "transactional-outbox", "cache-design", "dependency-injection",
}

FULL_SKILLS = {
    "architecture-review", "backend-security-audit", "bugbot-review",
    "build-3d-game-characters", "checkpointed-analysis",
    "cli-subagent-progress-logging", "database-migration", "deep-debugging",
    "decorator-pattern", "design-for-change", "derive-3d-character-specs", "frontend-engineering",
    "frontend-security-audit", "game-performance-profiling",
    "game-reference-to-spec", "gameplay-code-quality", "godot-game-development",
    "persistent-analysis-store", "polymorphism-and-strategy",
    "security-audit-core", "smart-contract-security-audit", "state-machine-design",
    "subagent-model-routing", "test-engineering", "vulnerability-research",
} | PATTERN_SKILLS
LITE_SKILLS = {
    "change-planning", "checkpointed-analysis",
    "cli-subagent-progress-logging", "decorator-pattern", "deep-debugging", "design-for-change",
    "persistent-analysis-store", "polymorphism-and-strategy", "state-machine-design",
    "subagent-model-routing",
} | PATTERN_SKILLS
FULL_AGENTS = [
    "explore", "general", "planner", "architecture-reviewer",
    "code-reviewer", "security-auditor", "debugger", "test-runner",
    "verifier", "docs-writer", "bash", "browser-tester", "scout",
    "orchestrator", "db-reader", "character-art-reviewer",
    "game-performance-reviewer",
]
LITE_AGENTS = ["explore", "planner", "debugger", "general",
               "code-reviewer", "orchestrator", "scout"]
FULL_ONLY_AGENTS = sorted(set(FULL_AGENTS) - set(LITE_AGENTS))
SHARED_SKILLS = [
    "checkpointed-analysis", "cli-subagent-progress-logging",
    "decorator-pattern", "design-for-change", "persistent-analysis-store",
    "polymorphism-and-strategy", "state-machine-design", "subagent-model-routing",
    *sorted(PATTERN_SKILLS),
]
HANDOFF_FIELDS = [
    "schema_version", "task_id", "role", "mode", "objective", "depends_on",
    "design_ref", "context", "owned_files", "contracts_and_invariants",
    "architecture_decisions", "acceptance", "validation_commands",
    "model_selection", "budgets", "escalate_if", "response",
]


def load_multitool():
    spec = importlib.util.spec_from_file_location("cline_config_multitool", MULTITOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def frontmatter_values(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    values = {}
    if not lines or lines[0].strip() != "---":
        return values
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" in line:
            key, value = line.split(":", 1)
            values[key.strip()] = value.strip()
    return values


class SourceTreeTests(unittest.TestCase):
    """Invariants of the profile sources themselves (no install required)."""

    def test_shared_skill_trees_are_byte_identical(self):
        for skill in SHARED_SKILLS:
            full = ROOT / "full" / ".cline" / "skills" / skill
            lite = ROOT / "lite" / ".cline" / "skills" / skill
            self.assertTrue(full.is_dir(), f"full copy missing: {skill}")
            self.assertTrue(lite.is_dir(), f"lite copy missing: {skill}")
            for source in sorted(p for p in full.rglob("*") if p.is_file()):
                relative = source.relative_to(full)
                counterpart = lite / relative
                self.assertTrue(counterpart.is_file(),
                                f"{skill}: {relative} missing from lite copy")
                self.assertEqual(
                    source.read_bytes(), counterpart.read_bytes(),
                    f"{skill}: {relative} differs between full and lite")

    def test_intended_skill_membership(self):
        full_tree = ROOT / "full" / ".cline" / "skills"
        lite_tree = ROOT / "lite" / ".cline" / "skills"
        self.assertEqual(FULL_SKILLS,
                         {p.name for p in full_tree.iterdir() if (p / "SKILL.md").is_file()})
        self.assertEqual(LITE_SKILLS,
                         {p.name for p in lite_tree.iterdir() if (p / "SKILL.md").is_file()})
        self.assertEqual(34, len(FULL_SKILLS))
        self.assertEqual(19, len(LITE_SKILLS))

    def test_pattern_links_and_evaluation_scenarios(self):
        for profile in ("full", "lite"):
            tree = ROOT / profile / ".cline" / "skills"
            for name in sorted(PATTERN_SKILLS | {"design-for-change", "decorator-pattern"}):
                source = tree / name
                data = json.loads((source / "evals" / "evals.json").read_text())
                self.assertEqual(name, data["skill_name"])
                self.assertEqual([1, 2], [item["id"] for item in data["evals"]])
                for scenario in data["evals"]:
                    self.assertTrue(scenario["prompt"])
                    self.assertTrue(scenario["expected_output"])
                    self.assertTrue(scenario["assertions"])
                for doc in source.rglob("*.md"):
                    for target in re.findall(r"\]\(([^)]+)\)", doc.read_text()):
                        if "://" not in target and not target.startswith("#"):
                            self.assertTrue((doc.parent / target.split("#", 1)[0]).is_file(),
                                            f"broken link in {doc}: {target}")

    def test_intended_agent_membership(self):
        full_list = [x for x in (ROOT / "agents" / "full.list").read_text().splitlines() if x.strip()]
        lite_list = [x for x in (ROOT / "agents" / "lite.list").read_text().splitlines() if x.strip()]
        self.assertEqual(FULL_AGENTS, full_list)
        self.assertEqual(LITE_AGENTS, lite_list)
        self.assertEqual(FULL_ONLY_AGENTS, sorted(set(FULL_AGENTS) - set(LITE_AGENTS)))
        self.assertIn("architecture-reviewer", full_list)
        self.assertNotIn("architecture-reviewer", lite_list)
        for profile_list in (full_list, lite_list):
            for agent_id in profile_list:
                catalog = ROOT / "agents" / "catalog" / f"{agent_id}.md"
                self.assertTrue(catalog.is_file(), f"catalog missing for {agent_id}")
                # Catalog files carry description/readonly/shell; the name is
                # the file stem (the renderers derive it from the id).
                self.assertTrue(frontmatter_values(catalog).get("description"),
                                f"catalog missing description: {agent_id}")

    def test_architecture_reviewer_is_readonly_and_shell_free(self):
        meta = frontmatter_values(ROOT / "agents" / "catalog" / "architecture-reviewer.md")
        self.assertEqual("true", meta.get("readonly"))
        self.assertEqual("false", meta.get("shell"))
        self.assertTrue(meta.get("description"))

    def test_handoff_schema_fields(self):
        for profile in ("full", "lite"):
            handoff = ROOT / profile / ".cline" / "skills" / "design-for-change" / "references" / "design-handoff.md"
            text = handoff.read_text(encoding="utf-8")
            for field in HANDOFF_FIELDS:
                self.assertIn(field, text, f"{profile} handoff missing field: {field}")
            for anchor in ("base:", "revision:", "worktree:"):
                self.assertIn(anchor, text, f"{profile} handoff missing base-identity anchor: {anchor}")
            self.assertIn("primary", text, "handoff must keep canonical state single-writer")

    def test_routing_wiring(self):
        full_core = (ROOT / "full" / ".clinerules" / "00-core-global.md").read_text()
        lite_core = (ROOT / "lite" / ".clinerules" / "00-core-global.md").read_text()
        full_style = (ROOT / "full" / ".clinerules" / "50-code-style-architecture.md").read_text()
        for phrase in ("Ownership and state", "Model and effort selection",
                       "Unavailable roles", "serial by default",
                       "explicitly selected model"):
            self.assertIn(phrase, full_core, f"full core rules lost: {phrase}")
        for phrase in ("Design routing", "serial", "explicitly selected model",
                       "not installed"):
            self.assertIn(phrase, lite_core, f"lite core rules lost: {phrase}")
        for phrase in ("Design routing", "design-for-change", "decorator-pattern",
                       "polymorphism-and-strategy", "architecture-review"):
            self.assertIn(phrase, full_style, f"full style rules lost: {phrase}")

        review = (ROOT / "full" / ".cline" / "skills" / "architecture-review" / "SKILL.md").read_text()
        for phrase in ("design-for-change", "references/design-handoff.md",
                       "@architecture-reviewer"):
            self.assertIn(phrase, review, f"architecture-review lost: {phrase}")

        planning = (ROOT / "lite" / ".cline" / "skills" / "change-planning" / "SKILL.md").read_text()
        for phrase in ("design-for-change", "references/design-handoff.md",
                       "polymorphism-and-strategy"):
            self.assertIn(phrase, planning, f"change-planning lost: {phrase}")

        for profile in ("full", "lite"):
            routing = (ROOT / profile / ".cline" / "skills" / "subagent-model-routing" / "SKILL.md").read_text()
            for phrase in ("Explicit selection wins", "serial by default", "schema_version"):
                self.assertIn(phrase, routing, f"{profile} subagent-model-routing lost: {phrase}")
        design = (ROOT / "full" / ".cline" / "skills" / "design-for-change" / "SKILL.md").read_text()
        for phrase in ("references/design-handoff.md", "polymorphism-and-strategy", "decorator-pattern"):
            self.assertIn(phrase, design, f"design-for-change lost: {phrase}")
        self.assertIn("decorator-pattern", lite_core)
        for name in PATTERN_SKILLS:
            self.assertIn(name, design, f"design-for-change missing focused route: {name}")
            self.assertIn(name, full_style, f"full style missing focused route: {name}")
        self.assertIn("references/construction.md", design)
        self.assertIn("Factory/Builder/composition-root", lite_core)

    def test_lite_skills_do_not_require_full_only_roles(self):
        # Shared skills are byte-identical between profiles, so they may
        # MENTION full-only roles — but only as optional delegation targets
        # inside a skill that delegates its execution mode to 00-core-global,
        # whose lite version performs uninstalled roles inline (Solo fallback).
        # A hard dependency would fail the lite acceptance criterion.
        lite_core = (ROOT / "lite" / ".clinerules" / "00-core-global.md").read_text()
        self.assertIn("not installed", lite_core,
                       "lite core must define the Solo fallback for uninstalled roles")
        lite_tree = ROOT / "lite" / ".cline" / "skills"
        for skill_dir in sorted(lite_tree.iterdir()):
            if not (skill_dir / "SKILL.md").is_file():
                continue
            for path in skill_dir.rglob("*.md"):
                text = path.read_text(encoding="utf-8")
                mentions = [a for a in FULL_ONLY_AGENTS if f"@{a}" in text]
                if mentions:
                    self.assertIn("00-core-global", text,
                                    f"{skill_dir.name}: full-only roles {mentions} referenced "
                                    f"without delegating execution modes to 00-core-global")

    def test_all_skill_frontmatter_is_opencode_valid(self):
        import re
        name_re = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
        for profile in ("full", "lite"):
            tree = ROOT / profile / ".cline" / "skills"
            for skill_dir in sorted(p for p in tree.iterdir() if p.is_dir()):
                skill_md = skill_dir / "SKILL.md"
                self.assertTrue(skill_md.is_file(), f"{profile}: {skill_dir.name} missing SKILL.md")
                lines = skill_md.read_text(encoding="utf-8").splitlines()
                self.assertEqual("---", lines[0].strip(), f"{profile}: {skill_dir.name} missing frontmatter")
                close = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
                self.assertIsNotNone(close, f"{profile}: {skill_dir.name} frontmatter not closed")
                meta = frontmatter_values(skill_md)
                self.assertEqual(skill_dir.name, meta.get("name"),
                                  f"{profile}: {skill_dir.name} frontmatter name mismatch")
                self.assertTrue(name_re.match(skill_dir.name),
                                 f"{profile}: {skill_dir.name} not OpenCode-safe")
                description = meta.get("description", "")
                self.assertTrue(description, f"{profile}: {skill_dir.name} missing description")
                self.assertLessEqual(len(description), 1024,
                                      f"{profile}: {skill_dir.name} description exceeds 1024 chars")

    def test_rendered_rules_retain_ownership_and_model_precedence(self):
        multitool = load_multitool()
        for profile in ("full", "lite"):
            for tool in ("Codex", "Claude Code", "Hermes"):
                rendered = multitool.render_rules(profile, tool)
                self.assertIn("explicitly selected model", rendered, f"{profile}/{tool}")
                self.assertIn("serial by default", rendered, f"{profile}/{tool}")
                self.assertIn("canonical durable state", rendered, f"{profile}/{tool}")
                self.assertIn("solo", rendered, f"{profile}/{tool}")
                self.assertIn("perform that step", rendered, f"{profile}/{tool}")


class ShellRendererTests(unittest.TestCase):
    """Real installer entry points against a disposable HOME."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cline-config-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.project = self.root / "project"
        self.home.mkdir()
        self.project.mkdir()
        self.env = dict(os.environ)
        self.env["HOME"] = str(self.home)
        self.env["LLM_URL"] = "http://127.0.0.1:1/"
        self.env["OPENCODE_CONFIG_DIR"] = str(self.home / "occonfig")

    def run_installer(self, profile, *args):
        script = ROOT / "bin" / f"install-{profile}.sh"
        return subprocess.run(
            ["bash", str(script), *args], env=self.env,
            capture_output=True, text=True, timeout=300)

    def snapshot_tree(self):
        snapshot = {}
        for path in sorted(self.home.rglob("*")):
            relative = path.relative_to(self.home)
            if path.is_file():
                snapshot[str(relative)] = ("file", path.read_bytes())
            else:
                snapshot[str(relative)] = ("dir", b"")
        return snapshot

    def assert_state_machine_installed(self, profile):
        source = ROOT / profile / ".cline" / "skills" / "state-machine-design"
        destinations = (
            self.home / ".cline" / "skills",
            self.home / "occonfig" / "skills",
            self.home / ".cursor" / "skills",
            self.home / ".agents" / "skills",
            self.home / ".claude" / "skills",
            self.home / ".hermes" / "skills" / "cline-config",
        )
        for destination in destinations:
            installed = destination / "state-machine-design"
            with self.subTest(profile=profile, destination=destination):
                self.assertEqual("state-machine-design",
                                 frontmatter_values(installed / "SKILL.md").get("name"))
                for reference in (source / "references").glob("*.md"):
                    self.assertEqual(reference.read_bytes(),
                                     (installed / "references" / reference.name).read_bytes())

    def assert_pattern_skills_installed(self, profile):
        destinations = (
            self.home / ".cline" / "skills",
            self.home / "occonfig" / "skills",
            self.home / ".cursor" / "skills",
            self.home / ".agents" / "skills",
            self.home / ".claude" / "skills",
            self.home / ".hermes" / "skills" / "cline-config",
        )
        for name in sorted(PATTERN_SKILLS | {"decorator-pattern", "design-for-change"}):
            source = ROOT / profile / ".cline" / "skills" / name
            for destination in destinations:
                installed = destination / name
                with self.subTest(profile=profile, skill=name, destination=destination):
                    self.assertEqual(name,
                                     frontmatter_values(installed / "SKILL.md").get("name"))
                    for resource in source.rglob("*"):
                        if resource.is_file() and resource.name != "SKILL.md":
                            self.assertEqual(resource.read_bytes(),
                                             (installed / resource.relative_to(source)).read_bytes())

    def test_full_install_installs_new_role_and_shared_skills(self):
        (self.home / ".cursor" / "agents").mkdir(parents=True)
        personal = self.home / ".cursor" / "agents" / "planner.md"
        personal.write_text("personal cursor planner\n")
        (self.home / "occonfig" / "agents").mkdir(parents=True)
        personal_opencode = self.home / "occonfig" / "agents" / "planner.md"
        personal_opencode.write_text("personal OpenCode planner\n")

        result = self.run_installer("full", "--skip-mcp")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

        cursor_agents = self.home / ".cursor" / "agents"
        cursor_files = list(cursor_agents.glob("*.md"))
        self.assertEqual(17, len(cursor_files),
                         "full profile: 17 Cursor agents (16 managed + 1 personal)")
        marked = [p for p in cursor_files if AGENT_MARKER in p.read_text()]
        self.assertEqual(16, len(marked), "personal unmarked agent must survive, not be replaced")
        arch = cursor_agents / "architecture-reviewer.md"
        self.assertTrue(arch.exists(), "architecture-reviewer agent not installed for Cursor")
        self.assertIn(AGENT_MARKER, arch.read_text())
        self.assertIn("readonly: true", arch.read_text())
        self.assertEqual("personal cursor planner\n", personal.read_text(),
                         "unmarked personal Cursor agent was overwritten")
        self.assertIn("preserved personal agent", result.stdout)

        oc_agents = self.home / "occonfig" / "agents"
        self.assertEqual(17, len(list(oc_agents.glob("*.md"))))
        marked_opencode = [p for p in oc_agents.glob("*.md")
                           if AGENT_MARKER in p.read_text()]
        self.assertEqual(16, len(marked_opencode),
                         "unmarked OpenCode agent must survive, not be replaced")
        self.assertEqual("personal OpenCode planner\n", personal_opencode.read_text())
        arch_oc = oc_agents / "architecture-reviewer.md"
        self.assertTrue(arch_oc.exists())
        arch_text = arch_oc.read_text()
        self.assertIn("edit: deny", arch_text)
        self.assertIn("bash: deny", arch_text)
        self.assertIn(AGENT_MARKER, arch_text)

        oc_skills = self.home / "occonfig" / "skills"
        self.assertEqual(34, len([p for p in oc_skills.iterdir() if p.is_dir()]))
        self.assertTrue((oc_skills / "design-for-change" / "references" / "design-handoff.md").is_file())
        self.assertTrue((self.home / ".cline" / "skills" / "polymorphism-and-strategy" / "SKILL.md").is_file())

        cursor_skills = self.home / ".cursor" / "skills"
        managed = [p for p in cursor_skills.iterdir()
                   if p.is_dir() and (p / SKILL_DIR_MARKER).is_file()]
        self.assertEqual(21, len(managed), "full Cursor = 6 game + 15 shared skills")
        for name in ("design-for-change", "polymorphism-and-strategy",
                     "state-machine-design", "subagent-model-routing", "cli-subagent-progress-logging"):
            self.assertTrue((cursor_skills / name / "SKILL.md").is_file(),
                            f"shared Cursor skill missing: {name}")
        self.assertTrue((cursor_skills / "design-for-change" / "references" / "design-examples.md").is_file())
        self.assert_state_machine_installed("full")
        self.assert_pattern_skills_installed("full")

        self.assertTrue((self.home / "occonfig" / "AGENTS.md").is_file())
        self.assertIn("cline-config:generated",
                      (self.home / "occonfig" / "AGENTS.md").read_text())
        agents_md = (self.home / "occonfig" / "AGENTS.md").read_text()
        self.assertIn("explicitly selected model", agents_md)
        self.assertIn("serial by default", agents_md)

    def test_profile_switch_removes_full_only_role_and_keeps_personal(self):
        (self.home / ".cursor" / "agents").mkdir(parents=True)
        personal = self.home / ".cursor" / "agents" / "planner.md"
        personal.write_text("personal cursor planner\n")
        self.assertEqual(0, self.run_installer("full", "--skip-mcp").returncode)
        result = self.run_installer("lite", "--skip-mcp")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

        cursor_agents = self.home / ".cursor" / "agents"
        self.assertFalse((cursor_agents / "architecture-reviewer.md").exists(),
                         "full-only agent must be removed on lite switch")
        cursor_files = list(cursor_agents.glob("*.md"))
        self.assertEqual(7, len(cursor_files),
                         "lite profile: 7 Cursor agents (6 managed + 1 personal)")
        marked = [p for p in cursor_files if AGENT_MARKER in p.read_text()]
        self.assertEqual(6, len(marked))
        self.assertEqual("personal cursor planner\n", personal.read_text(),
                         "personal agent was touched by the profile switch")

        oc_agents = self.home / "occonfig" / "agents"
        self.assertEqual(7, len(list(oc_agents.glob("*.md"))))
        self.assertFalse((oc_agents / "architecture-reviewer.md").exists())
        self.assertEqual(19, len([p for p in (self.home / "occonfig" / "skills").iterdir() if p.is_dir()]))

        cursor_skills = self.home / ".cursor" / "skills"
        managed = [p.name for p in cursor_skills.iterdir()
                   if p.is_dir() and (p / SKILL_DIR_MARKER).is_file()]
        self.assertEqual(15, len(managed), "lite keeps exactly the shared Cursor skills")
        for game_skill in ("gameplay-code-quality", "godot-game-development",
                           "game-performance-profiling", "build-3d-game-characters",
                           "game-reference-to-spec", "derive-3d-character-specs"):
            self.assertFalse((cursor_skills / game_skill).exists(),
                             f"managed game skill must be removed on lite: {game_skill}")
        for shared in ("design-for-change", "polymorphism-and-strategy",
                       "state-machine-design", "subagent-model-routing", "cli-subagent-progress-logging"):
            self.assertIn(shared, managed, f"shared skill must survive lite: {shared}")
        self.assert_state_machine_installed("lite")
        self.assert_pattern_skills_installed("lite")

    def test_dry_run_does_not_mutate(self):
        result = self.run_installer("full", "--skip-mcp")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        before = self.snapshot_tree()
        result = self.run_installer("full", "-n", "--skip-mcp")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(before, self.snapshot_tree(), "dry run must not change any file")

    def test_cursor_downgrade_cleanup_preserves_personal_directories(self):
        skills = self.home / ".cursor" / "skills"
        skills.mkdir(parents=True)
        personal_design = skills / "design-for-change"
        personal_design.mkdir()
        (personal_design / "SKILL.md").write_text("personal design-for-change\n")
        personal_other = skills / "my-personal-skill"
        personal_other.mkdir()
        (personal_other / "SKILL.md").write_text("personal other\n")

        result = self.run_installer("full", "--skip-mcp")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("personal design-for-change\n",
                         (personal_design / "SKILL.md").read_text(),
                         "installer must not overwrite an unmarked personal skill")
        self.assertTrue((skills / "polymorphism-and-strategy" / SKILL_DIR_MARKER).is_file())
        self.assertTrue((skills / "subagent-model-routing" / SKILL_DIR_MARKER).is_file())

        script = ROOT / "bin" / "cursor-shared-skill-cleanup.sh"

        dry = subprocess.run(["bash", str(script), "-n", str(skills)],
                             env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(0, dry.returncode, dry.stdout + dry.stderr)
        self.assertTrue((skills / "polymorphism-and-strategy" / SKILL_DIR_MARKER).is_file(),
                        "dry-run cleanup must not delete")
        self.assertIn("would remove", dry.stdout)

        real = subprocess.run(["bash", str(script), str(skills)],
                             env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(0, real.returncode, real.stdout + real.stderr)
        self.assertTrue(personal_design.exists(), "unmarked personal skill must survive cleanup")
        self.assertEqual("personal design-for-change\n",
                         (personal_design / "SKILL.md").read_text())
        self.assertTrue(personal_other.exists(), "unrelated personal skill must survive cleanup")
        self.assertFalse((skills / "polymorphism-and-strategy").exists())
        self.assertFalse((skills / "subagent-model-routing").exists())
        self.assertTrue((skills / "cli-subagent-progress-logging").exists(),
                        "cleanup must not touch skills outside its explicit design allowlist")
        self.assertFalse((skills / "state-machine-design").exists())
        self.assertFalse((skills / "decorator-pattern").exists())
        for name in PATTERN_SKILLS:
            self.assertFalse((skills / name).exists(), f"managed pattern skill not cleaned up: {name}")

    def test_personal_state_machine_skill_survives_install_and_cleanup(self):
        destinations = (
            self.home / ".cursor" / "skills",
            self.home / ".agents" / "skills",
            self.home / ".claude" / "skills",
            self.home / ".hermes" / "skills" / "cline-config",
        )
        for destination in destinations:
            personal = destination / "state-machine-design"
            personal.mkdir(parents=True)
            (personal / "SKILL.md").write_text("personal state machine skill\n")
        for profile in ("full", "lite"):
            result = self.run_installer(profile, "--skip-mcp")
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            for destination in destinations:
                personal = destination / "state-machine-design"
                self.assertEqual("personal state machine skill\n", (personal / "SKILL.md").read_text())
                self.assertFalse((personal / SKILL_DIR_MARKER).exists())
        cleanup = subprocess.run(
            ["bash", str(ROOT / "bin" / "cursor-shared-skill-cleanup.sh"),
             str(self.home / ".cursor" / "skills")],
            env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(0, cleanup.returncode, cleanup.stdout + cleanup.stderr)
        self.assertEqual("personal state machine skill\n",
                         (destinations[0] / "state-machine-design" / "SKILL.md").read_text())

    def test_opencode_project_install_reports_mismatch_and_keeps_global(self):
        stale = self.home / "occonfig" / "skills" / "subagent-model-routing"
        stale.mkdir(parents=True)
        (stale / "SKILL.md").write_text("stale global copy\n")

        result = self.run_installer("lite", "--project", str(self.project), "--skip-mcp")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("MISMATCH", result.stdout)
        self.assertIn("subagent-model-routing", result.stdout)
        self.assertEqual("stale global copy\n", (stale / "SKILL.md").read_text(),
                         "project install must never overwrite the global copy")
        project_skills = self.project / ".opencode" / "skills"
        self.assertFalse((project_skills / "subagent-model-routing").exists(),
                         "mismatched global skill must not be duplicated into the project")
        self.assertTrue((project_skills / "change-planning" / "SKILL.md").is_file(),
                         "non-conflicting project skills are still installed")
        self.assertTrue((self.project / "AGENTS.md").is_file())

    def test_opencode_project_install_skips_identical_global_without_warning(self):
        global_dir = self.home / "occonfig" / "skills"
        global_dir.mkdir(parents=True)
        shutil.copytree(ROOT / "lite" / ".cline" / "skills" / "subagent-model-routing",
                        global_dir / "subagent-model-routing")

        result = self.run_installer("lite", "--project", str(self.project), "--skip-mcp")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertNotIn("MISMATCH", result.stdout)
        self.assertIn("identical copy already in", result.stdout)
        self.assertFalse((self.project / ".opencode" / "skills" / "subagent-model-routing").exists())


class PythonRendererTests(unittest.TestCase):
    """Codex/Claude/Hermes renderer through multitool.py in a disposable HOME."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cline-config-ptest-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = dict(os.environ)
        self.env["HOME"] = str(self.home)

    def run_multitool(self, profile, *args):
        return subprocess.run(
            [sys.executable, str(MULTITOOL), "install", "--profile", profile, *args],
            env=self.env, capture_output=True, text=True, timeout=120)

    def test_profile_switch_preserves_personal_content(self):
        (self.home / ".claude" / "agents").mkdir(parents=True)
        claude_personal = self.home / ".claude" / "agents" / "planner.md"
        claude_personal.write_text("# personal claude planner\n")
        (self.home / ".codex" / "agents").mkdir(parents=True)
        codex_personal = self.home / ".codex" / "agents" / "general.toml"
        codex_personal.write_text('# personal\nname = "general"\n')
        private_skill = self.home / ".agents" / "skills" / "private-skill"
        private_skill.mkdir(parents=True)
        (private_skill / "SKILL.md").write_text("private\n")

        result = self.run_multitool("full")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

        codex_agents = self.home / ".codex" / "agents"
        self.assertEqual(17, len(list(codex_agents.glob("*.toml"))))
        self.assertEqual('# personal\nname = "general"\n', codex_personal.read_text(),
                         "unmarked personal Codex agent was overwritten")
        self.assertIn(AGENT_MARKER, (codex_agents / "architecture-reviewer.toml").read_text())

        claude_agents = self.home / ".claude" / "agents"
        self.assertEqual(17, len(list(claude_agents.glob("*.md"))))
        self.assertEqual("# personal claude planner\n", claude_personal.read_text(),
                         "unmarked personal Claude agent was overwritten")
        self.assertIn(AGENT_MARKER, (claude_agents / "architecture-reviewer.md").read_text())

        self.assertEqual("private\n", (private_skill / "SKILL.md").read_text())
        self.assertEqual(35, len(list((self.home / ".agents" / "skills").glob("*/SKILL.md"))))

        delegation = (self.home / ".hermes" / "skills" / "cline-config-delegation" / "SKILL.md").read_text()
        self.assertIn("## architecture-reviewer", delegation)
        for tool, rules_name in (("codex", "AGENTS.md"), ("claude", "CLAUDE.md")):
            rules = (self.home / f".{tool}" / rules_name).read_text()
            self.assertIn("explicitly selected model", rules)
            self.assertIn("serial by default", rules)

        result = self.run_multitool("lite")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual(7, len(list(codex_agents.glob("*.toml"))))
        self.assertFalse((codex_agents / "architecture-reviewer.toml").exists())
        self.assertEqual(7, len(list(claude_agents.glob("*.md"))))
        self.assertFalse((claude_agents / "architecture-reviewer.md").exists())
        self.assertEqual('# personal\nname = "general"\n', codex_personal.read_text())
        self.assertEqual("# personal claude planner\n", claude_personal.read_text())
        self.assertEqual("private\n", (private_skill / "SKILL.md").read_text())
        self.assertNotIn("## architecture-reviewer",
                         (self.home / ".hermes" / "skills" / "cline-config-delegation" / "SKILL.md").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)
