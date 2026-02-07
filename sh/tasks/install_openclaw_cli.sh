#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"
source "$(dirname "$0")/../lib/versions.sh"

log "openclaw(cli): 시작 — npm i -g openclaw 방식으로 OpenClaw CLI를 설치한다."

if ! is_linux; then
  die "Linux 서버에서만 지원한다."
fi

ID="$(linux_id)"
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  die "현재는 ubuntu/debian만 지원한다. (ID=$ID)"
fi

need_cmd sudo
need_cmd npm

if command -v openclaw >/dev/null 2>&1; then
  log "openclaw(cli): 이미 openclaw가 설치되어 있다: $(command -v openclaw)"
  log "openclaw(cli): 버전: $(openclaw --version 2>/dev/null || true)"
  log "openclaw(cli): 이 단계는 스킵한다."
  exit 0
fi

log "openclaw(cli): npm 글로벌 설치"
log "openclaw(cli): (설명) 필요 시 전역 권한이 필요할 수 있어 sudo를 사용한다."

sudo npm i -g openclaw

log "openclaw(cli): 설치 확인"
need_cmd openclaw
log "openclaw(cli): 버전: $(openclaw --version 2>/dev/null || true)"

log "$(t task.openclaw.install.done)"
