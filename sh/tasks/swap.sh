#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "$(t task.swap.start)"

SWAPFILE="${AUTOCLAW_SWAPFILE:-/swapfile}"
SWAP_GB="${AUTOCLAW_SWAP_GB:-2}"
SWAP_SIZE="${SWAP_GB}G"

# If swap already exists, do nothing.
if swapon --show 2>/dev/null | awk 'NR>1{print $1}' | grep -q .; then
  log "$(t task.swap.skip)"
  swapon --show || true
  log "$(t task.swap.done)"
  exit 0
fi

log "$(printf "$(t task.swap.creating)" "$SWAP_SIZE" "$SWAPFILE")"

# Create swapfile (prefer fallocate)
if command -v fallocate >/dev/null 2>&1; then
  sudo fallocate -l "$SWAP_SIZE" "$SWAPFILE" || true
fi

# Fallback to dd if file is missing or size seems wrong.
if [[ ! -f "$SWAPFILE" ]]; then
  log "swap: fallocate 실패/미지원 → dd로 생성"
  # 2G default: 2048 blocks of 1M
  # shellcheck disable=SC2086
  sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((SWAP_GB*1024)) status=progress
fi

sudo chmod 600 "$SWAPFILE"
sudo mkswap "$SWAPFILE" >/dev/null
sudo swapon "$SWAPFILE"

# Persist
if ! grep -q "^${SWAPFILE}[[:space:]]" /etc/fstab; then
  echo "${SWAPFILE} none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
  log "$(t task.swap.fstab.added)"
else
  log "$(t task.swap.fstab.exists)"
fi

log "$(t task.swap.check)"
free -h || true
swapon --show || true

log "$(t task.swap.done)"
