#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "node: 시작 — OpenClaw node 서비스를 설치/시작하고 상태를 확인한다."

need_cmd openclaw

STATE_DIR="${AUTOCLAW_STATE:-$(pwd)/sh/state}"
mkdir -p "$STATE_DIR"
FLAG="$STATE_DIR/node_ok.json"
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

if [[ "$MEM_MB" -gt 0 && "$MEM_MB" -lt 1500 && "$SWAP_MB" -gt 0 ]]; then
  NODE_OPTS="--max-old-space-size=1024"
  log "node: low-mem 감지(mem=${MEM_MB}MB swap=${SWAP_MB}MB) → NODE_OPTIONS=${NODE_OPTS} 적용"
fi

run_openclaw() {
  local label="$1"; shift
  local out rc
  log "node: ${label}"
  if [[ -n "$NODE_OPTS" ]]; then
    out="$(NODE_OPTIONS="$NODE_OPTS" "$@" 2>&1)" || rc=$?
  else
    out="$("$@" 2>&1)" || rc=$?
  fi
  rc="${rc:-0}"
  printf '%s\n' "$out"

  if echo "$out" | grep -qi "heap out of memory"; then
    log "node: ERROR: Node heap out of memory 감지"
    return 99
  fi
  return "$rc"
}

run_openclaw "node install (서비스 등록)" openclaw node install || true

run_openclaw "node restart" openclaw node restart || true

# 최종 판정은 node status로 한다
if ! run_openclaw "node status" openclaw node status; then
  log "node: ERROR: node status 실패"
  exit 1
fi

# pairing/connection is optional but useful to show
run_openclaw "nodes status (페어링/연결 확인)" openclaw nodes status || true

cat > "$FLAG" <<JSON
{ "ok": true, "checkedAt": "${TS}" }
JSON

log "node: flag written: $FLAG"
log "node: 완료"
