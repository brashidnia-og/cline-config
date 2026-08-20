# Process, environment, and host inspection

Generally appropriate read-only diagnostics:
```bash
ps
ps aux
pgrep
lsof
uname
hostname
id
whoami
date
uptime
free
df
nproc
ulimit -a
locale
groups
getconf
```

Examples:
```bash
pgrep -af java
pgrep -af node
pgrep -af cargo
pgrep -af python
lsof -i :8080
```

Use process inspection before assuming a service failed to start or before attempting cleanup.

## Environment
Prefer targeted variables:
```bash
printenv NODE_ENV
printenv JAVA_HOME
printenv RUST_LOG
printenv AWS_PROFILE
printenv AWS_REGION
```

Do not dump the full environment if secrets may be present. Do not print likely secret variables unless explicitly required and authorized.

## Jobs
`jobs` is acceptable. `fg`/`bg` only for agent-started disposable jobs whose identity is known.

## Process termination
Do not automatically use `kill`, `killall`, or `pkill` on arbitrary processes.

An agent-started disposable local process may be terminated for cleanup only when its identity is known and unrelated processes cannot be affected.

Do not auto-run `sudo`, `su`, `doas`, `systemctl`, or `service`.
