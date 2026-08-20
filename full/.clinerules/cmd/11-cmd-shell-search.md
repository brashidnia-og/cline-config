# Shell search and read-only repository inspection

Use search-first inspection to conserve context.

Generally appropriate read-only commands:
```bash
pwd
ls
ls -la
find
tree
stat
file
du
wc
head
tail
cat
sed
awk
cut
sort
uniq
tr
grep
rg
fd
which
whereis
readlink
realpath
dirname
basename
jq
yq
column
diff
cmp
md5sum
sha256sum
hexdump
xxd
timeout
time
```

Prefer `rg`, `fd`, targeted `find`, and bounded `sed`/`jq` ranges. Use `timeout <n>s <cmd>` and `time <cmd>` only to wrap already-safe commands.

Examples:
```bash
rg -n "symbolName" src/
rg -n "TODO|FIXME" src/
fd '.*\\.(kt|ts|rs|py)$' src
find src -maxdepth 3 -type f
sed -n '120,220p' path/to/file
jq '.scripts' package.json
timeout 60s ./gradlew :module:test --tests 'com.example.MyTest'
```

Avoid broad traversal of `.git/`, `node_modules/`, `target/`, `build/`, `.gradle/`, `dist/`, `coverage/`, generated output, or vendor directories unless directly relevant.

Restrictions:
- `find` is for inspection; do not use `-delete` or mutating `-exec` forms automatically.
- `sed` is for output inspection; do not use `sed -i` unless editing is explicitly intended.
- Bound `hexdump`/`xxd` to small ranges; do not dump large binaries into context.
- Do not pipe search output into destructive/external commands.
- If output is large, narrow directory, file type, symbol, or line range instead of ingesting everything.
