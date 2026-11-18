#!/usr/bin/env python3
"""Tests for OpenCode model-bound agent discovery and synchronization."""

import importlib.util
import json
import os
import shutil
import sys
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "sync-opencode-model-agents.py"
SPEC = importlib.util.spec_from_file_location("opencode_model_agents", SCRIPT)
model_agents = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = model_agents
SPEC.loader.exec_module(model_agents)


def model_block(provider: str, model_id: str, name: str) -> str:
    return f"{provider}/{model_id}\n" + json.dumps(
        {"providerID": provider, "id": model_id, "name": name, "options": {}},
        indent=2,
    )


class ModelParsingTests(unittest.TestCase):
    def test_verbose_models_resolves_display_names_and_keeps_variants_distinct(self):
        output = "\n".join(
            [
                model_block("openai", "gpt-6-astra", "GPT-6 Astra"),
                model_block("openai", "gpt-6-astra-fast", "GPT-6 Astra Fast"),
                model_block("openai", "gpt-6-astra-ultrafast", "GPT-6 Astra Ultrafast"),
            ]
        )
        models = model_agents.parse_verbose_models(output)

        self.assertEqual("openai/gpt-6-astra", model_agents.resolve_model("GPT-6 Astra", models).id)
        self.assertEqual("openai/gpt-6-astra-fast", model_agents.resolve_model("gpt 6 astra fast", models).id)
        self.assertEqual("openai/gpt-6-astra-ultrafast", model_agents.resolve_model("GPT-6 Astra Ultrafast", models).id)

    def test_duplicate_display_names_require_exact_id(self):
        models = [
            model_agents.Model("provider-a/model", "Researcher"),
            model_agents.Model("provider-b/model", "Researcher"),
        ]

        with self.assertRaisesRegex(model_agents.SyncError, "ambiguous"):
            model_agents.resolve_model("Researcher", models)
        self.assertEqual("provider-b/model", model_agents.resolve_model("provider-b/model", models).id)

    def test_malformed_catalog_is_rejected(self):
        with self.assertRaisesRegex(model_agents.SyncError, "disagrees"):
            model_agents.parse_verbose_models(
                "openai/gpt-6-astra\n"
                + json.dumps({"providerID": "openai", "id": "other", "name": "GPT-6 Astra"})
            )
        with self.assertRaisesRegex(model_agents.SyncError, "no models"):
            model_agents.parse_verbose_models("\n")


class AgentSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.destination = Path(self.temp.name) / "opencode" / "agents"
        self.scout = model_agents.read_role("scout", "full")
        self.astra = model_agents.Model("openai/gpt-6-astra", "GPT-6 Astra")
        self.luna = model_agents.Model("openai/gpt-6-luna", "GPT-6 Luna")

    def test_generated_agent_binds_exact_model_and_keeps_scout_permissions(self):
        name, content = model_agents.render_agent(self.scout, self.astra)

        self.assertTrue(name.startswith("cline-model-scout-openai-gpt-6-astra-"))
        self.assertIn('model: "openai/gpt-6-astra"', content)
        expected_description = (
            "scout — Researches external docs, dependencies, and upstream implementations. "
            "Use when the answer lives outside the local codebase. "
            "[model: GPT-6 Astra (openai/gpt-6-astra)]"
        )
        self.assertIn(f"description: {model_agents.yaml_quote(expected_description)}", content)
        self.assertIn("hidden: false", content)
        self.assertIn("permissions:", content)
        self.assertIn("  - action: edit", content)
        self.assertIn("  - action: shell", content)
        self.assertIn("  - action: subagent", content)
        self.assertIn("    effect: deny", content)
        self.assertNotIn("\npermission:\n", content)
        self.assertNotIn("bash: deny", content)
        self.assertIn(self.scout.prompt, content)
        self.assertIn(model_agents.MARKER, content)

    def test_general_worker_may_edit_but_cannot_use_shell_or_redelegate(self):
        general = model_agents.read_role("general", "full")
        _, content = model_agents.render_agent(general, self.luna)
        self.assertNotIn("  - action: edit", content)
        self.assertIn("  - action: shell", content)
        self.assertIn("  - action: subagent", content)

    def test_orchestrator_may_delegate_but_may_not_edit_or_shell(self):
        orchestrator = model_agents.read_role("orchestrator", "full")
        _, content = model_agents.render_agent(orchestrator, self.luna)
        self.assertIn("  - action: edit", content)
        self.assertIn("  - action: shell", content)
        self.assertNotIn("  - action: subagent", content)

    def test_variant_id_can_be_parsed_without_conflating_model(self):
        raw = "local-llm/qwen-flash#4096\n" + json.dumps(
            {"providerID": "local-llm", "id": "qwen-flash", "name": "Qwen Flash"}
        )
        models = model_agents.parse_verbose_models(raw)
        self.assertEqual("local-llm/qwen-flash#4096", models[0].id)

    def test_dry_run_does_not_create_directory_or_files(self):
        changed, unchanged = model_agents.sync_agents(
            self.scout, [self.astra], self.destination, dry_run=True, prune_stale=False
        )

        self.assertEqual([model_agents.agent_name(self.scout, self.astra)], changed)
        self.assertEqual([], unchanged)
        self.assertFalse(self.destination.exists())

    def test_sync_is_idempotent_and_preserves_personal_collision(self):
        changed, _ = model_agents.sync_agents(
            self.scout, [self.astra], self.destination, dry_run=False, prune_stale=False
        )
        self.assertEqual(1, len(changed))
        target = self.destination / f"{changed[0]}.md"
        changed_again, unchanged = model_agents.sync_agents(
            self.scout, [self.astra], self.destination, dry_run=False, prune_stale=False
        )
        self.assertEqual([], changed_again)
        self.assertEqual([changed[0]], unchanged)

        target.write_text("personal agent\n", encoding="utf-8")
        with self.assertRaisesRegex(model_agents.SyncError, "nothing was written"):
            model_agents.sync_agents(
                self.scout, [self.astra, self.luna], self.destination, dry_run=False, prune_stale=False
            )
        self.assertEqual("personal agent\n", target.read_text(encoding="utf-8"))
        self.assertFalse((self.destination / f"{model_agents.agent_name(self.scout, self.luna)}.md").exists())

    def test_prune_stale_removes_only_owned_role_agents_and_only_when_requested(self):
        models = [self.astra, self.luna]
        model_agents.sync_agents(self.scout, models, self.destination, dry_run=False, prune_stale=False)
        stale = self.destination / f"{model_agents.agent_name(self.scout, self.luna)}.md"

        model_agents.sync_agents(self.scout, [self.astra], self.destination, dry_run=False, prune_stale=False)
        self.assertTrue(stale.exists())

        model_agents.sync_agents(self.scout, [self.astra], self.destination, dry_run=False, prune_stale=True)
        self.assertFalse(stale.exists())

    def test_symlink_collision_is_not_replaced(self):
        self.destination.mkdir(parents=True)
        target = self.destination / f"{model_agents.agent_name(self.scout, self.astra)}.md"
        link_target = Path(self.temp.name) / "external-agent.md"
        link_target.write_text("personal symlink target\n", encoding="utf-8")
        target.symlink_to(link_target)

        with self.assertRaisesRegex(model_agents.SyncError, "collision"):
            model_agents.sync_agents(
                self.scout, [self.astra], self.destination, dry_run=False, prune_stale=False
            )
        self.assertTrue(target.is_symlink())
        self.assertEqual("personal symlink target\n", link_target.read_text(encoding="utf-8"))

    def test_verbose_cli_catalog_is_the_discovery_source(self):
        result = type("Result", (), {"returncode": 0, "stdout": model_block("openai", "gpt-6-astra", "GPT-6 Astra")})()
        with patch.object(model_agents.subprocess, "run", return_value=result) as run:
            models = model_agents.discover_models()

        run.assert_called_once_with(
            ["opencode", "models", "--verbose"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual("GPT-6 Astra", models[0].name)

    @unittest.skipUnless(shutil.which("opencode"), "OpenCode CLI is not installed")
    def test_opencode_loads_generated_agent_frontmatter(self):
        with tempfile.TemporaryDirectory() as temporary:
            config_dir = Path(temporary)
            agents_dir = config_dir / "agents"
            model_agents.sync_agents(
                self.scout, [self.astra], agents_dir, dry_run=False, prune_stale=False
            )
            env = dict(os.environ, OPENCODE_CONFIG_DIR=str(config_dir))
            result = subprocess.run(
                ["opencode", "agent", "list"],
                env=env,
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn(model_agents.agent_name(self.scout, self.astra), result.stdout)

    def test_model_ids_that_slug_to_same_text_get_distinct_agent_names(self):
        first = model_agents.Model("provider/model.name", "Model Name")
        second = model_agents.Model("provider/model-name", "Model Name 2")
        self.assertNotEqual(
            model_agents.agent_name(self.scout, first),
            model_agents.agent_name(self.scout, second),
        )


if __name__ == "__main__":
    unittest.main()
