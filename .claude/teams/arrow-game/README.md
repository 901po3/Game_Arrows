# Arrow Game Agent Team

Unity 게임 **Arrow Puzzle(Arrows Game)** 제작을 위한 Agent Teams 정의입니다. 팀원(Planner, PM, Programmer, Plan Reviewer, Code Reviewer, QA)은 이 폴더의 역할별 스폰 프롬프트로 생성됩니다.

---

## 팀 에이전트 사용 조건

- **Agent Teams 활성화**: 이 프로젝트에서는 `.vscode/settings.json`의 `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`가 `"1"`로 이미 설정되어 있습니다. 다른 환경에서는 해당 환경 변수를 `1`로 설정해야 합니다.
- **팀 시작 방법**: Claude Code(또는 Agent Teams를 지원하는 클라이언트)에서 이 프로젝트를 연 뒤, 아래 **마스터 스폰 프롬프트**가 담긴 이 파일을 참조해 팀 생성을 요청합니다.  
  예: **"Create an agent team using the instructions in .claude/teams/arrow-game/README.md"**  
  리드가 이 README와 `teammates/*.md` 내용을 읽고 6명의 팀원을 스폰하면, 정의한 규칙대로 동작하는 팀이 만들어집니다.

---

## 마스터 스폰 프롬프트 (팀 생성 시 리드에게 전달할 내용)

아래 내용을 사용해 팀을 생성하세요.

---

이 프로젝트는 **Unity 게임 Arrow Puzzle(Arrows Game)** 입니다. 탭 이스케이프 스타일의 힐링 논리 퍼즐이며, 화살표를 순서대로 탭해 보드를 비우는 것이 핵심 루프입니다.

**6명의 팀원**을 생성합니다:

1. **Planner (기획자)** — 스폰 프롬프트: `.claude/teams/arrow-game/teammates/planner.md` 파일 내용 전체를 해당 팀원의 스폰 프롬프트로 사용하세요.
2. **PM** — 스폰 프롬프트: `.claude/teams/arrow-game/teammates/pm.md` 파일 내용 전체를 해당 팀원의 스폰 프롬프트로 사용하세요.
3. **Programmer (프로그래머)** — 스폰 프롬프트: `.claude/teams/arrow-game/teammates/programmer.md` 파일 내용 전체를 해당 팀원의 스폰 프롬프트로 사용하세요.
4. **Plan Reviewer (Plan 리뷰어)** — 스폰 프롬프트: `.claude/teams/arrow-game/teammates/plan-reviewer.md` 파일 내용 전체를 해당 팀원의 스폰 프롬프트로 사용하세요.
5. **Code Reviewer (코드 리뷰어)** — 스폰 프롬프트: `.claude/teams/arrow-game/teammates/code-reviewer.md` 파일 내용 전체를 해당 팀원의 스폰 프롬프트로 사용하세요.
6. **QA** — 스폰 프롬프트: `.claude/teams/arrow-game/teammates/qa.md` 파일 내용 전체를 해당 팀원의 스폰 프롬프트로 사용하세요.

**공통 규칙**: 모든 팀원은 작업 시 프로젝트 문서를 참고해야 합니다. 특히 `docs/roles/` 아래 역할별 md, `docs/plan/GamePlan.md`, `docs/plan/TechnicalSpec.md`, `docs/Workflow.md` 등을 필요에 따라 읽고 따릅니다.

---

## 디렉터리 구조

```
.claude/teams/arrow-game/
  README.md           (이 파일 — 팀 설명 + 마스터 스폰 프롬프트)
  teammates/
    planner.md
    pm.md
    programmer.md
    plan-reviewer.md
    code-reviewer.md
    qa.md
```

각 `teammates/*.md`는 해당 역할의 **스폰 프롬프트**입니다. 리드가 팀원을 스폰할 때 해당 파일 내용을 그대로 해당 팀원에게 전달합니다.
