#!/usr/bin/env bash
set -euo pipefail

# Shell i18n (no external deps)
# - Language source priority:
#   1) AUTOCLAW_LANG
#   2) LC_ALL / LANG (ko* -> ko, else en)
#   3) default: ko

_i18n_lang_detect() {
  if [[ -n "${AUTOCLAW_LANG:-}" ]]; then
    echo "$AUTOCLAW_LANG"; return 0
  fi
  local loc="${LC_ALL:-${LANG:-}}"
  if [[ "$loc" == ko* || "$loc" == *"ko_KR"* ]]; then
    echo "ko"; return 0
  fi
  echo "en"
}

AUTOCLAW_LANG="$(_i18n_lang_detect)"

# load dictionaries
# shellcheck disable=SC1090
case "$AUTOCLAW_LANG" in
  ko) source "$(dirname "$0")/../i18n/ko.sh" ;;
  en) source "$(dirname "$0")/../i18n/en.sh" ;;
  *)  source "$(dirname "$0")/../i18n/ko.sh" ;;
esac

# t <key>
# If missing, returns the key itself (so logs remain readable).
t() {
  local key="$1"
  local v="${I18N[$key]:-}"
  if [[ -n "$v" ]]; then
    printf '%s' "$v"
  else
    printf '%s' "$key"
  fi
}
