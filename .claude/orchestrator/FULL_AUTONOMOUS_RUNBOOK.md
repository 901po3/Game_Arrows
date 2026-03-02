# Full Autonomous Runbook

개발자 개입을 최소화(또는 0에 가깝게) 하기 위한 운영 런북입니다.

## 0) 목적

- PM/Programmer/Reviewer가 오케스트레이터와 Unity MCP를 통해 작업을 자동 루프로 처리한다.
- 사람은 승인/우선순위/예외 대응만 담당한다.

## 1) 사전 체크 (5분)

1. Unity Editor 실행 + 프로젝트 오픈
2. MCP 연결 체크
   - `ProjectSettings/McpUnitySettings.json`에서 `AutoStartServer=true`, `Port=8090` 확인
   - 점검 스크립트 실행: `.claude/orchestrator/scripts/Test-McpUnityConnection.ps1`
3. 오케스트레이터 실행
   - `pwsh ./.claude/orchestrator/Orchestrator.ps1`
4. 팀 inbox 경로 확인
   - `~/.claude/teams/arrow-game/inboxes/team-lead.json`

## 2) 작업 발행

- PM은 Task ID + DoD(Definition of Done) 기반으로 작업 발행
- 템플릿: `.claude/orchestrator/AUTONOMOUS_WORK_TEMPLATES.md`
- 최종 보고는 계약 문서 준수: `.claude/orchestrator/TASK_UPDATE_CONTRACT.md`

## 3) 실행/검증 루프

- Programmer: Unity MCP 작업(씬/오브젝트/컴포넌트/UI) → 코드 수정(필요 시) → 테스트
- Reviewer: DoD 체크 + 승인/반려
- 오케스트레이터: 상태 전이/재배정 자동 처리

## 4) MCP 스모크 테스트 (권장)

아래 작업을 한 번 실행해 MCP 실동작을 검증한다.

- Task ID: `SMOKE-MCP-001`
- Goal: `Game 씬에 MCP_TestCube 생성 + SpriteRenderer 추가 + Position (0,0,0)`
- Done 조건:
  1) 씬 저장됨
  2) 오브젝트 존재 확인
  3) 최종 `task_update` 보고 수신

## 5) 실패 표준 처리

- `mcp_unavailable`: MCP 미연결/응답 없음 → `outcome=blocked`
- `invalid_json_block`: 최종 보고 블록 파싱 실패 → 재보고
- `processing_error` soft/hard:
  - soft: 재전송 요청
  - hard: non-idle 처리, 정상 보고 전 자동 진행 제한

## 6) 완전 자동 가능 범위

가능:
- GameObject 생성/삭제
- Component 추가/수정
- UI 구성/연결
- 씬 저장/테스트 실행

조건부:
- 에셋 제작(아트)은 외부 파이프라인 필요
- 최종 병합 승인/릴리즈 승인 정책은 사람 승인 유지 권장
