#!/usr/bin/env bash
set -euo pipefail

declare -gA I18N=()

# common
I18N[common.error]="ERROR"

# tasks - doctor
I18N[task.doctor.start]="doctor: 시작 — 기본 환경을 점검합니다."
I18N[task.doctor.done]="doctor: 완료"

# prereqs
I18N[task.prereqs.start]="prereqs: 시작 — 필수 패키지를 설치합니다(이미 있으면 스킵)."
I18N[task.prereqs.done]="prereqs: 완료"

# swap
I18N[task.swap.start]="swap: 시작 — RAM 부족(OOM) 방지를 위해 스왑을 설정합니다(권장)"
I18N[task.swap.skip]="swap: 이미 스왑이 활성화되어 있습니다 → 스킵"
I18N[task.swap.creating]="swap: 현재 스왑 없음 → %s 스왑파일 생성 시도 (%s)"
I18N[task.swap.fstab.added]="swap: /etc/fstab에 영구 등록"
I18N[task.swap.fstab.exists]="swap: /etc/fstab에 이미 등록되어 있습니다"
I18N[task.swap.check]="swap: 확인"
I18N[task.swap.done]="swap: 완료"

# node+pnpm
I18N[task.node_pnpm.start]="node: 시작 — Node.js와 pnpm을 설치/검증합니다."
I18N[task.node_pnpm.done]="node: 완료"

# openclaw cli
I18N[task.openclaw.install.start]="openclaw(cli): 시작 — OpenClaw CLI를 설치합니다."
I18N[task.openclaw.install.done]="openclaw(cli): 완료"

# config
I18N[task.config.start]="config: 시작 — openclaw.json 생성/백업/패치(대시보드 입력값 반영)"
I18N[task.config.backup]="config: 기존 config 발견 → 백업 생성"
I18N[task.config.none]="config: 기존 config 없음 → 최소 골격 생성"
I18N[task.config.done]="config: 완료"

# gateway
I18N[task.gateway.start]="gateway: 시작 — OpenClaw gateway 서비스를 설치/시작하고 상태를 확인합니다."
I18N[task.gateway.lowmem]="gateway: low-mem 감지(mem=%sMB swap=%sMB) → NODE_OPTIONS=%s 적용"
I18N[task.gateway.install]="gateway: gateway install (서비스 등록)"
I18N[task.gateway.start_cmd]="gateway: gateway start"
I18N[task.gateway.status]="gateway: gateway status"
I18N[task.gateway.oom]="gateway: ERROR: Node heap out of memory 감지"
I18N[task.gateway.status_fail]="gateway: ERROR: gateway status 실패"
I18N[task.gateway.flag]="gateway: flag written: %s"
I18N[task.gateway.done]="gateway: 완료"

# provider
I18N[task.provider.start]="provider: 시작 — 제공자/모델/API Key 설정을 openclaw.json에 반영합니다."
I18N[task.provider.flag]="provider: flag written: %s"
I18N[task.provider.oauth.note1]="provider: NOTE: OpenAI Codex(OAuth)는 별도 로그인 절차가 필요합니다."
I18N[task.provider.oauth.note2]="provider: NOTE: 서버 터미널에서 아래 명령을 실행해 주세요:"
I18N[task.provider.oauth.note3]="provider:   openclaw models auth login --provider openai-codex"
I18N[task.provider.done]="provider: 완료"

# channels (telegram)
I18N[task.channels.start]="channels: 시작 — 채널(텔레그램) 설정을 openclaw.json에 반영합니다."
I18N[task.channels.done]="channels: 완료"
I18N[task.channels.flag]="channels: flag written: %s"
