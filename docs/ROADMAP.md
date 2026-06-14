# al-hub npx Roadmap

이 문서는 `al-hub/npx`의 목적을 구분하고, 이후 확장을 위한 방향을 정리한다.

## Current Purpose

현재 프로젝트는 개인용 로컬 운영 런처다.

핵심 목적:

- 새 환경에서 빠르게 기본 상태를 만든다.
- 현재 개발 환경이 정상인지 점검한다.
- 터미널 안에서 시스템 상태와 Codex 토큰 사용량을 확인한다.

현재 범위:

- `npx github:al-hub/npx`로 실행 가능한 메뉴 제공
- 직접 명령 실행 지원
- Bash 기반 스크립트 중심 구현
- 외부 npm dependency 없는 최소 구조 유지

명확히 범위 밖인 것:

- 범용 CLI 프레임워크화
- 복잡한 플러그인 시스템
- 팀 공통 정책 강제
- 외부 서비스 대시보드 의존

## Functional Areas

### Bootstrap

환경 초기화를 담당한다.

현재 명령:

- `setup`

확장 후보:

- opencode 설정 설치/갱신
- dotfiles 설치 상태 점검
- SSH/GitHub 기본 연결 점검
- 개인용/업무용 프로필 선택

### Diagnostics

환경 상태 점검을 담당한다.

현재 명령:

- `doctor`

확장 후보:

- 필수 CLI 존재 여부 점검
- API 키별 provider 연결 테스트
- WSL, PATH, shell 설정 진단
- 문제 발견 시 해결 명령 안내

### Observability

터미널 기반 모니터링을 담당한다.

현재 명령:

- `monitor`
- `ccusage`
- `tokens`

확장 후보:

- 일별/월별 토큰 사용량 요약
- 모델별 토큰 사용량 분리
- 비용 계산용 가격표 관리 명령
- CSV/Markdown export

## Architecture Direction

현재 구조를 유지한다.

```txt
bin/al.js        npx 진입점
scripts/menu.sh 명령 라우터
scripts/*.sh    실제 기능
docs/*.md       설계와 운영 문서
```

확장 규칙:

- 새 기능은 우선 `scripts/{command}.sh`로 추가한다.
- 공통 로직이 세 개 이상 반복될 때만 `scripts/lib/` 도입을 검토한다.
- Node.js 로직은 인자 전달과 프로세스 실행 이상으로 키우지 않는다.
- 옵션은 Bash에서 직접 파싱하되, 복잡해지면 명령별로 분리한다.

## Near-Term Plan

1. 문서 정리
   - README는 사용법과 현재 구조를 설명한다.
   - ROADMAP은 목적, 영역, 확장 방향을 관리한다.

2. 토큰 사용량 개선
   - `ccusage`는 세션별 표로 유지한다.
   - `tokens`는 현재 세션 live counter로 유지한다.
   - 가격표 파일 예시와 관리 방법을 추가한다.

3. 환경 점검 강화
   - `doctor`에 Codex 상태 DB 존재 여부를 추가한다.
   - `doctor`에 Git remote와 branch 상태를 추가한다.
   - 문제 발견 시 다음 액션을 짧게 출력한다.

4. 설치/설정 확장
   - `setup`을 단순 폴더 생성에서 선택형 설정 설치로 확장한다.
   - opencode 설정은 개인용 기본값부터 시작한다.
   - 업무용 확장은 별도 profile 옵션으로 준비한다.

## Compatibility Notes

- Linux/WSL을 기본 실행 환경으로 둔다.
- macOS 지원은 가능하지만 `/proc`, `/sys`, `nvidia-smi` 의존 기능은 별도 fallback이 필요하다.
- Windows native shell은 현재 우선 지원 대상이 아니다.
- `ccusage`와 `tokens`는 Codex의 로컬 SQLite 상태 DB 구조에 의존한다.

## Done Criteria

프로젝트가 좋은 상태라고 볼 기준:

- `npx github:al-hub/npx` 실행 시 메뉴가 명확하다.
- 각 명령은 직접 실행과 메뉴 실행이 모두 된다.
- live 화면은 `q`로 종료된다.
- README만 읽어도 현재 기능을 사용할 수 있다.
- ROADMAP만 읽어도 다음 확장 방향을 이해할 수 있다.
