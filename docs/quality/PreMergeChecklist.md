# Pre-Merge Checklist

main 브랜치에 머지하기 **전**에 아래 항목을 모두 충족해야 한다. AI·팀원이 self-check할 때 사용한다.

---

## 1. Plan

- [ ] Plan이 작성되었고, **Plan 리뷰어**의 승인을 받았다.

---

## 2. 작업 산출물

- [ ] 구현·기획 작업이 Plan 범위 내에서 완료되었다.
- [ ] **작업 요약**이 [docs/changelog/](../changelog/) 또는 PR description에 있다 (변경 파일·결정 사항·이유). ([changelog/README.md](../changelog/README.md) 참고)
- [ ] **TODO**에 남은 작업·개선·이슈가 반영되었다. ([docs/TODO.md](../TODO.md))
- [ ] 구조를 바꿨다면 [docs/plan/CurrentStructure.md](../plan/CurrentStructure.md)를 갱신했다.

---

## 3. 코드 리뷰

- [ ] **리뷰어(코드 검증)**의 검사를 받았고, **통과** 상태이다.
- [ ] 반려 사항이 있었다면 수정 후 문서를 업데이트하고 다시 통과했다.

---

## 4. 품질

- [ ] [docs/code/Conventions.md](../code/Conventions.md)를 준수했다.
- [ ] 기존 기능이 깨지지 않았음을 확인했다 (가능하면 로컬에서 한 번 실행·테스트).

---

## 5. 머지 후

- 머지 후 **QA**가 테스트를 수행하고, 이슈가 있으면 TODO에 등록한다. ([docs/roles/QA.md](../roles/QA.md))
- PM이 TODO 일감을 묶고 기획/개발에 배정한다. ([docs/roles/PM.md](../roles/PM.md))

---

*체크리스트를 통과한 뒤에만 main으로 머지한다.*
