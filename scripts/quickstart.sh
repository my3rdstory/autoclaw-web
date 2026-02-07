#!/usr/bin/env bash
set -euo pipefail

# AutoClaw quickstart (Ubuntu/Debian VPS)
# - Installs base packages (curl, git, ca-certificates)
# - Installs Node.js LTS (NodeSource) + pnpm
# - Starts the AutoClaw dashboard

PORT="${AUTOCLAW_PORT:-8787}"

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

# Default bind:
# - VPS: 0.0.0.0 (IP direct)
# - WSL: 127.0.0.1 (Windows에서 localhost 접속)
if [[ -n "${AUTOCLAW_BIND:-}" ]]; then
  BIND="$AUTOCLAW_BIND"
else
  if is_wsl; then
    BIND="127.0.0.1"
  else
    BIND="0.0.0.0"
  fi
fi

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

if [[ "$(uname -s)" != "Linux" ]]; then
  log "$(txt "ERROR: Linux에서만 지원" "ERROR: Linux only")"
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  log "$(txt "ERROR: /etc/os-release 없음 (배포판 감지 실패)" "ERROR: /etc/os-release not found (distro detection failed)")"
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" ]]; then
  log "ERROR: 현재는 ubuntu/debian만 지원 (ID=${ID:-unknown})"
  exit 1
fi

log "1) 기본 패키지 설치 (curl/git/ca-certificates)"
sudo apt-get update -y
sudo apt-get install -y curl git ca-certificates

# --- WSL: enable systemd before starting the dashboard ---
if is_wsl; then
  log "$(txt "WSL 감지됨" "WSL detected")"
  if [[ ! -d /run/systemd/system ]]; then
    log "$(txt "WSL systemd가 비활성 상태입니다. (대시보드 실행 전에 활성화가 필요합니다)" "WSL systemd is disabled. (Enable it before starting the dashboard)")"

    WSL_CONF="/etc/wsl.conf"
    TS="$(date +%Y%m%d-%H%M%S)"

    if [[ -f "$WSL_CONF" ]]; then
      sudo cp "$WSL_CONF" "$WSL_CONF.autoclaw.${TS}.bak"
      log "wsl.conf 백업: $WSL_CONF.autoclaw.${TS}.bak"
    fi

    # Ensure [boot] systemd=true
    if [[ ! -f "$WSL_CONF" ]]; then
      cat <<'EOF' | sudo tee "$WSL_CONF" >/dev/null
[boot]
systemd=true
EOF
    else
      # add section if missing
      if ! grep -q '^\[boot\]' "$WSL_CONF"; then
        printf '\n[boot]\n' | sudo tee -a "$WSL_CONF" >/dev/null
      fi
      # set/replace systemd=true inside [boot]
      sudo awk '
        BEGIN{inboot=0;done=0}
        /^\[boot\]/{inboot=1;print;next}
        /^\[/{if(inboot && !done){print "systemd=true";done=1} inboot=0;print;next}
        {if(inboot && $0 ~ /^systemd=/){print "systemd=true";done=1;next} print}
        END{if(inboot && !done){print "systemd=true"}}
      ' "$WSL_CONF" | sudo tee "$WSL_CONF" >/dev/null
    fi

    log "$(txt "WSL systemd 설정을 적용하려면 Windows PowerShell에서 아래를 실행해 주세요:" "To apply WSL systemd config, run this in Windows PowerShell:")"
    log "  wsl --shutdown"
    log "$(txt "그 다음 WSL을 다시 열고, 이 quickstart를 다시 실행해 주세요." "Then reopen WSL and run this quickstart again.")"
    exit 0
  else
    log "WSL systemd 활성 상태 확인됨"
  fi
fi

log "2) Node.js LTS(NodeSource) 설치"
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

log "3) pnpm 설치(corepack)"
# corepack enable needs to run as root on many servers (global shim)
sudo corepack enable || true
sudo corepack prepare pnpm@latest --activate

REPO="${AUTOCLAW_REPO:-https://github.com/my3rdstory/autoclaw-web.git}"
# Default install dir: user home (avoids permission issues on WSL/VPS). Override with AUTOCLAW_DIR.
DIR="${AUTOCLAW_DIR:-$HOME/autoclaw}"

log "4) autoclaw-web 코드 받기"
log "   - repo: $REPO"
log "   - dir : $DIR"

# Determine the non-root owner user (the interactive user running this script).
OWNER_USER="${SUDO_USER:-$(id -un)}"
OWNER_GROUP="$OWNER_USER"

# Ensure parent dir exists and is writable for the owner user.
PARENT_DIR="$(dirname "$DIR")"
sudo mkdir -p "$PARENT_DIR"
# Make /opt (or chosen parent) writable by the interactive user so git can create $DIR.
# Without this, git clone as non-root fails: "could not create work tree dir ... Permission denied"
sudo chown "$OWNER_USER":"$OWNER_GROUP" "$PARENT_DIR" || true
sudo chmod u+rwx "$PARENT_DIR" || true

is_opt_dir() {
  [[ "$DIR" == /opt/* ]]
}

if [[ -d "$DIR/.git" ]]; then
  # Updating an existing checkout
  if is_opt_dir; then
    log "   기존 폴더 감지 → git pull (root, then chown to $OWNER_USER)"
    sudo git -C "$DIR" pull --ff-only
  else
    log "   기존 폴더 감지 → git pull (user=$OWNER_USER)"
    sudo -u "$OWNER_USER" -H git -C "$DIR" pull --ff-only
  fi
else
  # Fresh checkout
  if is_opt_dir; then
    log "   신규 설치 → git clone (root, then chown to $OWNER_USER)"
    sudo rm -rf "$DIR"
    sudo git clone "$REPO" "$DIR"
  else
    log "   신규 설치 → git clone (user=$OWNER_USER)"
    sudo rm -rf "$DIR"
    sudo -u "$OWNER_USER" -H git clone "$REPO" "$DIR"
  fi
fi

# Ensure package managers can write (WSL/permissions edge cases)
sudo chown -R "$OWNER_USER":"$OWNER_GROUP" "$DIR" || true
sudo chmod -R u+rwX "$DIR" || true

log "5) autoclaw-web 의존성 설치"
cd "$DIR"
# prefer pnpm, fallback to npm
if command -v pnpm >/dev/null 2>&1; then
  # Install as the non-root owner user for consistent cache/home permissions.
  if [[ "$(id -un)" == "$OWNER_USER" ]]; then
    pnpm i
  else
    sudo -u "$OWNER_USER" -H pnpm i
  fi
else
  if [[ "$(id -un)" == "$OWNER_USER" ]]; then
    npm i
  else
    sudo -u "$OWNER_USER" -H npm i
  fi
fi

get_public_ip() {
  # Try multiple services with short timeouts (best-effort)
  for url in \
    "https://api.ipify.org" \
    "https://ifconfig.me" \
    "https://checkip.amazonaws.com"; do
    ip="$(curl -fsSL --max-time 3 --connect-timeout 2 "$url" 2>/dev/null | tr -d '\n\r ' || true)"
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$ip"
      return 0
    fi
  done
  return 1
}

LANG_CHOICE="${AUTOCLAW_LANG:-}"
if [[ -z "$LANG_CHOICE" ]]; then
  loc="${LC_ALL:-${LANG:-}}"
  if [[ "$loc" == ko* || "$loc" == *"ko_KR"* ]]; then
    LANG_CHOICE="ko"
  else
    LANG_CHOICE="en"
  fi
fi

# txt <ko> <en>
txt() {
  if [[ "$LANG_CHOICE" == "en" ]]; then
    printf %s "$2"
  else
    printf %s "$1"
  fi
}


PUBLIC_IP="$(get_public_ip || true)"

log "6) 대시보드 실행: bind=${BIND} port=${PORT}"
if is_wsl; then
  log "$(txt "   접속 주소(WSL): http://localhost:${PORT}" "   Open dashboard (WSL): http://localhost:${PORT}")"
else
  if [[ -n "$PUBLIC_IP" ]]; then
    log "   접속 주소(공인 IP 자동 감지): http://${PUBLIC_IP}:${PORT}"
  else
    log "   접속 주소: http://<server-ip>:${PORT}  (공인 IP 자동 감지 실패)"
  fi
fi

log "$(txt "   주의: 이 터미널을 닫으면 대시보드도 종료됩니다." "   Note: Closing this terminal will stop the dashboard.")"

export AUTOCLAW_PORT="$PORT"
export AUTOCLAW_BIND="$BIND"
node server/index.js
