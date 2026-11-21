# Godot validation and resource safety

Use the project's documented gates and installed engine version. These checks address failure modes where plausible-looking output is weaker evidence than the actual runtime behavior.

## Headless gates and imports

- Retain the engine process exit status and full stdout/stderr. Check for `SCRIPT ERROR`, unexpected `ERROR:` diagnostics, resource-load failures, and failing assertions; a later PASS line can come from an unrelated check after an earlier failure. If a negative test deliberately emits an error, account for that exact expected diagnostic rather than ignoring all errors.
- Do not report a logging/filter pipeline's exit status as the engine's result. Preserve the original failed log and record each rerun as a separate gate with its command, engine version, revision, exit status, and verdict.
- In a fresh checkout/worktree, run the established asset-import step before gates that depend on imported resources. A version-supported underlying invocation may be `godot --headless --path <project> --editor --import --quit`; inspect project editor plugins and repository wrappers before executing it. A missing generated `.ctex` is not evidence that the source image is missing.
- Isolate persistent test settings between gates and reruns. On Linux, a scratch `XDG_DATA_HOME` may provide isolation, but verify the actual Godot user-data path and project overrides. Do not reset a test by deleting the user's real settings.

## Scene lifecycle and captures

- Check opt-in processing behavior after actual scene-tree entry. Overridden callbacks can be enabled as part of node initialization/entry; an `_init()`-only check may miss this. Where required by the installed version and node type, apply the scheduling choice in `_ready()` and verify both disabled/default and enabled paths.
- Before screenshots, assert the actual menu/match/modal state, then wait for the rendered frame. Re-establish readiness after configuration changes if those changes invalidate it. Distinct filenames and successful PNG writes do not prove distinct or correct screens; inspect images and use hashes to detect accidental duplicates.
- Record actual window and viewport dimensions in capture evidence. Window-manager constraints can prevent a requested tall resolution from being rendered.

## Probe artifacts and UIDs

- Track exact task-created paths for cleanup. Broad globs such as `tools/*.uid` can delete tracked files, staged additions, or another owner's untracked metadata.
- If a UID sidecar is lost, preserve remaining metadata and `.godot/uid_cache.bin` before further imports. Establish ownership and recover the original tracked/staged or cached mapping where possible; inspect the installed version's ResourceUID API when decoding cached IDs. Do not silently regenerate IDs or restore an entire directory over user work.
- Verify tracked, staged, and untracked categories separately. A clean unstaged-deletion list alone does not establish that all original mappings survived.
