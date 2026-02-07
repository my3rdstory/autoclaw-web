#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "$(t task.channels.start)"

need_cmd jq

STATE_DIR="${AUTOCLAW_STATE:-$(pwd)/sh/state}"
SECRETS="$STATE_DIR/secrets.json"
FLAG="$STATE_DIR/channels_ok.json"
TS="$(date +%Y%m%d-%H%M%S)"

CONFIG_DIR="$HOME/.openclaw"
CONFIG_PATH="$CONFIG_DIR/openclaw.json"
BACKUP_DIR="$CONFIG_DIR/backup/autoclaw"

mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$STATE_DIR"

if [[ ! -f "$CONFIG_PATH" ]]; then
  die "openclaw.json not found: $CONFIG_PATH (먼저 이전 단계에서 config를 생성해 주세요)"
fi

cp "$CONFIG_PATH" "$BACKUP_DIR/openclaw.json.$TS.channels.bak"
log "channels: backup=$BACKUP_DIR/openclaw.json.$TS.channels.bak"

TELEGRAM_TOKEN=""
TELEGRAM_ALLOW_FROM=""

if [[ -f "$SECRETS" ]]; then
  TELEGRAM_TOKEN="$(jq -r '.telegramToken // empty' "$SECRETS")"
  TELEGRAM_ALLOW_FROM="$(jq -r '.telegramAllowFrom // empty' "$SECRETS")"
fi

if [[ -z "$TELEGRAM_TOKEN" ]]; then
  die "설정할 텔레그램 토큰이 없습니다. (대시보드 9단계에서 토큰 입력 후 저장해 주세요)"
fi

# Telegram allowFrom is required when telegram token is present.
if [[ -n "$TELEGRAM_TOKEN" && -z "$TELEGRAM_ALLOW_FROM" ]]; then
  die "Telegram allowFrom(사용자 ID)가 비어 있습니다. 9단계에서 숫자 ID를 입력해 주세요."
fi

TMP="$CONFIG_PATH.tmp.$TS"

jq \
  --arg telegramToken "$TELEGRAM_TOKEN" \
  --arg telegramAllowFrom "$TELEGRAM_ALLOW_FROM" \
  '
  . as $cfg
  | ($cfg.channels // {}) as $channels

  | (if ($telegramToken|length) > 0 then
      .channels = ($channels + {
        telegram: (
          ($channels.telegram // {})
          + {
              enabled: true,
              botToken: $telegramToken,
              dmPolicy: "allowlist",
              groupPolicy: "allowlist",
              allowFrom: [($telegramAllowFrom|tonumber)],
              streamMode: "partial"
            }
        )
      })
    else
      .
    end)
  ' \
  "$CONFIG_PATH" > "$TMP"

mv "$TMP" "$CONFIG_PATH"

cat > "$FLAG" <<JSON
{ "ok": true, "checkedAt": "${TS}" }
JSON

log "$(printf "$(t task.channels.flag)" "$FLAG")"
log "$(t task.channels.done)"
