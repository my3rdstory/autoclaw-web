#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "prereqs: 시작 — OpenClaw 설치에 필요한 기본 패키지(필수+운영)를 준비한다."
as_root_hint

if ! is_linux; then
  log "prereqs: 현재는 Linux 서버 기준 스크립트다. (다른 OS는 이후 지원)"
  exit 0
fi

ID="$(linux_id)"
log "prereqs: distro id=${ID}"

case "$ID" in
  ubuntu|debian)
    log "prereqs: apt update"
    sudo apt-get update -y

    # Idempotent: apt-get install is safe to re-run.
    log "$(t task.prereqs.start)"
    log "prereqs: - curl, git, ca-certificates, jq, lsof"
    sudo apt-get install -y curl git ca-certificates jq lsof

    log "prereqs: 버전/존재 확인"
    command -v curl >/dev/null && log "prereqs: curl=$(curl --version | head -n1)"
    command -v git  >/dev/null && log "prereqs: git=$(git --version)"
    command -v jq   >/dev/null && log "prereqs: jq=$(jq --version)"
    command -v lsof >/dev/null && log "prereqs: lsof=$(lsof -v 2>/dev/null | head -n1 || true)"

    log "prereqs: Node.js/pnpm 설치는 다음 단계(11_node_pnpm)에서 처리한다."
    ;;
  *)
    log "prereqs: 아직 지원하지 않는 배포판이다. (ID=$ID)"
    log "prereqs: TODO: dnf/yum/apk 등 분기 추가"
    ;;
 esac

log "$(t task.prereqs.done)"
