# PR #2 reconciliation against merged PR #1

This branch merges the latest main and retains only changes not already implemented by PR #1.

| Original PR #2 material | Disposition | Rationale |
|---|---|---|
| `ai-ready-plan`, clarification guide, `plans/<slug>.md` template | **Drop** as an independent skill | Overlaps `define-task-requirements` and creates a competing status and document convention instead of `product/work/` |
| Regression contract and independent preserved-behavior IDs | **Integrate** | Adds RG identifiers and tests to current requirement contracts and builder readiness/completion checks |
| `android-wireless-adb` skill + discovery script + offline tests | **Keep** | Distinct device management functionality useful for physical Android testing |
| OpenCode per-model specialist agent generator + tests | **Keep with fixes** | Selects actual configured provider/model IDs; updated to V2 permission actions and visible subagent discovery |
| Model-routing and install instructions | **Selectively integrate** | Preserves evidence-based local-model guidance from PR #1 and introduces only opt-in OpenCode model aliases |
| Earlier skill/agent-count assertions | **Replace** | PR #1 changed the catalogs; update both preexisting and newly introduced tests |

## Technical constraints and validation

OpenCode V2 role permissions use an ordered `permissions` array with `action`/`resource`/`effect` (not V1 `permission.edit/bash/task`). Hidden agents are absent from normal subagent discovery. Use explicit selected model aliases, not text pretending to switch the runtime model.

Validating a parser against synthetic adb data does not prove real wireless device connectivity. Likewise, validating agent Markdown syntax does not prove runtime model identity or restricted tool execution.

Run after checkout:
```bash
python3 -m unittest discover -s tests -v
./bin/install-full.sh -n --skip-mcp
./bin/install-lite.sh -n --skip-mcp
python3 bin/sync-opencode-model-agents.py --list
```

Then smoke-test OpenCode V2 with one generated model agent, inspect the selected model and test denial of prohibited operations. Test wireless adb on a real Android device with pairing and a known test command. No efficiency or accuracy improvement for Qwen or cheaper frontier models is asserted without measurements.

Sources: https://opencode.ai/docs/permissions, https://opencode.ai/docs/agents
