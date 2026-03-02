# Autonomous Work Templates

개발자 개입을 최소화하기 위해, 프로그래머 팀원이 Unity MCP와 오케스트레이터를 이용해 작업을 끝까지 수행할 때 사용하는 표준 템플릿입니다.

## 공통 전제

- Unity Editor가 실행 중이고 프로젝트가 열려 있어야 한다.
- Unity MCP 서버가 연결되어 있어야 한다.
- 최종 보고는 `TASK_UPDATE` 계약을 따른다: `.claude/orchestrator/TASK_UPDATE_CONTRACT.md`

## 표준 실행 프롬프트 (복사용)

아래 템플릿에서 변수만 바꿔 프로그래머 팀원에게 전달한다.

```text
[WORK ORDER]
Task ID: <TASK_ID>
Goal: <한 줄 목표>
Target Scene: <SCENE_PATH_OR_NAME>
Definition of Done:
1) <완료조건1>
2) <완료조건2>
3) <완료조건3>

[EXECUTION RULES]
- Unity MCP로 씬/오브젝트/컴포넌트 작업을 먼저 수행한다.
- C# 코드 변경이 필요하면 최소 범위로 수정한다.
- 변경 후 가능한 테스트(PlayMode/EditMode/메뉴 실행)를 수행한다.
- 실패 시 원인/재시도 내용을 notes에 남긴다.

[REPORT]
메시지 마지막에 반드시 아래 블록을 추가한다.
TASK_UPDATE_BEGIN
{"type":"task_update","task_id":"<TASK_ID>","stage":"IN_DEV","outcome":"done|blocked","summary":"<one-line>","notes":"<optional>"}
TASK_UPDATE_END
```

## 템플릿 A: UI 패널 추가

```text
Task ID: <TASK_ID>
Goal: Add settings panel UI
Target Scene: Assets/Scenes/Main.unity
Definition of Done:
1) Canvas 하위에 SettingsPanel(GameObject) 생성
2) Panel 배경(Image), 제목(Text/TMP), 닫기(Button) 구성
3) 닫기 버튼 클릭 시 패널 비활성화 동작 연결
4) 기본 레이아웃이 깨지지 않고 Play Mode에서 동작 확인
```

## 템플릿 B: 게임오브젝트 + 컴포넌트 구성

```text
Task ID: <TASK_ID>
Goal: Add player root and movement component
Target Scene: Assets/Scenes/Game.unity
Definition of Done:
1) PlayerRoot GameObject 생성
2) Rigidbody2D, Collider2D, PlayerController 컴포넌트 추가
3) 필수 직렬화 필드 연결
4) NullReference 없이 플레이 가능
```

## 템플릿 C: 입력/연동 작업

```text
Task ID: <TASK_ID>
Goal: Wire jump input action to PlayerController
Target Scene: Assets/Scenes/Game.unity
Definition of Done:
1) InputAction 참조 연결
2) 점프 입력 처리 메서드 연결
3) Play Mode에서 입력 동작 확인
4) 실패 시 로그/원인 기록
```

## 실패 시 표준 처리

- MCP 미연결/권한 문제: `outcome=blocked`, notes에 "mcp_unavailable" 명시
- 컴파일 오류: 오류 메시지 요약 + 수정 시도 1회 후 재보고
- 씬 충돌/병합 이슈: 변경 범위 최소화 후 PM에 escalation

## 운영 팁

- PM은 Definition of Done을 구체적으로 써서 재작업 루프를 줄인다.
- Programmer는 큰 작업을 1~2시간 단위 하위 Task ID로 분할해 보고한다.
- Reviewer는 결과 검증 시 DoD 체크리스트 기준으로 승인/반려한다.
