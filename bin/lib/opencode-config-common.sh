#!/usr/bin/env bash
# Shared OpenCode model-config helpers for install-opencode-config.sh (and,
# as a best-effort subprocess, for install-full.sh / install-lite.sh).
#
# Queries the local OpenAI-compatible model server ($LLM_URL/models) and
# (re)generates the provider block of the global opencode.jsonc. Everything
# else in that file is preserved: the managed block is wrapped in
# "// cline-config:begin local-llm" / "// cline-config:end local-llm" marker
# comments, so re-runs only rewrite that region. A user-authored file (no
# markers) is backed up to opencode.jsonc.bak-<timestamp> before its
# provider.local-llm entry is replaced in place on the first run.
#
# Requires die, info, install_hint from install-common.sh and
# resolve_opencode_global_dir from opencode-common.sh (sourced together by
# install-opencode-config.sh).

set -euo pipefail

OC_CONFIG_NAME="opencode.jsonc"
OC_TIMEOUT=10

# refresh_opencode_models <dry_run:0|1> <strict:0|1> <llm_url>
#
# strict=1 (standalone): any failure (missing python3, editor swap file,
# unreachable endpoint, 0 models, unparseable file, failed validation or
# write) exits non-zero via die(), leaving the existing file untouched.
# strict=0 (embedded in install-full/lite): the same failures print a warning
# and return 0 so the rest of the install completes.
refresh_opencode_models() {
  local dry_run="${1:-0}"
  local strict="${2:-1}"
  local url="${3:-}"

  if [[ -z "$url" ]]; then
    if [[ "$strict" == "1" ]]; then
      die "LLM_URL is empty (set LLM_URL or pass --url)"
    fi
    info "warning: LLM_URL is not set - skipping the ${OC_CONFIG_NAME} model refresh (the rest of the install is unaffected)."
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    if [[ "$strict" == "1" ]]; then
      install_hint python3
      die "python3 is required to query the model server and generate ${OC_CONFIG_NAME}"
    fi
    info "note: python3 not found - skipping the ${OC_CONFIG_NAME} model refresh (the rest of the install is unaffected)."
    install_hint python3
    return 0
  fi

  local oc_dir target
  oc_dir="$(resolve_opencode_global_dir)"
  target="${oc_dir}/${OC_CONFIG_NAME}"

  # Refuse to clobber a file an editor has open (vim creates <name>.swp/.swo
  # next to the file; a write underneath would surface as E325 on save).
  if [[ -e "${target}.swp" || -e "${target}.swo" ]]; then
    if [[ "$strict" == "1" ]]; then
      die "an editor appears to have ${target} open (found ${target}.swp / .swo) - close the editor first, then re-run"
    fi
    info "note: an editor appears to have ${target} open (vim swap file present) - skipping the model refresh (the rest of the install is unaffected)."
    info "Close the editor and run ./bin/install-opencode-config.sh to refresh the model list."
    return 0
  fi

  # The python program below: fetches <url>/models, merges the provider block
  # into the config (creating it if absent), validates the result, and either
  # prints a dry-run report or backs up + atomically writes the file.
  # Exit codes: 0 ok/skipped, 2 endpoint unreachable/HTTP error,
  # 3 bad response/zero models, 4 file structure not mergeable,
  # 5 post-validation failed, 6 backup/write failed.
  #
  # Capture via a temp file instead of nesting the heredoc in $(): bash 3.2
  # (macOS /bin/bash) misparses parentheses inside heredocs inside command
  # substitutions as shell syntax.
  local out rc out_file
  out_file="$(mktemp)"
  # Capture path in trap string — local out_file is unset when RETURN fires under set -u.
  # shellcheck disable=SC2064
  trap "rm -f '${out_file}'" RETURN
  python3 - "$target" "$url" "$dry_run" "$OC_TIMEOUT" >"$out_file" 2>&1 <<'PY' && rc=0 || rc=$?
import datetime
import json
import os
import sys
import tempfile
import urllib.error
import urllib.request

BEGIN_MARK = "// cline-config:begin local-llm"
END_MARK = "// cline-config:end local-llm"
PROVIDER_ID = "local-llm"


def fail(code, msg):
    sys.stdout.write(msg.rstrip("\n") + "\n")
    sys.exit(code)


# ---------- JSONC-aware text scanning ---------------------------------------
# The config is JSONC (comments allowed, often hand-edited). We never feed
# raw comments to json.loads and we never re-serialize the whole file: the
# merge is text surgery that leaves every byte outside the managed region
# untouched, so user comments and formatting survive.

def is_ws(c):
    return c in " \t\r\n"


def skip_ws_comments(text, i):
    n = len(text)
    while i < n:
        c = text[i]
        if is_ws(c):
            i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
        elif c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            if i + 1 < n:
                i += 2
            else:
                i = n
        else:
            break
    return i


def read_string(text, i):
    """text[i] == '"'. Returns (content, index just past the closing quote)."""
    n = len(text)
    j = i + 1
    buf = []
    while j < n:
        c = text[j]
        if c == "\\":
            if j + 1 < n:
                buf.append(c)
                buf.append(text[j + 1])
                j += 2
                continue
            buf.append(c)
            j += 1
            continue
        if c == '"':
            return "".join(buf), j + 1
        buf.append(c)
        j += 1
    raise ValueError("unterminated string literal")


def strip_comments(text):
    """Remove // and /* */ comments (string-aware) for json.loads validation."""
    out = []
    i = 0
    n = len(text)
    in_str = False
    esc = False
    in_line = False
    in_block = False
    while i < n:
        c = text[i]
        if in_line:
            if c == "\n":
                in_line = False
                out.append(c)
            i += 1
            continue
        if in_block:
            if c == "*" and i + 1 < n and text[i + 1] == "/":
                in_block = False
                out.append(" ")
                i += 2
                continue
            i += 1
            continue
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "/" and i + 1 < n:
            if text[i + 1] == "/":
                in_line = True
                i += 1
                continue
            if text[i + 1] == "*":
                in_block = True
                i += 2
                continue
        out.append(c)
        i += 1
    return "".join(out)


def depth_at(text, pos):
    """Bracket depth ({ and [) just before pos, ignoring strings/comments."""
    depth = 0
    i = 0
    n = min(pos, len(text))
    in_str = False
    esc = False
    in_line = False
    in_block = False
    while i < n:
        c = text[i]
        if in_line:
            if c == "\n":
                in_line = False
            i += 1
            continue
        if in_block:
            if c == "*" and i + 1 < n and text[i + 1] == "/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == "/" and i + 1 < n:
            if text[i + 1] == "/":
                in_line = True
                i += 1
                continue
            if text[i + 1] == "*":
                in_block = True
                i += 2
                continue
        if c in "{[":
            depth += 1
        elif c in "}]":
            depth -= 1
        i += 1
    return depth


def find_first_brace(text):
    i = 0
    n = len(text)
    in_str = False
    esc = False
    in_line = False
    in_block = False
    while i < n:
        c = text[i]
        if in_line:
            if c == "\n":
                in_line = False
            i += 1
            continue
        if in_block:
            if c == "*" and i + 1 < n and text[i + 1] == "/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == "/" and i + 1 < n:
            if text[i + 1] == "/":
                in_line = True
                i += 1
                continue
            if text[i + 1] == "*":
                in_block = True
                i += 2
                continue
        if c == "{":
            return i
        i += 1
    return None


def match_bracket(text, open_pos, open_ch, close_ch):
    """Index of the bracket matching text[open_pos] (string/comment-aware)."""
    n = len(text)
    depth = 0
    i = open_pos
    in_str = False
    esc = False
    in_line = False
    in_block = False
    while i < n:
        c = text[i]
        if in_line:
            if c == "\n":
                in_line = False
            i += 1
            continue
        if in_block:
            if c == "*" and i + 1 < n and text[i + 1] == "/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == "/" and i + 1 < n:
            if text[i + 1] == "/":
                in_line = True
                i += 1
                continue
            if text[i + 1] == "*":
                in_block = True
                i += 2
                continue
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unbalanced brackets in config")


def find_key(text, key, want_depth, search_from=0, search_to=None):
    """Find a key named `key` at bracket depth want_depth inside [search_from, search_to).

    Returns (key_start, key_end, colon_pos, value_start, value_kind) or None.
    value_kind is 'container' ({ or [) or 'scalar'.
    """
    if search_to is None:
        search_to = len(text)
    n = len(text)
    i = search_from
    while i < search_to:
        j = skip_ws_comments(text, i)
        if j >= search_to or j >= n:
            return None
        if text[j] != '"':
            i = j + 1
            continue
        content, after = read_string(text, j)
        i = after
        if content != key:
            continue
        k = skip_ws_comments(text, after)
        if k >= n or text[k] != ":":
            continue  # a string value, not a key
        if depth_at(text, j) != want_depth:
            continue
        v = skip_ws_comments(text, k + 1)
        if v >= search_to:
            continue
        kind = "container" if text[v] in "{[" else "scalar"
        return (j, after, k, v, kind)
    return None


def line_start(text, pos):
    return text.rfind("\n", 0, pos) + 1


def end_of_line(text, pos):
    n = len(text)
    i = pos
    while i < n and text[i] != "\n":
        i += 1
    return n if i >= n else i + 1


def key_line_indent(text, pos):
    """Leading whitespace of the line containing pos (None if not column 0)."""
    prefix = text[line_start(text, pos):pos]
    if prefix == "" or prefix.strip():
        return None
    return prefix


def detect_region_indent(text, start, end):
    for line in text[start:end].splitlines():
        stripped = line.lstrip()
        if stripped.startswith('"local-llm"'):
            prefix = line[: len(line) - len(stripped)]
            if prefix and not prefix.strip():
                return prefix
        if BEGIN_MARK in line:
            prefix = line[: len(line) - len(line.lstrip())]
            if prefix and not prefix.strip():
                return prefix
    return "    "


def detect_member_indent(text, start, end):
    """Indent of the first key inside an object spanning [start, end)."""
    i = start
    n = len(text)
    while i < end:
        j = skip_ws_comments(text, i)
        if j >= end or j >= n:
            return None
        if text[j] != '"':
            i = j + 1
            continue
        content, after = read_string(text, j)
        i = after
        k = skip_ws_comments(text, after)
        if k < n and text[k] == ":":
            prefix = text[line_start(text, j):j]
            if prefix and not prefix.strip():
                return prefix
    return None


# ---------- managed block rendering -----------------------------------------

# Per-request vLLM thinking budgets exposed as OpenCode model variants.
# Base model (no variant) leaves thinking_token_budget unset (unlimited).
THINKING_TOKEN_BUDGETS = (2048, 4096, 8192, 32768)


def render_block(ids, url, base_indent, trailing):
    """The marker-wrapped provider.local-llm block, at base_indent (the indent
    of the 'local-llm' key line). trailing adds a comma after the block when
    another provider member follows it."""
    c1 = base_indent + "  "
    c2 = base_indent + "    "
    c3 = base_indent + "      "
    c4 = base_indent + "        "
    c5 = base_indent + "          "
    lines = [
        base_indent + BEGIN_MARK,
        base_indent + '"local-llm": {',
        c1 + '"name": "Local LLM",',
        c1 + '"npm": "@ai-sdk/openai-compatible",',
        c1 + '"options": {',
        c2 + '"baseURL": ' + json.dumps(url) + ",",
        # Local vLLM prefills can exceed OpenCode's default header wait; disable
        # so long TTFT does not abort mid-prefill and trigger retry loops.
        c2 + '"headerTimeout": false',
        c1 + "},",
        c1 + '"models": {',
    ]
    for idx, mid in enumerate(ids):
        comma = "," if idx < len(ids) - 1 else ""
        lines.append(c2 + json.dumps(mid) + ": {")
        lines.append(c3 + '"name": ' + json.dumps(mid) + ",")
        lines.append(c3 + '"reasoning": true,')
        lines.append(c3 + '"variants": {')
        for bidx, budget in enumerate(THINKING_TOKEN_BUDGETS):
            bcomma = "," if bidx < len(THINKING_TOKEN_BUDGETS) - 1 else ""
            lines.append(c4 + json.dumps(str(budget)) + ": {")
            lines.append(c5 + '"thinking_token_budget": ' + str(budget))
            lines.append(c4 + "}" + bcomma)
        lines.append(c3 + "}")
        lines.append(c2 + "}" + comma)
    lines.append(c1 + "}")
    lines.append(base_indent + "}" + ("," if trailing else ""))
    lines.append(base_indent + END_MARK)
    return "\n".join(lines) + "\n"


def build_new_file(ids, url):
    return (
        "{\n"
        '  "$schema": "https://opencode.ai/config.json",\n'
        '  "disabled_providers": [],\n'
        '  "provider": {\n'
        + render_block(ids, url, "    ", False)
        + "  }\n"
        "}\n"
    )


# ---------- merge strategies --------------------------------------------------

def regenerate_region(text, ids, url):
    """File carries both markers (in order): rewrite only that region."""
    b = text.find(BEGIN_MARK)
    e = text.find(END_MARK, b)
    if b == -1 or e == -1:
        raise ValueError("managed markers are corrupted (begin without matching end)")
    b_start = line_start(text, b)
    e_end = end_of_line(text, e)
    base_indent = detect_region_indent(text, b_start, e_end)
    nxt = skip_ws_comments(text, e_end)
    # Trailing comma only if another provider member follows the region.
    trailing = nxt < len(text) and text[nxt] != "}"
    block = render_block(ids, url, base_indent, trailing)
    return text[:b_start] + block + text[e_end:], "regenerated managed region in place"


def replace_local_llm(text, llm, prov_close, ids, url, base_indent):
    key_start, _key_end, _colon, value_open, kind = llm
    if kind != "container" or text[value_open] != "{":
        raise ValueError("provider.local-llm is not a JSON object; cannot merge safely")
    llm_close = match_bracket(text, value_open, "{", "}")
    if llm_close > prov_close:
        raise ValueError("provider.local-llm object is malformed; cannot merge safely")
    nxt = skip_ws_comments(text, llm_close + 1)
    if nxt >= len(text):
        raise ValueError("unexpected end of file inside the provider object")
    if text[nxt] == ",":
        trailing = True
        region_end = nxt + 1
    elif text[nxt] == "}":
        if nxt != prov_close:
            raise ValueError("unexpected structure after provider.local-llm; cannot merge safely")
        trailing = False
        region_end = end_of_line(text, llm_close)
    else:
        raise ValueError("unexpected character %r after provider.local-llm; cannot merge safely" % text[nxt])
    region_start = line_start(text, key_start)
    block = render_block(ids, url, base_indent, trailing)
    return text[:region_start] + block + text[region_end:], "replaced existing provider.local-llm (added managed markers)"


def insert_into_provider(text, prov_open, prov_close, ids, url, base_indent):
    nxt = skip_ws_comments(text, prov_open + 1)
    provider_empty = nxt >= len(text) or text[nxt] == "}"
    if base_indent is None:
        base_indent = "    "
    member = "\n" + render_block(ids, url, base_indent, not provider_empty)
    new_text = text[:prov_open + 1] + member + text[prov_open + 1:]
    return new_text, "inserted provider.local-llm into the existing provider object"


def inject_provider(text, root_open, ids, url):
    nxt = skip_ws_comments(text, root_open + 1)
    root_has_members = not (nxt >= len(text) or text[nxt] == "}")
    member = (
        "\n  \"provider\": {\n"
        + render_block(ids, url, "    ", False)
        + "  }"
        + ("," if root_has_members else "")
    )
    new_text = text[:root_open + 1] + member + text[root_open + 1:]
    return new_text, "injected a new provider object (the file had none)"


def merge_unmarked(text, ids, url):
    # Drop orphaned cline-config marker lines (corrupted/partial marker state)
    # before doing structural surgery; they are plain comment lines.
    kept = [
        line
        for line in text.splitlines(keepends=True)
        if BEGIN_MARK not in line and END_MARK not in line
    ]
    text = "".join(kept)

    root_open = find_first_brace(text)
    if root_open is None:
        raise ValueError("no root JSON object found; cannot merge safely")

    prov = find_key(text, "provider", 1)
    if prov is None:
        return inject_provider(text, root_open, ids, url)

    if prov[4] != "container" or text[prov[3]] != "{":
        raise ValueError("'provider' is not a JSON object; cannot merge safely")
    prov_open = prov[3]
    prov_close = match_bracket(text, prov_open, "{", "}")

    llm = find_key(text, "local-llm", 2, search_from=prov_open + 1, search_to=prov_close)
    if llm is None:
        base_indent = detect_member_indent(text, prov_open + 1, prov_close)
        return insert_into_provider(text, prov_open, prov_close, ids, url, base_indent)

    base_indent = key_line_indent(text, llm[0]) or "    "
    return replace_local_llm(text, llm, prov_close, ids, url, base_indent)


# ---------- main ---------------------------------------------------------------

def main():
    if len(sys.argv) < 5:
        fail(1, "internal error: expected arguments <target> <url> <dry_run> <timeout>")
    target = sys.argv[1]
    llm_url = sys.argv[2]
    dry_run = sys.argv[3] == "1"
    try:
        timeout = float(sys.argv[4])
    except ValueError:
        timeout = 10.0
    base_url = llm_url.rstrip("/")

    # Read the existing config (if any).
    existing = None
    if os.path.exists(target):
        try:
            with open(target, "r", encoding="utf-8") as f:
                existing = f.read()
        except Exception as e:
            fail(4, "could not read %s: %s" % (target, e))

    # Respect an explicit user opt-out before doing any work.
    if existing is not None:
        try:
            cfg = json.loads(strip_comments(existing))
            if isinstance(cfg, dict) and PROVIDER_ID in (cfg.get("disabled_providers") or []):
                print("skipped: provider '%s' is listed in disabled_providers in %s - leaving the file untouched" % (PROVIDER_ID, target))
                sys.exit(0)
        except Exception:
            pass  # structural problems are caught by the merge + post-validation below

    # Fetch the live model list.
    endpoint = base_url + "/models"
    try:
        req = urllib.request.Request(endpoint, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        fail(2, "endpoint error: HTTP %s from %s" % (e.code, endpoint))
    except Exception as e:
        fail(2, "cannot reach %s (%s: %s) - is the LLM server running?" % (endpoint, e.__class__.__name__, e))

    if isinstance(payload, dict) and isinstance(payload.get("data"), list):
        entries = payload["data"]
    elif isinstance(payload, list):
        entries = payload
    else:
        fail(3, "unexpected response shape from %s (expected a list, or an object with a 'data' list)" % endpoint)

    ids = []
    for entry in entries:
        if isinstance(entry, dict) and isinstance(entry.get("id"), str) and entry["id"]:
            if entry["id"] not in ids:
                ids.append(entry["id"])
    ids.sort()
    if not ids:
        fail(3, "%s returned 0 models - refusing to overwrite the config with an empty model list" % endpoint)

    # Merge.
    if existing is None:
        new_text = build_new_file(ids, base_url)
        action = "created file"
        backup_needed = False
    else:
        b = existing.find(BEGIN_MARK)
        e = existing.find(END_MARK, b) if b != -1 else -1
        try:
            if b != -1 and e != -1:
                new_text, action = regenerate_region(existing, ids, base_url)
                backup_needed = False
            else:
                new_text, action = merge_unmarked(existing, ids, base_url)
                backup_needed = True
        except ValueError as ex:
            fail(4, "could not update %s: %s - file left unchanged" % (target, ex))

    # Post-validation: never write a file that is not valid JSON with the
    # expected provider block.
    try:
        parsed = json.loads(strip_comments(new_text))
    except Exception as e:
        fail(5, "post-validation failed (merge would produce invalid JSON: %s) - original file left unchanged" % e)
    if not isinstance(parsed, dict):
        fail(5, "post-validation failed (root is not a JSON object) - original file left unchanged")
    prov = parsed.get("provider")
    llm = prov.get(PROVIDER_ID) if isinstance(prov, dict) else None
    if not isinstance(llm, dict) or llm.get("options", {}).get("baseURL") != base_url:
        fail(5, "post-validation failed (provider.%s.baseURL mismatch) - original file left unchanged" % PROVIDER_ID)
    if llm.get("options", {}).get("headerTimeout") is not False:
        fail(5, "post-validation failed (provider.%s.options.headerTimeout must be false) - original file left unchanged" % PROVIDER_ID)
    models = llm.get("models", {})
    if set(models.keys()) != set(ids):
        fail(5, "post-validation failed (model list mismatch) - original file left unchanged")
    expected_variants = {str(b): b for b in THINKING_TOKEN_BUDGETS}
    for mid in ids:
        entry = models.get(mid)
        if not isinstance(entry, dict):
            fail(5, "post-validation failed (model %s is not an object) - original file left unchanged" % mid)
        if entry.get("thinking_token_budget") is not None:
            fail(5, "post-validation failed (base model %s must not set thinking_token_budget) - original file left unchanged" % mid)
        opts = entry.get("options")
        if isinstance(opts, dict) and opts.get("thinking_token_budget") is not None:
            fail(5, "post-validation failed (base model %s options must not set thinking_token_budget) - original file left unchanged" % mid)
        variants = entry.get("variants")
        if not isinstance(variants, dict) or set(variants.keys()) != set(expected_variants.keys()):
            fail(5, "post-validation failed (model %s variants mismatch; expected %s) - original file left unchanged" % (mid, ", ".join(expected_variants.keys())))
        for key, budget in expected_variants.items():
            v = variants.get(key)
            if not isinstance(v, dict) or v.get("thinking_token_budget") != budget:
                fail(5, "post-validation failed (model %s variant %s thinking_token_budget mismatch) - original file left unchanged" % (mid, key))

    # Report / write.
    models_line = ", ".join(ids)
    if dry_run:
        print("[dry-run] endpoint: %s" % endpoint)
        print("[dry-run] models:   %d (%s)" % (len(ids), models_line))
        print("[dry-run] target:   %s" % target)
        print("[dry-run] action:   %s" % action)
        if backup_needed:
            print("[dry-run] note: existing file has no cline-config markers - it would be backed up to %s.bak-<timestamp> first" % os.path.basename(target))
        print("[dry-run] resulting file content:")
        sys.stdout.write(new_text)
        sys.exit(0)

    if backup_needed and existing is not None:
        ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        bak = "%s.bak-%s" % (target, ts)
        try:
            with open(bak, "w", encoding="utf-8") as f:
                f.write(existing)
        except Exception as e:
            fail(6, "could not create backup %s: %s" % (bak, e))
        backup_path = bak
    else:
        backup_path = None

    d = os.path.dirname(target) or "."
    try:
        os.makedirs(d, exist_ok=True)
    except Exception as e:
        fail(6, "could not create directory %s: %s" % (d, e))
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".opencode.jsonc.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(new_text)
        os.replace(tmp, target)
    except Exception as e:
        try:
            if os.path.exists(tmp):
                os.remove(tmp)
        except OSError:
            pass
        fail(6, "write failed: %s" % e)

    msg = "updated %s: %d model(s) from %s [%s]" % (target, len(ids), endpoint, action)
    if backup_path:
        msg += " (previous file backed up to %s)" % backup_path
    print(msg)
    print("models: %s" % models_line)


main()
PY
  out="$(cat "$out_file")"
  if [[ "$rc" != "0" ]]; then
    if [[ "$strict" == "1" ]]; then
      die "opencode.jsonc refresh failed: ${out}"
    fi
    info "warning: could not refresh ${target} (${out:-unknown error}) - the rest of the install completed."
    info "Run ./bin/install-opencode-config.sh later (with the LLM server reachable) to retry."
    return 0
  fi
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
  fi
  return 0
}
