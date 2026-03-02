# Next Steps (Autonomous Team Ops)

## 1) SMOKE-MCP-001 완료 확인
- [ ] `orchestrator: wait report (auto-escalate)` 태스크로 `SMOKE-MCP-001` 모니터링
- [ ] team-lead inbox에서 programmer의 `task_update` 도착 확인
- [ ] `stage/outcome`이 기대값(`IN_DEV`, `done`)인지 검증

## 2) Unity MCP 실동작 확정
- [ ] `.claude/orchestrator/scripts/Test-McpUnityConnection.ps1` 실행
- [ ] `::1:8090` 연결 성공 여부 확인
- [ ] IPv4 실패 시(127.0.0.1) IPv6 기반 운영 가이드 문서화

## 3) 무응답 대응 자동화 고도화
- [ ] `Wait-TaskUpdateReportWithEscalation.ps1`를 기본 모니터로 사용
- [ ] timeout/parse-error 발생 시 PM inbox 에스컬레이션 확인
- [ ] 에스컬레이션 후 재배정 규칙(담당자 변경/재시도 횟수) 확정

## 4) Agent Heartbeat 모니터 추가 (권장)
- [ ] 팀원별 `lastSeen/idle/lastEvent`를 주기 점검하는 스크립트 추가
- [ ] 일정 시간 무활동 에이전트 자동 경보(PM/team-lead) 추가
- [ ] VS Code task로 `heartbeat monitor` 등록

## 5) 운영 표준화 문서 마무리
- [ ] `.claude/orchestrator/FULL_AUTONOMOUS_RUNBOOK.md`에 장애 대응 플로우 보강
- [ ] 역할 프롬프트(Planner/PM/Programmer/Reviewer)에 DoD 기반 보고 규칙 재검토
- [ ] 릴리즈 노트에 자동운영 체크리스트 반영

## 6) 커밋/태그 후속
- [ ] 이번 변경 커밋(템플릿/런북/모니터 태스크) 생성
- [ ] 필요 시 패치 버전 태그(`v0.1.x`) 발행
- [ ] 원격 푸시 후 팀 공지
