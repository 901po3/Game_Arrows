# Agent Teams MVP Orchestrator

Agent Teams가 Idle 상태에 들어가도 자동으로 다음 작업을 배정하기 위한 로컬 오케스트레이터입니다.

## 제공 기능 (MVP)

- 이벤트 기반 감시
  - `docs/TODO.md` 변경 감시
  - `~/.claude/teams/<team>/inboxes/team-lead.json` 변경 감시
- 상태 머신 자동 전이
  - `NEW -> PLANNING -> PM_REVIEW -> READY_FOR_DEV -> IN_DEV -> CODE_REVIEW -> REWORK -> MERGE_READY -> DONE`
- 역할 기반 라우팅
  - 에이전트 이름이 `planner1`, `programmer2`처럼 바뀌어도 `role` 기준으로 자동 분배
  - 같은 역할 다중 인원은 idle 우선 + 라운드로빈으로 배정
- 자동 재할당 루프
  - PM 반려 시 Planner 재투입
  - Reviewer 반려 시 Programmer 재투입
- 핸드오프 커밋
  - 상태 전이 후 변경사항이 있으면 handoff 커밋 시도
- 작업 저장
  - `.claude/orchestrator/tasks/*.json`에 작업 상태 영속화

## 실행

PowerShell에서 저장소 루트 기준:

```powershell
# 1회 실행
pwsh ./.claude/orchestrator/Orchestrator.ps1 -Once

# 상시 실행 (watch)
pwsh ./.claude/orchestrator/Orchestrator.ps1
```

Windows PowerShell 5.1 사용 시:

```powershell
powershell -ExecutionPolicy Bypass -File .\.claude\orchestrator\Orchestrator.ps1
```

## 설정

`config.json`:

- `teamRoot`: Claude 팀 런타임 경로 (`${HOME}/.claude/teams/arrow-game`)
- `todoFile`: TODO 경로
- `runtime.requireIdleAgent`: `true`면 idle 알림 받은 에이전트에게만 배정
- `runtime.autoInjectTaskId`: `true`면 `task_id` 누락 보고에서 보수적 자동 주입 시도
- `git.autoCommitOnHandoff`: 핸드오프 시 커밋 시도
- `git.autoCheckoutTaskBranch`: `true`면 task branch로 checkout 시도

## 에이전트 응답 규약 (중요)

오케스트레이터는 `team-lead` inbox의 JSON 메시지를 읽어 상태를 전이합니다.
최종 보고 포맷은 `TASK_UPDATE` 공통 계약 문서를 단일 기준으로 사용합니다.

- 계약 문서: `.claude/orchestrator/TASK_UPDATE_CONTRACT.md`
- 엄격 검증: 필수 필드, stage/outcome 조합, 현재 상태 전이 유효성
- 오류 처리: 에이전트 inbox로 오류 코드/재제출 형식 자동 회신

동작 방식:
- 1회 형식 오류: soft fail (재제출 요청)
- 연속 오류(기본 2회째): hard fail (해당 메시지 거부 + 재보고 필요)
- `task_id` 누락 시: 자동 주입 시도 (보수적 단일 후보일 때만)
- 메시지 처리 예외(`processing_error`): soft/hard 누적 정책 동일 적용
  - soft: 에이전트는 idle 유지, 재전송 요청
  - hard: 에이전트 non-idle 처리, 정상 `task_update` 재보고 전까지 자동 진행 제한

자동 주입 조건(안전 모드):
- 보고자(agent)가 현재 담당(`currentOwner`)인 작업만 후보
- 보고 stage와 task 상태가 일치하는 작업만 후보
- 후보가 정확히 1개일 때만 주입
- 후보가 0개/2개 이상이면 주입하지 않고 기존 검증 실패 처리

### stage / outcome 예시

- Planner 완료: `stage=PLANNING`, `outcome=done`
- PM 승인/반려: `stage=PM_REVIEW`, `outcome=approved|rejected`
- 개발 완료: `stage=IN_DEV`, `outcome=done|blocked`
- 리뷰 승인/반려: `stage=CODE_REVIEW`, `outcome=approved|rejected`
- 최종 승인: `stage=MERGE_READY`, `outcome=approved`

## 제약

- PR API를 직접 호출하지 않습니다. `MERGE_READY` 단계에서 PM에게 수동 최종 승인 요청을 자동 전달합니다.
- 자연어 메시지는 참고만 하고, 자동 전이는 JSON `task_update`가 있어야 정확히 동작합니다.
- 핸드오프 커밋은 현재 브랜치가 task branch와 다르면(설정상 checkout 비활성) 건너뜁니다.

## 권장 운영

- 오케스트레이터는 별도 터미널에서 상시 실행
- PM/Reviewer 프롬프트에 "작업 결과는 반드시 task_update JSON으로 보고" 규칙 추가
- 필요 시 CI에서 `-Once`를 주기적으로 실행해 백업 안전망 구성

## 자동 실행 템플릿

개발자 개입을 최소화하려면 아래 표준 템플릿을 사용해 프로그래머에게 작업 지시를 전달합니다.

- 템플릿 문서: `.claude/orchestrator/AUTONOMOUS_WORK_TEMPLATES.md`
- 포함 내용: UI 작업, GameObject/Component 구성, 입력 연동, 실패 시 표준 처리

## 완전 자동 실행 런북

- 런북: `.claude/orchestrator/FULL_AUTONOMOUS_RUNBOOK.md`
- MCP 실동작 점검 스크립트: `.claude/orchestrator/scripts/Test-McpUnityConnection.ps1`
