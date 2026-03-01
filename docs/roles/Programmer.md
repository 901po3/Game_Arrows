# 프로그래머 (Programmer)

코드 데이터화·컨벤션·게임 구조·핵심 기능을 담당한다. 기능 구현 시에도 Plan을 작성하고 Plan 리뷰어 검토를 받은 뒤 구현한다. **기획 명세는 기획자(Planner) 산출물을 참고**하고, [GamePlan.md](../plan/GamePlan.md) 및 Plan에 따라 구현한다.

---

## 1. 필수 준수 사항

- [Workflow.md](../Workflow.md) 공통 규칙 준수: 브랜치 → Plan 작성 → Plan 리뷰어 검토 → 작업 → 문서·TODO 기록 → 코드 리뷰.
- [code/Conventions.md](../code/Conventions.md) 및 [plan/GamePlan.md](../plan/GamePlan.md)(핵심 기능·콘텐츠)를 참고하여 구현한다. 작업 시작 전 [changelog/](../changelog/)·[plan/CurrentStructure.md](../plan/CurrentStructure.md)에서 이전 작업·현재 구조를 확인한다. **리소스**는 [resources/Resources.md](../resources/Resources.md)의 배치·네이밍 규칙과 기획 명세의 필요 리소스 목록·경로를 보고 참조·연동한다.

---

## 2. 담당 업무

### 2.1 코드 데이터화

- 게임 데이터(스테이지, 아이템, 상품, 밸런스 수치 등)는 가능한 한 코드 밖(ScriptableObject, JSON, 테이블 등)으로 두어 기획 변경 시 코드 수정을 최소화한다.
- 데이터 구조·경로·로딩 방식은 Conventions 또는 GamePlan에 정의된 방식을 따른다.

### 2.2 코드 컨벤션

- [docs/code/Conventions.md](../code/Conventions.md)를 숙지하고 모든 코드에 적용한다.
- 네이밍, 폴더 구조, 스크립트 배치, public/private 구분 등을 일관되게 유지한다.

### 2.3 게임 구조 정의

- 씬 구조, 매니저·서비스 분리, 이벤트·데이터 흐름을 GamePlan·기획 명세와 맞게 유지한다.
- 새 시스템 추가 시 기존 구조와의 관계를 Plan에 명시하고, 리뷰어가 이해할 수 있도록 문서화한다. **구조가 바뀌면** [plan/CurrentStructure.md](../plan/CurrentStructure.md)를 갱신한다.

### 2.4 게임 핵심 기능 (기획 명세 기반)

- **게임 콘텐츠**
  - **아이템**: 획득·사용·저장·표시 로직을 기획 명세에 맞게 구현.
  - **스테이지**: 클리어 조건·보상·진행 로직을 데이터 기반으로 구현.
  - **기본 기능**: 입력, UI, 씬 전환, 저장/로드 등 공통 기능.
  - **상품**: 스토어·구매 플로우·연동(광고/결제 등)을 명세에 따라 구현.
  - **광고**: 연동 방식·보상 타임링을 기획과 맞춘다.

---

## 3. 작업 후 필수

- 변경한 파일·모듈과 이유를 **[docs/changelog/](../changelog/)**에 브랜치·날짜별로 기록하거나 PR description에 적는다. ([changelog/README.md](../changelog/README.md) 참고)
- [TODO.md](../TODO.md)에 리팩터링·개선·알려진 이슈를 추가한다.
- 코드 리뷰 통과 후에만 main에 머지한다.
