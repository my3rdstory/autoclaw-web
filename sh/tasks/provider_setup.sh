#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../lib/common.sh"

log "$(t task.provider.start)"

need_cmd jq

STATE_DIR="${AUTOCLAW_STATE:-$(pwd)/sh/state}"
SECRETS="$STATE_DIR/secrets.json"
FLAG="$STATE_DIR/provider_ok.json"
TS="$(date +%Y%m%d-%H%M%S)"

CONFIG_DIR="$HOME/.openclaw"
CONFIG_PATH="$CONFIG_DIR/openclaw.json"
BACKUP_DIR="$CONFIG_DIR/backup/autoclaw"

mkdir -p "$CONFIG_DIR" "$BACKUP_DIR" "$STATE_DIR"

if [[ ! -f "$CONFIG_PATH" ]]; then
  die "openclaw.json not found: $CONFIG_PATH (먼저 이전 단계에서 config를 생성해 주세요)"
fi

if [[ -f "$CONFIG_PATH" ]]; then
  cp "$CONFIG_PATH" "$BACKUP_DIR/openclaw.json.$TS.provider.bak"
  log "provider: backup=$BACKUP_DIR/openclaw.json.$TS.provider.bak"
fi

PROVIDER=""
OPENAI_AUTH=""
MODEL=""
OPENAI_API_KEY=""
ANTHROPIC_API_KEY=""
GEMINI_API_KEY=""

if [[ -f "$SECRETS" ]]; then
  PROVIDER="$(jq -r '.provider // empty' "$SECRETS")"
  OPENAI_AUTH="$(jq -r '.openaiAuth // empty' "$SECRETS")"
  MODEL="$(jq -r '.model // empty' "$SECRETS")"
  OPENAI_API_KEY="$(jq -r '.openaiApiKey // empty' "$SECRETS")"
  ANTHROPIC_API_KEY="$(jq -r '.anthropicApiKey // empty' "$SECRETS")"
  GEMINI_API_KEY="$(jq -r '.geminiApiKey // empty' "$SECRETS")"
fi

if [[ -z "$PROVIDER" || -z "$MODEL" ]]; then
  die "provider/model 값이 비어 있습니다. (대시보드 8단계에서 선택 후 저장해 주세요)"
fi

TMP="$CONFIG_PATH.tmp.$TS"

jq \
  --arg provider "$PROVIDER" \
  --arg openaiAuth "$OPENAI_AUTH" \
  --arg model "$MODEL" \
  --arg openaiApiKey "$OPENAI_API_KEY" \
  --arg anthropicApiKey "$ANTHROPIC_API_KEY" \
  --arg geminiApiKey "$GEMINI_API_KEY" \
  '
  . as $cfg
  | ($cfg.env // {}) as $env
  | ($cfg.agents // {}) as $agents
  | ($agents.defaults // {}) as $defaults
  | ($defaults.model // {}) as $modelCfg

  | .agents = ($agents
      | .defaults = ($defaults
          | .model = ($modelCfg
              | .primary = $model
            )
        )
    )

  | .env = (
      $env
      + (if $provider == "openai" and ($openaiApiKey|length) > 0 then { OPENAI_API_KEY: $openaiApiKey } else {} end)
      + (if $provider == "anthropic" and ($anthropicApiKey|length) > 0 then { ANTHROPIC_API_KEY: $anthropicApiKey } else {} end)
      + (if $provider == "google" and ($geminiApiKey|length) > 0 then { GEMINI_API_KEY: $geminiApiKey } else {} end)
    )
  ' \
  "$CONFIG_PATH" > "$TMP"

mv "$TMP" "$CONFIG_PATH"

# Success flag
cat > "$FLAG" <<JSON
{ "ok": true, "provider": "${PROVIDER}", "model": "${MODEL}", "checkedAt": "${TS}" }
JSON

log "$(printf "$(t task.provider.flag)" "$FLAG")"

if [[ "$PROVIDER" == "openai-codex" ]]; then
  log "$(t task.provider.oauth.note1)"
  log "$(t task.provider.oauth.note2)"
  log "$(t task.provider.oauth.note3)"
fi

log "$(t task.provider.done)"
