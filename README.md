# 오토클로 (autoclaw)

초보자도 **Ubuntu/Debian 환경에서 OpenClaw를 설치/설정**할 수 있게 도와주는 “설치 마법사 웹 대시보드”입니다.

- **목표:** 서버에 접속(IP/localhost) → 인증번호 로그인 → 단계별 버튼 클릭으로 설치/설정 완료
- **원칙:** 초보자가 가장 자주 막히는 지점(캐시/권한/systemd/메모리/OOM)을 자동 감지하고, 안전하게 안내합니다.

대시보드 구성
- 왼쪽: 전체 단계(진단 → 패키지 → Node/pnpm → OpenClaw 설치 → 설정 → 서비스)
- 가운데: 현재 단계 설명 + 실행 버튼
- 오른쪽: 상세 진행 로그

> 1차 목표: **“성공률”** — 최소한의 지식으로도 설치를 끝내게 하기

---

## 준비물

- Ubuntu 또는 Debian 환경 1개
  - **일반 VPS** (공인 IP 접속)
  - 또는 **Windows + WSL(Ubuntu)** (localhost 접속)
- SSH/터미널 접근 권한

---

## 0) 시작: 터미널에서 실행(공통)

아래 한 줄을 **대상 환경 터미널에서** 실행하면 오토클로를 설치/실행합니다.

```bash
curl -fsSL "https://raw.githubusercontent.com/my3rdstory/autoclaw-web/main/scripts/quickstart.sh?ts=$(date +%s)" | bash
```

quickstart가 하는 일
- apt 업데이트 및 기본 패키지 설치(curl/git/ca-certificates)
- Node.js LTS(NodeSource) 설치
- pnpm 설치(corepack)
- 레포 clone/pull(기본: `$HOME/autoclaw`, 필요 시 `AUTOCLAW_DIR`로 변경) + 의존성 설치
- 웹 대시보드 실행

---

## 1) 일반 VPS 환경에서 진행 방법

### 접속 주소
- quickstart 출력의 안내 주소로 접속합니다.
  - 보통: `http://<server-ip>:8787`
  - (가능하면) 공인 IP 자동 감지 결과를 그대로 사용

### 왜 이렇게 했나?
- 초보자는 SSH 터널/리버스 프록시 없이도 바로 확인할 수 있어야 합니다.
- 대신 대시보드는 **인증번호(24자) 로그인**으로 보호합니다.

### 진행 순서(요약)
1) 브라우저 접속 → 인증번호 생성/기록 → 로그인
2) 마법사 단계대로 진행
3) 메모리(1GB VPS)에서는 **스왑 설정**을 먼저 진행(권장)

---

## 2) WSL(Windows + WSL Ubuntu) 환경에서 진행 방법

### 핵심 차이점
- WSL은 “서버”라기보다 **내 PC 내부의 리눅스 환경**이라서,
  - 접속은 **Windows 브라우저에서 localhost**가 가장 자연스럽습니다.
  - 서비스 단계에서 **systemd 활성화**가 필요할 수 있습니다.

### 접속 주소(WSL)
- 기본: `http://localhost:8787`

### 터미널을 닫으면 종료되나?
네. 기본 quickstart는 대시보드를 **포그라운드로 실행**하므로, WSL 터미널을 닫거나 세션이 종료되면 대시보드도 같이 종료됩니다.

계속 실행하고 싶다면(권장 순):

1) **tmux 사용(권장)**
```bash
tmux new -s autoclaw
cd "$HOME/autoclaw"
AUTOCLAW_BIND=127.0.0.1 AUTOCLAW_PORT=8787 node server/index.js
```

2) **nohup 백그라운드 실행**
```bash
cd "$HOME/autoclaw"
nohup env AUTOCLAW_BIND=127.0.0.1 AUTOCLAW_PORT=8787 node server/index.js > autoclaw.log 2>&1 &
```

### WSL systemd 활성화(중요)
WSL에서 systemd가 꺼져 있으면, quickstart가 먼저 다음을 수행합니다.
- `/etc/wsl.conf`에 `systemd=true` 설정(필요 시 백업 포함)
- 그리고 **대시보드를 띄우기 전에 종료**하면서 아래를 안내합니다.

Windows PowerShell에서:
```powershell
wsl --shutdown
```
그 다음 WSL을 다시 열고 quickstart를 **다시 실행**하면 대시보드가 실행됩니다.

### 왜 이렇게 했나?
- systemd 활성화는 **WSL 전체 재시작**이 필요합니다.
- 웹앱을 띄운 뒤에 WSL을 셧다운하면 웹앱도 같이 죽어서 오히려 더 헷갈립니다.
- 그래서 “웹앱 실행 전” 터미널 단계에서 안내하고, 2회 실행 플로우로 안정화했습니다.

---

## 3) 설치 후 운영(오토클로 없이 OpenClaw만 실행)

결론: 설치가 끝난 뒤에는 **오토클로(autoclaw-web) 자체는 필수가 아닙니다.** 오토클로는 설치/설정 마법사(UI)일 뿐이고, 실제로 동작하는 건 OpenClaw의 **gateway/node 서비스**입니다.

### OpenClaw 실행/상태 확인

- Gateway
```bash
openclaw gateway status
openclaw gateway start
openclaw gateway stop
```

- Node host
```bash
openclaw node status
openclaw node restart
openclaw node stop
```

> 설치 마법사(7~10단계)에서 service install/start를 완료했다면, 이후에는 위 명령으로만 운영해도 됩니다.

### WSL 주의사항(중요)

- WSL은 **리눅스가 Windows 위에서 돌아가는 세션**이라서, **WSL을 종료/셧다운하면 그 안에서 동작하던 OpenClaw 서비스도 같이 종료**됩니다.
- 즉, 텔레그램이 잘 되다가도 Windows에서 `wsl --shutdown`을 하거나 WSL 터미널을 닫아 WSL이 내려가면, OpenClaw도 멈춥니다.

권장:
- WSL 환경은 “상시 서버”보다는 개발/테스트 용도로 쓰고,
- 24/7 운영이 목적이면 VPS나 항상 켜져 있는 리눅스 머신에서 운영하는 편이 안정적입니다.

---

## 3) 대시보드 보안(중요)

- 대시보드는 **인증번호(24자) 로그인**으로 보호됩니다.
- 인증번호는 한 번만 표시되며, 잊으면 복구가 어렵습니다.

### 인증번호를 잊었을 때(복구)
SSH/터미널로 서버에 접속해서 아래 파일을 삭제하면, 다음 접속 시 인증번호를 다시 발급받을 수 있습니다.

```bash
# 기본 설치 경로(기본값): $HOME/autoclaw
rm -f "$HOME/autoclaw/sh/state/auth.json"
```

> 주의: 인증번호는 재발급 시 새 것으로 바뀌며, 기존 인증번호는 더 이상 동작하지 않습니다.

---

## 삭제/언인스톨(설치한 OpenClaw 제거)

> 아래는 “오토클로로 설치/등록된 OpenClaw”를 제거하는 절차입니다. **자동으로 실행되진 않으며**, 실행 전 현재 사용 중인 설정/토큰이 있다면 백업을 권장합니다.

### 1) 오토클로 대시보드 중지
- 터미널에서 오토클로를 실행 중이었다면(quickstart 마지막 줄), 해당 터미널에서 `Ctrl+C`로 종료합니다.

### 2) 오토클로 코드 제거(선택)
```bash
# 기본 설치 경로(기본값): $HOME/autoclaw
rm -rf "$HOME/autoclaw"
```

### 3) OpenClaw 서비스 중지/삭제
오토클로는 설치 과정에서 OpenClaw의 **gateway/node 서비스를 systemd(또는 launchd)에 등록**할 수 있습니다. 아래로 제거합니다.

```bash
sudo openclaw gateway stop || true
sudo openclaw gateway uninstall || true

sudo openclaw node stop || true
sudo openclaw node uninstall || true
```

### 4) OpenClaw 설정/상태 파일 제거(선택)
OpenClaw는 기본적으로 `~/.openclaw/`에 설정/세션/로그를 저장합니다. 완전 삭제를 원하면 아래를 실행합니다.

```bash
rm -rf ~/.openclaw
```

### 5) OpenClaw CLI 제거(선택)
OpenClaw CLI를 전역 설치(npm -g)로 했던 경우:

```bash
sudo npm rm -g openclaw || true
```

> 주의: Node.js/pnpm을 다른 용도로 쓰고 있다면 제거하지 마세요.

---

## 4) 문제를 줄이기 위한 자동 처리(왜 필요한가)

오토클로는 “초보가 실제로 막히는 지점”을 자동으로 흡수합니다.

- **캐시 문제:** index.html 캐시 방지(no-store)
- **저사양 VPS(1GB) OOM:** 스왑 단계 제공 + gateway/node 단계에서 heap OOM 감지 및 완화
- **단계 완료 판정:** 성공 시 플래그 파일을 기록해 UI가 정확히 완료로 표시

---

## 코드 구조(요약)

```
autoclaw-web/
├─ scripts/quickstart.sh          # curl | bash 부트스트랩 (WSL systemd 안내 포함)
├─ server/
│  ├─ index.js                   # 웹서버 + API + 작업 실행 + SSE 로그
│  └─ auth.js                    # 인증번호 생성/검증(pbkdf2) + 세션
├─ web/
│  └─ index.html                 # 단일 페이지 UI(단계/로그/인증 포함)
├─ sh/
│  ├─ lib/
│  │  ├─ common.sh               # 공통 유틸(log/die/need_cmd) + shell i18n 로드
│  │  └─ i18n.sh                 # AUTOCLAW_LANG/LANG 기반 터미널 언어 결정 + t()
│  ├─ i18n/                      # shell 언어팩(ko/en)
│  ├─ tasks/                     # 단계별 실행 스크립트(의미 기반 파일명)
│  └─ state/                     # 런타임 상태(secrets/auth/flags/runs 로그)
├─ README.md
└─ package.json
```

### 언어(i18n)

- 웹(UI) 언어
  - 인증 화면 및 로그인 후 상단의 **KO/EN 버튼**으로 즉시 전환됩니다.
  - EN 선택 시, 진행 로그(pre#log) 자체는 운영/디버깅 편의를 위해 **한국어 로그를 유지**합니다.

- 터미널/쉘(task) 언어
  - 쉘 스크립트는 `AUTOCLAW_LANG`가 있으면 그 값을 우선 사용합니다. (예: `AUTOCLAW_LANG=en`)
  - 없으면 `LC_ALL`/`LANG` 로케일을 보고 ko/en을 선택합니다.
  - 관련 코드: `sh/lib/i18n.sh`, `sh/i18n/`

### 상태 파일(sh/state) 예시
- `secrets.json`: 대시보드 입력값(토큰/API key 등)
- `auth.json`: 인증번호 해시
- `runs/*.log`: 단계 실행 로그
- `*_ok.json`: 단계 완료 플래그(gateway/provider/channels/node 등)

---

## 참고 링크

- GitHub: https://github.com/my3rdstory/autoclaw-web
- OpenClaw Docs: https://docs.openclaw.ai
