# AI 팀 문서 진입점

AI 에이전트가 작업할 때 **반드시 이 순서로** 문서를 참조한다.

1. **[Workflow.md](Workflow.md)** — 공통 규칙, 브랜치·Plan·리뷰·머지·QA·PM 흐름
2. **본인 역할** — [roles/README.md](roles/README.md)에서 역할 확인 후 해당 파일 읽기  
   - 기획: [roles/Planner.md](roles/Planner.md)  
   - 개발: [roles/Programmer.md](roles/Programmer.md)  
   - Plan 검토: [roles/PlanReviewer.md](roles/PlanReviewer.md)  
   - 코드 검증: [roles/CodeReviewer.md](roles/CodeReviewer.md)  
   - QA: [roles/QA.md](roles/QA.md)  
   - PM: [roles/PM.md](roles/PM.md)
3. **기획 참고** — [plan/GamePlan.md](plan/GamePlan.md) (게임 정체성, 콘텐츠, 밸런스)
4. **작업 시작 전** — [changelog/](changelog/)에서 자기 브랜치·일감의 **이전 작업 요약**과 [plan/CurrentStructure.md](plan/CurrentStructure.md)를 읽고, 기존 코드·구조와 맞는 방향으로 진행한다.
5. **머지 전** — [quality/PreMergeChecklist.md](quality/PreMergeChecklist.md) 확인
6. **용어·의사결정** — [Glossary.md](Glossary.md), [Decisions.md](Decisions.md) (필요 시)
7. **일감** — [TODO.md](TODO.md)에서 할 일 확인·등록
8. **리소스 필요 시** — [resources/Resources.md](resources/Resources.md) (구하는 방법·배치·기획/개발 인식)

---

## 문서 구조

| 경로 | 용도 |
|------|------|
| [Workflow.md](Workflow.md) | 워크플로우 전체 규칙 |
| [roles/](roles/) | 역할별 규칙·체크리스트 |
| [plan/](plan/) | 게임 기획·Plan, 현재 구조(CurrentStructure) |
| [changelog/](changelog/) | 작업 기록(브랜치·날짜별 요약) |
| [resources/](resources/) | 리소스 구하는 방법·배치·기획/개발 인식 |
| [code/](code/) | 코드 컨벤션 |
| [quality/](quality/) | 품질·머지 전 체크리스트 |
| [Glossary.md](Glossary.md) | 프로젝트 용어 정의 |
| [TODO.md](TODO.md) | 일감·개선·이슈 |
| [Decisions.md](Decisions.md) | 의사결정·예외 처리 |
