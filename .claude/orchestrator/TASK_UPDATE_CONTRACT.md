# TASK_UPDATE Contract

오케스트레이터 자동 상태 전이를 위해 모든 에이전트는 최종 보고 시 아래 계약을 준수합니다.

## Wrapper (required)

```text
TASK_UPDATE_BEGIN
{...json...}
TASK_UPDATE_END
```

- 블록은 메시지 마지막에 둡니다.
- 블록 내부에는 JSON 객체 1개만 둡니다.

## JSON schema (required)

```json
{
  "type": "task_update",
  "task_id": "<task_id>",
  "stage": "PLANNING|PM_REVIEW|IN_DEV|CODE_REVIEW|MERGE_READY",
  "outcome": "approved|rejected|done|blocked",
  "summary": "one-line summary",
  "notes": "optional"
}
```

필수 필드: `type`, `task_id`, `stage`, `outcome`, `summary`

## Stage / outcome rules

- `PLANNING`: `done|blocked`
- `PM_REVIEW`: `approved|rejected`
- `IN_DEV`: `done|blocked`
- `CODE_REVIEW`: `approved|rejected`
- `MERGE_READY`: `approved|done`

## Validation behavior

- 필수 필드 누락, stage/outcome 불일치, 현재 상태와 맞지 않는 전이는 거부됩니다.
- 거부 시 orchestrator가 에이전트 inbox로 오류 코드와 재제출 포맷을 회신합니다.
- 동일 task update가 연속 오류일 때 soft/hard 정책이 적용됩니다.

## Recommended examples

Planner done:

```text
TASK_UPDATE_BEGIN
{"type":"task_update","task_id":"P-101","stage":"PLANNING","outcome":"done","summary":"기획안 초안 완료"}
TASK_UPDATE_END
```

PM rejected:

```text
TASK_UPDATE_BEGIN
{"type":"task_update","task_id":"P-101","stage":"PM_REVIEW","outcome":"rejected","summary":"반려","notes":"중복 항목 제거 필요"}
TASK_UPDATE_END
```
