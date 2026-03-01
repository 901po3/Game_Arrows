# Arrow Puzzle - GitHub Copilot Instructions

## 프로젝트 개요
- **엔진**: Unity 6000.3 (2D URP)
- **프로젝트 타입**: Arrow Puzzle 게임
- **렌더링**: Universal Render Pipeline (URP) 2D

## 코딩 규칙
- C# 스크립트는 Unity 네이밍 컨벤션 사용
- public 필드는 PascalCase, private 필드는 _camelCase 또는 camelCase
- MonoBehaviour 스크립트는 Assets/Scripts 폴더에 배치

## Unity 관련
- Input System 사용 (InputSystem_Actions.inputactions)
- 2D 프로젝트이므로 Physics2D, Sprite 관련 API 사용
- URP 설정은 Assets/Settings/ 에서 관리

## 참고사항
- .meta 파일은 Unity가 자동 생성하므로 수정하지 않음
- Scene 파일(.unity)은 YAML 형식
