import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "bin" / "lib" / "multitool.py"


class MultitoolInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        self.home.mkdir()
        self.project = Path(self.temp.name) / "project"
        self.project.mkdir()

    def run_installer(self, *args):
        env = dict(os.environ, HOME=str(self.home))
        return subprocess.run(["python3", str(INSTALLER), *args], env=env,
                              capture_output=True, text=True, check=True)

    def test_full_lite_switch_preserves_personal_content(self):
        personal = self.home / ".agents" / "skills" / "private-skill"
        personal.mkdir(parents=True)
        (personal / "SKILL.md").write_text("private\n")
        self.run_installer("install", "--profile", "full")
        self.assertEqual(19, len(list((self.home / ".agents/skills").glob("*/SKILL.md"))) - 1)
        self.assertEqual(16, len(list((self.home / ".codex/agents").glob("*.toml"))))
        self.run_installer("install", "--profile", "lite")
        self.assertEqual(4, len(list((self.home / ".agents/skills").glob("*/SKILL.md"))) - 1)
        self.assertEqual(7, len(list((self.home / ".claude/agents").glob("*.md"))))
        self.assertEqual("private\n", (personal / "SKILL.md").read_text())
        self.run_installer("install", "--profile", "full")
        self.assertEqual(19, len(list((self.home / ".hermes/skills/cline-config").glob("*/SKILL.md"))))

    def test_project_rules_force_and_dry_run(self):
        agents = self.project / "AGENTS.md"
        agents.write_text("personal instructions\n")
        self.run_installer("install", "--profile", "lite", "--project", str(self.project), "--dry-run")
        self.assertEqual("personal instructions\n", agents.read_text())
        self.run_installer("install", "--profile", "lite", "--project", str(self.project))
        self.assertEqual("personal instructions\n", agents.read_text())
        self.assertTrue((self.project / ".claude/rules").exists() is False)
        self.run_installer("install", "--profile", "full", "--project", str(self.project), "--force")
        self.assertIn("cline-config:managed", agents.read_text())
        self.assertTrue(list(self.project.glob("AGENTS.md.bak-*")))
        self.assertTrue(list((self.project / ".claude/rules").glob("cline-config-*.md")))

    def test_mcp_preserves_existing_servers_and_settings(self):
        codex = self.home / ".codex" / "config.toml"
        codex.parent.mkdir()
        codex.write_text('model = "chosen-model"\n[mcp_servers."local-playwright"]\ncommand = "custom"\n')
        claude = self.home / ".claude.json"
        claude.write_text(json.dumps({"theme": "dark", "mcpServers": {"local-playwright": {"command": "custom"}}}))
        self.run_installer("mcp")
        c = tomllib.loads(codex.read_text())
        self.assertEqual("chosen-model", c["model"])
        self.assertEqual("custom", c["mcp_servers"]["local-playwright"]["command"])
        self.assertFalse(c["mcp_servers"]["external-tavily"]["enabled"])
        self.assertEqual("custom", json.loads(claude.read_text())["mcpServers"]["local-playwright"]["command"])
        self.run_installer("mcp")
        self.assertEqual(10, len(tomllib.loads(codex.read_text())["mcp_servers"]))


if __name__ == "__main__":
    unittest.main()
