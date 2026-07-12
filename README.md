# al-hub npx

`al-hub/npx`는 `npx github:al-hub/npx`로 바로 실행할 수 있는 개인용 로컬 운영 런처다.

목표는 복잡한 CLI 프레임워크를 만들지 않고, 자주 쓰는 점검/설정/모니터링 작업을 작은 Bash 스크립트로 묶는 것이다. Node.js는 `npx` 진입점 역할만 하고, 실제 기능은 `scripts/*.sh`에서 처리한다.

## Purpose

이 프로젝트의 목적은 세 가지로 구분한다.

- `bootstrap`: 새 환경에서 기본 폴더와 개발 환경을 빠르게 준비한다.
- `diagnostics`: Node, Git, WSL, API 키 등 현재 환경 상태를 점검한다.
- `observability`: 시스템 리소스와 Codex 세션 토큰 사용량을 터미널에서 바로 확인한다.

현재는 개인용 워크플로우에 맞춘 최소 구현을 우선한다. 이후 업무용 또는 팀용으로 확장할 수 있도록 명령 경계와 문서 구조만 분리해 둔다.

## Usage

```bash
npx github:al-hub/npx
npx github:al-hub/npx doctor
npx github:al-hub/npx setup
npx github:al-hub/npx setup-fzf
npx github:al-hub/npx setup-opencode
npx github:al-hub/npx setup-opencode-omo
npx github:al-hub/npx monitor
npx github:al-hub/npx ccusage
npx github:al-hub/npx ccusage --watch
npx github:al-hub/npx tokens
```

Local run:

```bash
node bin/al.js
node bin/al.js doctor
node bin/al.js setup
node bin/al.js setup-fzf
node bin/al.js setup-opencode
node bin/al.js setup-opencode-omo
node bin/al.js monitor
node bin/al.js ccusage
node bin/al.js ccusage --watch
node bin/al.js tokens
node bin/al.js help
```

## Commands

- `doctor`: Node, npm, npx, Git, OS, WSL, API 키 상태를 점검한다.
- `setup`: 기본 개발 폴더를 생성한다.
- `setup-fzf`: fzf 공식 저장소(git clone + install)로 설치/업데이트한다.
- `setup-opencode`: opencode 설정(글로벌/프로젝트)을 프로필별로 적용한다.
- `setup-opencode-omo`: oh-my-openagent(Bun 기반)를 설치하고 구독별 모델을 구성한다.
- `monitor`: CPU, 메모리, GPU, 디스크, 네트워크 상태를 실시간 표시한다.
- `ccusage`: Codex 세션별 토큰/비용 요약 표를 출력한다.
- `tokens`: 현재 워크스페이스의 최신 Codex 세션 토큰을 실시간 표시한다.
- `exit`: 메뉴를 종료한다.

Live screens such as `monitor`, `ccusage --watch`, and `tokens` exit when you press `q`.

## Token Usage

`ccusage`와 `tokens`는 Codex 상태 데이터베이스를 읽는다.

기본 탐색 경로:

```txt
~/.codex/state_*.sqlite
```

동작 방식:

- `ccusage`: `threads` 테이블을 읽어 세션별 `tokens_used`, 모델, 제목, 갱신 시간을 표로 요약한다.
- `tokens`: 같은 데이터를 현재 워크스페이스 기준으로 읽고, 최신 세션 중심의 live counter로 표시한다.
- 기본적으로 현재 `cwd`와 같은 워크스페이스 세션만 보여주며, 없으면 전체 세션으로 fallback한다.
- `--all` 옵션을 주면 전체 세션을 표시한다.

비용 추정:

- Codex DB에는 입력/출력 토큰 분리가 없으므로 비용은 총 토큰 기반 추정치다.
- 가격표 파일이 있으면 모델별 단가를 우선 사용한다.
- 가격표가 없으면 기본 추정 단가 `1.00 USD / 1M tokens`를 사용한다.
- 기본 단가는 `CCUSAGE_DEFAULT_USD_PER_MILLION` 또는 `--default-rate`로 바꿀 수 있다.
- 가격표를 사용하려면 `~/.codex/ccusage-prices.tsv` 또는 `CCUSAGE_PRICE_FILE`을 설정한다.
- 파일 형식은 `model<TAB>usd_per_million_tokens`다.

예시:

```txt
gpt-5.5	10.00
gpt-5.4-mini	1.00
```

## Structure

```txt
npx/
├─ package.json
├─ bin/
│  └─ al.js
├─ scripts/
│  ├─ menu.sh
│  ├─ doctor.sh
│  ├─ setup.sh
│  ├─ setup-fzf.sh
│  ├─ setup-opencode.sh
│  ├─ setup-opencode-omo.sh
│  ├─ monitor.sh
│  ├─ ccusage.sh
│  ├─ tokens.sh
│  └─ templates/
│     ├─ opencode.personal.jsonc
│     ├─ opencode.work.jsonc
│     ├─ tui.personal.jsonc
│     └─ tui.work.jsonc
└─ docs/
   └─ ROADMAP.md
```

## Design Principles

- `bin/al.js`는 thin wrapper로 유지한다.
- 명령 하나는 `scripts/*.sh` 하나로 추가한다.
- 외부 npm dependency는 추가하지 않는다.
- 개인용 기본값을 우선하되, 환경변수와 옵션으로 확장 가능하게 둔다.
- live 화면은 공통적으로 `q`로 종료한다.

## Roadmap

향후 확장 계획은 [docs/ROADMAP.md](docs/ROADMAP.md)를 참고한다.
