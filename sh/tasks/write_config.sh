#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "$(t task.config.start)"

need_cmd jq

STATE_DIR="${AUTOCLAW_STATE:-$(pwd)/sh/state}"
SECRETS="$STATE_DIR/secrets.json"

CONFIG_DIR="$HOME/.openclaw"
CONFIG_PATH="$CONFIG_DIR/openclaw.json"
BACKUP_DIR="$CONFIG_DIR/backup/autoclaw"
TS="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$CONFIG_DIR" "$BACKUP_DIR"

if [[ -f "$CONFIG_PATH" ]]; then
  log "$(t task.config.backup)"
  cp "$CONFIG_PATH" "$BACKUP_DIR/openclaw.json.$TS.bak"
  log "config: backup=$BACKUP_DIR/openclaw.json.$TS.bak"
else
  log "$(t task.config.none)"
  cat > "$CONFIG_PATH" <<'JSON'
{
  "commands": { "native": "auto", "nativeSkills": "auto" },
  "gateway": { "mode": "local", "bind": "loopback", "auth": { "mode": "token" } }
}
JSON
fi

if [[ -f "$SECRETS" ]]; then
  log "config: secrets.json 감지 → 값 반영"
else
  log "config: secrets.json 없음 → 반영할 비밀값이 없다 (스킵)"
fi

# Extract values (may be empty)
GATEWAY_TOKEN=""
TELEGRAM_TOKEN=""
EXTRA_ENV='{}'

if [[ -f "$SECRETS" ]]; then
  GATEWAY_TOKEN="$(jq -r '.gatewayToken // empty' "$SECRETS")"
  TELEGRAM_TOKEN="$(jq -r '.telegramToken // empty' "$SECRETS")"
  EXTRA_ENV="$(jq -c '.extraEnv // {}' "$SECRETS")"
fi

# Patch config
TMP="$CONFIG_PATH.tmp.$TS"

jq \
  --arg gatewayToken "$GATEWAY_TOKEN" \
  --arg telegramToken "$TELEGRAM_TOKEN" \
    --argjson extraEnv "$EXTRA_ENV" \
  '
  . as $cfg
  | ($cfg.commands // {native:"auto", nativeSkills:"auto"}) as $commands
  | ($cfg.gateway // {}) as $gateway
  | ($cfg.env // {}) as $env
  | ($cfg.channels // {}) as $channels

  | .commands = $commands
  | .gateway = ($gateway
      | .mode = (.mode // "local")
      | .bind = (.bind // "loopback")
      | .port = (.port // 18790)
      | .auth = (.auth // {mode:"token"})
      | (if ($gatewayToken|length) > 0 then .auth.token = $gatewayToken else . end)
    )

  | .env = ($env + $extraEnv)

  | (if ($telegramToken|length) > 0 then
      .channels = ($channels + {
        telegram: (
          ($channels.telegram // {})
          + { enabled: true, botToken: $telegramToken, dmPolicy: "allowlist", groupPolicy: "allowlist", allowFrom: ([]), streamMode: "partial" }
        )
      })
    else
      .
    end)
  ' \
  "$CONFIG_PATH" > "$TMP"

mv "$TMP" "$CONFIG_PATH"

log "config: 작성 완료: $CONFIG_PATH"
log "config: NOTE: telegram allowFrom은 아직 비어있다(초보 안전 기본값). 필요 시 대시보드에서 추후 입력 기능 추가."
log "$(t task.config.done)"
