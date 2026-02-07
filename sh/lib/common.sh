#!/usr/bin/env bash
set -euo pipefail

# i18n
# shellcheck disable=SC1090
# NOTE: this file is sourced by task scripts; use BASH_SOURCE to resolve this file's directory.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$COMMON_DIR/i18n.sh"

log() {
  # timestamped, human-readable for dashboard
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  log "ERROR: $*"
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

is_linux() { [[ "$(uname -s)" == "Linux" ]]; }

# Best-effort distro detection
linux_id() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-unknown}"
  else
    echo "unknown"
  fi
}

as_root_hint() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "이 단계는 root 권한이 필요할 수 있어. (예: sudo로 실행)"
  fi
}
