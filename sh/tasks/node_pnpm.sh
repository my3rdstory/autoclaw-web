#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "node/pnpm: 시작 — Node.js LTS(NodeSource) + pnpm을 설치한다."
as_root_hint

if ! is_linux; then
  die "Linux 서버에서만 지원한다."
fi

ID="$(linux_id)"
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  die "현재는 ubuntu/debian만 지원한다. (ID=$ID)"
fi

source "$(dirname "$0")/../lib/versions.sh"

need_cmd curl

MIN_NODE="20.0.0"
MIN_PNPM="9.0.0"

HAVE_NODE="0"
if command -v node >/dev/null 2>&1; then
  HAVE_NODE="1"
  NODE_V="$(node -v || true)"
  log "node/pnpm: 감지된 node=$NODE_V"
else
  log "node/pnpm: node 미설치"
fi

# Node check
NEED_NODE="1"
if [[ "$HAVE_NODE" == "1" ]]; then
  if ver_ge_dpkg "$NODE_V" "$MIN_NODE"; then
    NEED_NODE="0"
    log "node/pnpm: node 버전 조건 충족 (>= $MIN_NODE) → 설치 스킵"
  else
    log "node/pnpm: node 버전 부족 (need >= $MIN_NODE) → 설치/업그레이드 진행"
  fi
fi

if [[ "$NEED_NODE" == "1" ]]; then
  log "node/pnpm: NodeSource LTS 저장소 설정"
  log "node/pnpm: (설명) NodeSource 스크립트가 apt repo를 추가한다."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

  log "node/pnpm: nodejs 설치"
  sudo apt-get install -y nodejs

  log "node/pnpm: node=$(node -v || true) npm=$(npm -v || true)"
fi

# pnpm check
NEED_PNPM="1"
if command -v pnpm >/dev/null 2>&1; then
  PNPM_V="$(pnpm -v || true)"
  log "node/pnpm: 감지된 pnpm=$PNPM_V"
  if ver_ge_dpkg "$PNPM_V" "$MIN_PNPM"; then
    NEED_PNPM="0"
    log "node/pnpm: pnpm 버전 조건 충족 (>= $MIN_PNPM) → 설치 스킵"
  else
    log "node/pnpm: pnpm 버전 부족 (need >= $MIN_PNPM) → 업그레이드 진행"
  fi
else
  log "node/pnpm: pnpm 미설치"
fi

if [[ "$NEED_PNPM" == "1" ]]; then
  log "node/pnpm: pnpm 설치/업그레이드 (corepack 사용)"
  sudo corepack enable || true
  corepack prepare pnpm@latest --activate
  log "node/pnpm: pnpm=$(pnpm -v || true)"
fi

log "node/pnpm: 완료"
