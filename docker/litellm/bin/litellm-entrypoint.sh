#!/bin/bash
set -u

LOG=/mnt/log/rag/litellm.log
TOKEN_FILE=/mnt/ragconfig/r2r/openai_api_token.txt
CONFIG=/mnt/ragconfig/litellm/config.yaml
WAIT=5

# Everything from here on (including litellm itself after exec) goes to the log
exec >>"$LOG" 2>&1

log() { echo "$(date -Is) [entrypoint] $*"; }

# Waits until the check function succeeds, logging only when the reason changes
wait_until() {
  local desc="$1"; shift
  local last="" reason
  until reason=$("$@" 2>&1); do
    reason="${reason:-check failed with no output}"
    if [ "$reason" != "$last" ]; then
      log "waiting for $desc: $reason"
      last="$reason"
    fi
    sleep "$WAIT"
  done
  log "$desc OK"
}

check_file() {
  [ -s "$1" ] || { echo "$1 missing or empty"; return 1; }
}

# Re-reads the config on every call, so edits are picked up while waiting
check_master_key() {
  python3 - "$CONFIG" <<'EOF'
import os, sys, yaml

try:
    with open(sys.argv[1]) as f:
        cfg = yaml.safe_load(f) or {}
except Exception as e:
    print(f"config.yaml not parseable yet: {e}")
    sys.exit(1)

gs = cfg.get("general_settings") if isinstance(cfg, dict) else None
key = gs.get("master_key") if isinstance(gs, dict) else None

if not isinstance(key, str) or not key.strip():
    print("general_settings.master_key is not set or empty")
    sys.exit(1)

# Support the os.environ/VAR indirection LiteLLM allows
if key.startswith("os.environ/"):
    var = key.split("/", 1)[1]
    key = os.environ.get(var, "")
    if not key.strip():
        print(f"master_key references env var {var}, which is empty or unset")
        sys.exit(1)

if not key.startswith("sk-"):
    print("master_key must start with 'sk-'")
    sys.exit(1)
EOF
}

wait_until "token file"     check_file "$TOKEN_FILE"
wait_until "config file"    check_file "$CONFIG"
# Important to wait for the master-key since changing it would make db entries invalid, since they are salted using
# the master key (this is not only an authentication?
wait_until "master_key"     check_master_key

log "all checks passed, starting litellm"
exec litellm "$@"
