#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "$(t task.gateway.start)"

need_cmd openclaw

STATE_DIR="${AUTOCLAW_STATE:-$(pwd)/sh/state}"
mkdir -p "$STATE_DIR"
FLAG="$STATE_DIR/gateway_ok.json"
TS="$(date +%Y%m%d-%H%M%S)"

get_mem_mb() {
  awk '/^MemTotal:/ {printf("%d", $2/1024)}' /proc/meminfo 2>/dev/null || echo "0"
}
get_swap_mb() {
  awk '/^SwapTotal:/ {printf("%d", $2/1024)}' /proc/meminfo 2>/dev/null || echo "0"
}

MEM_MB="$(get_mem_mb)"
SWAP_MB="$(get_swap_mb)"
NODE_OPTS=""

# 1GB VPS에서는 openclaw CLI가 종종 기본 heap limit에 걸려 OOM이 난다.
# 스왑이 있는 경우에 한해 heap을 키워서 설치/시작 성공률을 올린다.
if [[ "$MEM_MB" -gt 0 && "$MEM_MB" -lt 1500 && "$SWAP_MB" -gt 0 ]]; then
  NODE_OPTS="--max-old-space-size=1024"
  log "$(printf "$(t task.gateway.lowmem)" "$MEM_MB" "$SWAP_MB" "$NODE_OPTS")"
fi

run_openclaw() {
  local label="$1"; shift
  local out rc
  log "gateway: ${label}"
  if [[ -n "$NODE_OPTS" ]]; then
    out="$(NODE_OPTIONS="$NODE_OPTS" "$@" 2>&1)" || rc=$?
  else
    out="$("$@" 2>&1)" || rc=$?
  fi
  rc="${rc:-0}"
  printf '%s\n' "$out"

  if echo "$out" | grep -qi "heap out of memory"; then
    log "$(t task.gateway.oom)"
    return 99
  fi
  return "$rc"
}

# may require privileges depending on system
run_openclaw "gateway install (서비스 등록)" openclaw gateway install || true

run_openclaw "gateway start" openclaw gateway start || true

# 최종 판정은 status로 한다(이게 실패하면 실패)
STATUS_OUT="$(run_openclaw "gateway status" openclaw gateway status)" || {
  log "$(t task.gateway.status_fail)"
  exit 1
}

# Success flag (used by UI progress detection)
cat > "$FLAG" <<JSON
{ "ok": true, "checkedAt": "${TS}" }
JSON

log "$(printf "$(t task.gateway.flag)" "$FLAG")"
log "$(t task.gateway.done)"
