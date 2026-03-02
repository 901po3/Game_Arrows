# 코드 컨벤션

프로그래머는 이 규칙을 따르고, 리뷰어는 이 규칙을 기준으로 코드를 검토한다.  
Unity 공식 C# 스타일 가이드·Microsoft 네이밍 규칙·캐주얼 게임 아키텍처 모범 사례를 반영했다.  
프로젝트 루트의 [.github/copilot-instructions.md](../../.github/copilot-instructions.md)와 충돌 시 이 문서를 우선하되, 필요하면 두 문서를 맞춘다.

---

## 0. 프로젝트 환경 (통합 참고)

- **스크립트 기본 위치**: MonoBehaviour·C# 스크립트는 `Assets/Scripts/` 아래에 배치. (폴더 구조는 4.1 참고)
- **엔진·프로젝트 타입** 등 상세는 [GamePlan.md](../plan/GamePlan.md)·[.github/copilot-instructions.md](../../.github/copilot-instructions.md) 참고.

---

## 1. 코드 스타일 (Code Style)

### 1.1 네이밍 (Naming)

- **클래스·인터페이스·구조체·enum 타입**: `PascalCase`
- **public 필드·프로퍼티·메서드·이벤트**: `PascalCase`
- **private / protected 필드**: `_camelCase` (언더스코어 + camelCase. Microsoft/Unity 권장으로 private 구분 명확화)
- **로컬 변수·매개변수**: `camelCase`
- **상수 (const / static readonly)**: `PascalCase` 또는 `UPPER_SNAKE` (팀 내 하나로 통일)
- **namespace**: `PascalCase`, 하이픈/언더스코어 사용하지 않음
- **identifier**: 특수문자·백슬래시·유니코드 사용 금지 (Unity 커맨드라인·도구 호환)

### 1.2 서식 (Formatting)

- **들여쓰기**: 스페이스 4칸 (탭 사용 시 팀에서 1탭 = 4스페이스로 통일)
- **중괄호**: K&R 스타일 — 제어문/메서드 같은 줄 `{`, 블록 다음 줄
- **한 줄 길이**: 120자 이내 권장. 초과 시 줄 나누기 (가독성 우선)
- **빈 줄**: 논리적 블록 사이에 한 줄. 과도한 빈 줄 자제

### 1.3 주석·문서

- public API에는 XML 주석(`///`)으로 요약·매개변수·반환값 명시 권장
- 복잡한 알고리즘·비즈니스 예외는 이유를 주석으로 남긴다
- `#region`은 필요한 경우에만 사용하고, 남용하지 않는다

---

## 2. 코드 구조 (Code Structure)

### 2.1 단일 책임·파일 크기

- 한 클래스는 하나의 책임. 한 파일에는 하나의 public 타입(클래스/인터페이스)을 두는 것을 원칙으로 한다.
- 파일이 300~400줄을 넘어가면 역할을 나누거나 partial·하위 타입 분리 검토.

### 2.2 네임스페이스

- 프로젝트 루트 네임스페이스는 팀 정책에 맞게 (예: `ArrowPuzzle`, `Company.GameName`).
- 하위는 기능·시스템별로 (예: `ArrowPuzzle.Items`, `ArrowPuzzle.Stage`).
- Unity 에디터 전용 코드는 `.Editor` 네임스페이스 또는 `Editor/` 폴더로 구분.

### 2.3 접근성

- public은 꼭 필요한 API만 노출. 나머지는 `internal` 또는 `private`.
- `[SerializeField]` private 필드는 인스페이터 노출용; 나머지 private은 `_camelCase`로 구분.

---

## 3. 아키텍처 구조 (Architecture)

캐주얼 게임에서 널리 쓰이는 **모듈화·이벤트 기반·데이터 주도** 구조를 따른다.

### 3.1 원칙

- **관심사 분리**: 게임 로직 / UI / 리소스(로딩)·저장은 역할별로 분리한다.
- **느슨한 결합**: 모듈 간 직접 참조를 줄이고, 이벤트·인터페이스·메시징으로 소통한다.
- **캡슐화**: 모듈은 명확한 인터페이스만 노출하고, 내부 구현은 숨긴다.

### 3.2 권장 패턴

- **이벤트 버스 / 메시징**: 시스템 간 통신은 중앙 이벤트 버스(또는 정적 이벤트)로 한다.  
  예: 플레이어 피격 → 이벤트 1회 발행 → UI·사운드·카메라가 각자 구독. 직접 참조 최소화.  
  **이벤트·메시지 이름**: PascalCase, 동작·과거 상황을 드러내게 (예: `PlayerDamaged`, `StageCleared`). 팀 내 하나의 규칙으로 통일.
- **Model–View–Presenter (MVP)**: UI와 비즈니스 로직 분리. Model은 UnityEngine에 의존하지 않는 순수 C#으로 두고, View는 **UI Toolkit**(VisualElement, UIDocument)으로 구현한다. Unity UI만 담당하며, 상세 규칙은 §4.4를 따른다.
- **유한 상태 기계 (FSM)**: 게임 전체 상태·캐릭터/플로우 상태는 FSM으로 관리해 전이를 명확히 한다.
- **데이터와 로직 분리**: 게임 데이터(스테이지·아이템·밸런스)는 ScriptableObject 등으로 두고, 코드는 “데이터를 읽어 동작”하도록 한다.

### 3.3 피할 것 (캐주얼 게임 관점)

- **거대한 GameManager 한 곳에 모든 로직**: 기능별 매니저/시스템으로 나눈다.
- **레벨 내용을 코드에 하드코딩**: 레벨 데이터는 에셋·Addressables 등으로 분리해 기획/디자이너가 수정 가능하게.
- **Live Ops 무시**: 주기적인 콘텐츠 업데이트를 고려한 데이터·번들 구조를 설계한다.

---

## 4. 유니티 프로젝트·폴더 구조 (Unity Management)

### 4.1 폴더 구조 (Feature-Based 권장)

타입별(Scripts, Prefabs, Art)만 나누면 규모가 커질 때 관련 파일이 흩어진다. **기능(Feature) 단위**로 묶는 구성을 권장한다.

```
Assets/
├── _Project/           # 공통·공유 에셋 (공통 UI, 공용 스크립트 등)
├── Features/           # 기능별
│   ├── Player/
│   │   ├── Scripts/
│   │   ├── Prefabs/
│   │   └── Art/
│   ├── Stage/
│   ├── Items/
│   ├── Shop/
│   └── UI/
├── Scenes/
├── Settings/           # URP, Input, Quality 등
├── Plugins/            # 서드파티
└── Sandbox/            # 실험·테스트용 (필요 시)
```

- **Scripts 경로 일원화**: 프로젝트 기본은 **`Assets/Scripts/`** 아래 기능별 하위 폴더 (예: `Scripts/Items/`, `Scripts/Stage/`). **Features 기반**을 쓰면 `Assets/Features/<기능>/Scripts/`에 둔다. 한 프로젝트 안에서는 둘 중 하나로 통일한다.
- 구조는 **초기에 정하고 일관되게 유지**한다. 중간에 대규모 재구성은 지양.

### 4.2 에디터 설정 (버전 관리·머지 대비)

- **Edit > Project Settings > Editor**
  - **Asset Serialization**: `Force Text` (YAML로 직렬화 → Git 머지·diff 가능)
  - **Version Control**: `Visible Meta Files` (GUID 추적)
  - **Line Endings**: 팀 정책에 맞게 (예: OS Native 또는 LF 통일)

### 4.3 프로젝트별 규칙

- **Input**: Input System 사용 (InputSystem_Actions.inputactions).
- **2D**: Physics2D, Sprite 관련 API 사용. URP 2D 설정은 Assets/Settings/ 에서 관리.
- **.meta**: Unity가 자동 생성. 수동 수정 금지. Scene(.unity)·에셋은 YAML 형식 유지.
- **UI**: UI Toolkit 사용. UIDocument, Panel Settings, UXML/USS. 상세는 §4.4 참고.

### 4.4 UI 구현: UI Toolkit

- **UI 스택**: 게임 UI는 **UI Toolkit**을 사용한다. UGUI(Canvas)는 레거시 또는 특수 목적이 있을 때만 사용.
- **패키지·모듈**: `com.unity.modules.uielements`(이미 포함) 기반으로 런타임 UI를 구현한다. UIDocument, Panel Settings, UXML/USS 사용. 필요 시 Package Manager에서 "Unity UI"(UI Toolkit) 패키지 추가.
- **에셋 위치**:
  - UXML, USS, Panel Settings 에셋은 `Assets/_Project/UI/` 또는 `Assets/Features/UI/`에 둔다. (§4.1 폴더 구조와 일치하도록 팀에서 하나로 통일.)
  - 공통 스타일·테마는 `_Project/UI/`에, 화면별 레이아웃은 `Features/UI/` 또는 기능별 하위에 둘 수 있다.
- **세팅**:
  - **Panel Settings**: 런타임 UI용 Panel Settings 에셋을 최소 1개 생성해 프로젝트에서 공통으로 사용한다. (예: `Assets/_Project/UI/DefaultPanelSettings.asset`.) 스케일 모드·참조 해상도는 타깃(모바일/PC)에 맞게 설정.
  - **UIDocument**: 씬 또는 프리팹에 `UIDocument` 컴포넌트를 부착하고, Panel Settings와 Source Asset(UXML)을 할당한다. 한 씬에 여러 UIDocument를 두는 경우 정렬 순서(Sort Order)로 전후 관계를 제어한다.
  - **소트 오더**: 오버레이가 겹칠 때는 UIDocument의 Sort Order로 어떤 패널이 앞에 올지 결정한다.
- **네이밍**: UXML/USS 파일명은 화면·패널 단위로 구분 (예: `GameHUD.uxml`, `MainMenu.uxml`, `GameHUD.uss`). 팀 내 규칙으로 통일.

---

## 5. 소스 관리 (Version Control)

- **커밋/제외**: `Assets/`, `ProjectSettings/`, `Packages/`(manifest·lock), `*.cs`, `*.unity`, `*.meta`는 커밋. `Library/`, `Temp/`, `Logs/`, `UserSettings/`, `Build/`, `Builds/`, IDE 전용 파일 등은 .gitignore로 제외. .gitignore는 프로젝트 루트에 둔다.
- **Unity YAML 머지**: `.unity`, `.asset` 등은 Unity **Smart Merge (UnityYAMLMerge)** 사용 권장. `.gitattributes`에 merge 도구 지정 시 참조 깨짐을 줄일 수 있다. 상세 셋업은 프로젝트 버전 관리 가이드 참고.

---

## 6. 데이터 관리 (Data Management)

### 6.1 ScriptableObject 중심

- **공유·정적 데이터**: 스테이지 정의, 아이템 스탯, 밸런스 수치, 설정값 등은 ScriptableObject로 보관.
- **장점**: 메모리 1부만 사용, 에디터에서 기획자가 수치 수정 가능, 코드와 데이터 분리.

### 6.2 데이터 주도 설계

- “어떤 동작을 할지”는 **데이터(에셋)**로 제어하고, 코드는 “데이터를 읽어 실행”하는 쪽으로 작성.
- 새 데이터 타입 추가 시 `[CreateAssetMenu]`로 에셋 생성 경로를 고정하고, 로딩·검증 방식은 프로젝트 내 일관되게 유지.
- **ScriptableObject·에셋 네이밍**: `menuName`은 기능별로 구분 (예: `"ArrowPuzzle/Items/ItemData"`, `"ArrowPuzzle/Stage/StageData"`). 에셋 파일명은 타입+식별자 (예: `ItemData_Sword.asset`). 팀 내 규칙으로 통일.

### 6.3 사용처 예

- 적/아이템 스탯, 게임 설정, 스테이지/웨이브 정의, 스폰 정보, 보상 테이블 등.
- 런타임에 바꿀 필요 없는 데이터는 ScriptableObject; 세이브/유저별 데이터는 별도 저장 구조(JSON·바이너리 등).

---

## 7. 최적화 규율 (Optimization)

### 7.1 원칙

- 최적화는 **마지막이 아니라 설계 단계부터** 고려한다. 특히 모바일·캐주얼은 저사양 기기 타깃을 전제로 한다.
- “일단 동작하게” 만든 뒤, **프로파일링으로 병목을 확인한 구간만** 최적화한다. 과도한 최적화는 지양.

### 7.2 프로파일링

- **타깃 기기**에서 Unity Profiler로 측정. 에디터만 보지 않는다.
- **저사양·고사양** 둘 다 테스트해 목표 프레임·메모리를 만족하는지 확인. 플랫폼별 네이티브 프로파일러는 필요 시 사용.

### 7.3 코드·아키텍처

- **Update()**: 매 프레임 불필요한 연산·GetComponent·Find 계열 호출 금지. 캐시·이벤트 기반으로 전환.
- **오브젝트 생성/파괴 빈도**: 풀링(Object Pool)으로 재사용.
- **메모리**: 큰 할당·GC 유발을 줄이기 위해 임시 컬렉션·문자열 결합 최소화. 재사용 가능한 버퍼·리스트 활용.

### 7.4 에셋·그래픽

- 텍스처·오디오 압축·해상도는 타깃 플랫폼에 맞게 설정.
- Draw Call·배칭, 불필요한 post-processing·해상도는 모바일 기준으로 조정.

### 7.5 문서화

- 성능에 민감한 시스템(풀링, LOD, 로딩 정책)은 코드 또는 [GamePlan.md](../plan/GamePlan.md)·별도 문서에 “왜 이렇게 했는지” 짧게 남긴다.

---

## 8. Unity 스크립트·로깅·테스트

### 8.1 MonoBehaviour·라이프사이클

- **호출 순서**: Awake → OnEnable → (프레임) → Start → FixedUpdate/Update/LateUpdate → OnDisable → OnDestroy. 의존성이 있으면 이 순서를 전제로 참조한다.
- **Unity 오브젝트 null 체크**: `if (obj == null)` 사용. Unity는 destroyed 오브젝트에 대해 연산자 오버로드로 null처럼 동작하므로, 가능하면 `obj`가 UnityEngine.Object일 때는 `== null`로 검사한다.
- **Coroutine vs 비동기**: 단순 대기·딜레이·순차 실행은 코루틴. 취소·조합·예외 처리가 복잡하면 async/UniTask 등 검토. 코루틴 메서드는 동작을 드러내는 이름 (예: `RunSequenceAsync`, `DelayedExecute`). 무한 루프 코루틴은 `OnDisable`/`OnDestroy`에서 StopCoroutine으로 정리한다.

### 8.2 에러 처리·로깅

- **예외**: 복구 불가능한 오류에만 예외 사용. 흐름 제어용으로 쓰지 않는다. catch 시 로그 남기고 재throw 또는 상위에 보고.
- **Debug.Log**: 개발 중 디버그용. 빌드에는 조건부 컴파일(`#if UNITY_EDITOR` / `DEBUG`) 또는 로그 레벨로 제한하는 방식을 권장. 콘솔 스팸 자제.
- **Assert**: 가정이 깨졌을 때만 사용. `UnityEngine.Assertions.Assert` 또는 `Debug.Assert`. 릴리즈 빌드에서 제거되는지 확인.

### 8.3 상수·매직 넘버

- **매직 넘버·문자열**: 반복되는 수치·문자열은 const/static readonly 또는 ScriptableObject 등으로 정의해 한 곳에서 관리.
- **태그·레이어·씬 이름**: 문자열 하드코딩 대신 상수·정적 클래스 또는 Name/Id 테이블 사용 권장.

### 8.4 테스트

- **위치**: Unity Test Framework 사용 시 테스트 어셈블리는 `Tests/` 또는 `Assets/Tests/` 등 프로젝트 정책에 맞게. 에디터 테스트는 `Editor` 폴더/어셈블리로 분리 가능.
- **네이밍**: 테스트 메서드/클래스는 동작을 드러내게 (예: `MethodName_Condition_ExpectedResult` 또는 `WhenX_ShouldY`).
- **테스트 가능성**: 비즈니스 로직은 UnityEngine에 의존을 줄이면 단위 테스트 작성이 쉬움. (아키텍처 3.2 데이터·로직 분리와 연동)

### 8.5 에디터 전용 스크립트

- **위치**: `Editor/` 폴더 또는 `*Editor.cs` 등. `UnityEditor` 네임스페이스·어셈블리는 런타임 빌드에 포함되지 않도록 경로 규칙 유지.
- **Custom Inspector**: 클래스명은 `[원본클래스명]Editor`. 메뉴 확장은 `MenuItem` 경로를 프로젝트 규칙에 맞게 통일.
- **Deprecated API**: 제거 예정 API는 `[Obsolete("대체 방법 명시")]`로 표시하고, 마이그레이션 후 제거한다.

---

## 9. 기타

- 새 시스템 추가 시 [GamePlan.md](../plan/GamePlan.md) 및 기존 아키텍처와 충돌하지 않도록 Plan에 명시한 뒤 구현한다.
- **보안**: API 키·시크릿·프로덕션 토큰은 코드·버전 저장소에 넣지 않는다. 환경 변수·로컬 설정·시크릿 매니저 등 빌드/배포 시 주입하는 방식을 사용한다.
- **Nullable 참조 타입 (C#)**: 프로젝트에서 채택 시 `string?`, `GameObject?` 등으로 의도를 명시. 채택 여부는 팀 정책에 따르고, 일단 적용하면 주석·리뷰에 반영한다.
- 리뷰어는 이 문서의 코드 스타일·구조·아키텍처·데이터·최적화·Unity·로깅·테스트 규율을 기준으로 검토한다.

---

## 10. 문서·워크플로우와의 관계

컨벤션을 적용하는 쪽(프로그래머·리뷰어)이 다른 docs와 맞춰 행동할 수 있도록, 알고 있어야 할 내용을 정리한다.

### 10.1 워크플로우

- **코드 작업은 Plan 작성 → Plan 리뷰어 승인 후** 진행한다. ([Workflow.md](../Workflow.md))
- 작업 후 **작업 요약**을 [changelog/](../changelog/) 또는 PR에 남기고, **[TODO.md](../TODO.md) 갱신**은 필수이다. **폴더·모듈 구조를 바꿨다면** [plan/CurrentStructure.md](../plan/CurrentStructure.md)를 갱신한다.
- **코드 리뷰 통과 후에만** main에 머지한다. 머지 전 [PreMergeChecklist.md](../quality/PreMergeChecklist.md)를 확인한다.
- **리소스**(이미지·사운드 등)는 [resources/Resources.md](../resources/Resources.md)의 배치·네이밍을 따른다.
- 리뷰 반려 시 수정 후 문서(TODO·변경 요약)를 업데이트한 뒤 재요청한다. ([Decisions.md](../Decisions.md))

### 10.2 기획·용어와의 일치

- 구현 시 **[GamePlan.md](../plan/GamePlan.md)** 및 기획 명세를 따른다. 콘텐츠(아이템, 스테이지, 기본 기능, 상품, 광고)는 GamePlan 정의와 맞춘다.
- **용어**는 [Glossary.md](../Glossary.md)와 일치하게 쓴다. 스테이지·아이템·상품·밸런스·게임 정체성 등 — 주석·변수명·로그·문서에서 동일한 의미로 사용한다.

### 10.3 문서 충돌 시

- 다른 문서와 코드 규칙이 충돌하면 **docs/ 내 문서가 우선**한다. 코드 규칙의 **단일 출처는 본 Conventions**이다. ([Decisions.md](../Decisions.md))

### 10.4 관련 문서

- 상세 문서 구조·진입점은 [docs/README.md](../README.md) 참고.
