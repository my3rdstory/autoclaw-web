#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "doctor: 시작 — 현재 시스템 상태를 점검한다."
log "doctor: OS=$(uname -a)"

if is_linux; then
  log "doctor: distro=$(linux_id)"
  [[ -f /etc/os-release ]] && sed -n '1,20p' /etc/os-release | sed 's/^/[os-release] /'
fi

for c in curl git node npm pnpm; do
  if command -v "$c" >/dev/null 2>&1; then
    log "doctor: OK command exists: $c -> $(command -v "$c")"
  else
    log "doctor: WARN missing command: $c"
  fi
done

log "doctor: 완료"
