#!/usr/bin/env bash
set -euo pipefail

declare -gA I18N=()

# common
I18N[common.error]="ERROR"

# tasks - doctor
I18N[task.doctor.start]="doctor: start — checking environment."
I18N[task.doctor.done]="doctor: done"

# prereqs
I18N[task.prereqs.start]="prereqs: start — installing required packages (skip if already installed)."
I18N[task.prereqs.done]="prereqs: done"

# swap
I18N[task.swap.start]="swap: start — configure swap to prevent OOM on low-memory machines (recommended)."
I18N[task.swap.skip]="swap: swap is already enabled → skip"
I18N[task.swap.creating]="swap: no swap detected → creating %s swapfile (%s)"
I18N[task.swap.fstab.added]="swap: persisted in /etc/fstab"
I18N[task.swap.fstab.exists]="swap: already present in /etc/fstab"
I18N[task.swap.check]="swap: verify"
I18N[task.swap.done]="swap: done"

# node+pnpm
I18N[task.node_pnpm.start]="node: start — install/verify Node.js and pnpm."
I18N[task.node_pnpm.done]="node: done"

# openclaw cli
I18N[task.openclaw.install.start]="openclaw(cli): start — installing OpenClaw CLI."
I18N[task.openclaw.install.done]="openclaw(cli): done"

# config
I18N[task.config.start]="config: start — generate/backup/patch openclaw.json (apply dashboard inputs)."
I18N[task.config.backup]="config: existing config detected → creating backup"
I18N[task.config.none]="config: no existing config → writing minimal skeleton"
I18N[task.config.done]="config: done"

# gateway
I18N[task.gateway.start]="gateway: start — install/start OpenClaw gateway service and verify status."
I18N[task.gateway.lowmem]="gateway: low-mem detected(mem=%sMB swap=%sMB) → applying NODE_OPTIONS=%s"
I18N[task.gateway.install]="gateway: gateway install (register service)"
I18N[task.gateway.start_cmd]="gateway: gateway start"
I18N[task.gateway.status]="gateway: gateway status"
I18N[task.gateway.oom]="gateway: ERROR: Node heap out of memory detected"
I18N[task.gateway.status_fail]="gateway: ERROR: gateway status failed"
I18N[task.gateway.flag]="gateway: flag written: %s"
I18N[task.gateway.done]="gateway: done"

# provider
I18N[task.provider.start]="provider: start — apply provider/model/API key settings to openclaw.json."
I18N[task.provider.flag]="provider: flag written: %s"
I18N[task.provider.oauth.note1]="provider: NOTE: OpenAI Codex (OAuth) requires a separate login step."
I18N[task.provider.oauth.note2]="provider: NOTE: run the following on the server terminal:"
I18N[task.provider.oauth.note3]="provider:   openclaw models auth login --provider openai-codex"
I18N[task.provider.done]="provider: done"

# channels (telegram)
I18N[task.channels.start]="channels: start — apply Telegram channel settings to openclaw.json."
I18N[task.channels.done]="channels: done"
I18N[task.channels.flag]="channels: flag written: %s"
