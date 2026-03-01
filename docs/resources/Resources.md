# 리소스 (에셋) 가이드

게임에 쓰는 **리소스**(이미지, 사운드, 애니메이션, 폰트 등)를 어떻게 구하고, 어디에 두며, 기획자·프로그래머가 어떻게 인식·사용하는지 정리한다.

---

## 1. 정의

- **리소스**: 게임에 사용하는 **미디어·데이터 에셋** — 스프라이트, UI 아트, 사운드, 애니메이션 클립, 폰트, 비디오 등. (코드·ScriptableObject 데이터는 [Conventions](../code/Conventions.md)에서 다룸.)
- **에셋**: Unity 프로젝트 내 에셋(스크립트·이미지·사운드·프리팹 등). 리소스는 그중 "게임에 쓰는 미디어"를 넓게 이르는 말.

---

## 2. 리소스를 구하는 방법

- **구하는 주체**: 사람(또는 PM/기획자가 요청)이 리소스를 구해서 프로젝트에 넣는다. 출처(에셋 스토어, 외부 제작, 내부 제작)는 팀 정책에 따른다.
- **배정**: 리소스가 필요한 기능은 기획·Plan에 "필요 리소스 목록"으로 적고, 리소스가 준비되면 아래 배치 규칙에 따라 지정된 경로에 넣는다.

---

## 3. 배치 규칙

- [docs/code/Conventions.md](../code/Conventions.md) §4.1 폴더 구조와 맞춘다.
  - 공통·공유: `Assets/_Project/` (또는 `Assets/Shared/`)
  - 기능별: `Assets/Features/<기능>/Art/`, `.../Audio/` 등. 또는 `Assets/Scripts/`를 쓰는 경우 `Assets/Art/`, `Assets/Audio/` 등 타입별 하위 폴더.
  - **플레이스홀더**: 리소스 미준비 시 사용할 기본 에셋은 `Assets/_Project/Placeholders/` (또는 팀 정책 경로)에 둔다. 예: `Sprite_Default.png`, `Audio_Default.wav`.
- **파일·폴더 네이밍**: 기능_용도_식별자 (예: `Items_Icon_Sword.png`, `Stage_BGM_01.wav`). 팀 내 규칙으로 통일한다. (선택) 에셋 타입 접두어: 스프라이트 `sp_` 또는 `tex_`, 사운드 `snd_`, UI `ui_` — 팀 정책으로 통일.

---

## 4. 런타임 로딩 방식

- **기본**: 2D 캐주얼·콘텐츠 규모가 작으면 **씬/프리팹에서 직접 참조**를 우선 권장. 코드에서 경로로 불러올 필요가 적으면 유지보수·빌드가 단순하다.
- **경로로 로드가 필요한 경우**: 소량이면 Unity **Resources 폴더**를 쓸 수 있다. `Assets/Resources/` 하위에만 두고, **필요한 에셋만** 넣는다. 에셋 수가 많아지거나 패치·원격 배포가 필요해지면 **Addressables** 전환을 검토한다.
- **Resources 폴더 주의**: 빌드 시 Resources 하위가 한 덩어리로 묶여 시작·빌드가 느려질 수 있다. 대량·Live Ops 필요 시 [Addressables](https://docs.unity3d.com/Packages/com.unity.addressables@1.28/manual/index.html) 도입 검토.
- **Resources.Load 사용 시**: `Resources.Load("하위경로/이름")` 에서 쓰는 경로는 **Resources 아래 상대경로만** (확장자 제외). 예: `Resources/Items/Icons/Items_Icon_Sword` → `Resources.Load("Items/Icons/Items_Icon_Sword")`.

---

## 5. 배치 경로 vs 로드 경로 (AI·코드 생성 시)

- **배치 경로**: 에셋 파일이 있는 프로젝트 경로. 예: `Assets/Features/Items/Art/Items_Icon_Sword.png`. 기획 명세·본 문서 "배치 규칙"에서 이 경로를 쓴다.
- **로드 경로**: 씬/프리팹 참조는 에디터에서 할당. `Resources.Load`를 쓸 경우 **Resources 하위 상대경로만** 사용한다. 배치 경로와 다르므로 혼동하지 않는다.
- **코드 생성 시**: 에셋 경로는 **기획 명세의 경로** 또는 **본 문서 배치 규칙**을 따른다. `Resources.Load`를 쓸 경우 Resources 하위 상대경로만 사용하고, 확장자는 넣지 않는다.

---

## 6. 기획자가 할 일

- 기능 명세·기획서에 **필요 리소스 목록**(이름·용도·배치 경로 또는 예상 경로)을 적는다.
- 이미 프로젝트에 있는 리소스는 **경로를 명시**해 프로그래머가 참조하게 한다. 예: "사용할 리소스: `Assets/Features/Items/Art/Items_Icon_Sword.png`"
- 리소스가 아직 없으면 "미준비 시 플레이스홀더 사용" 및 플레이스홀더 경로(§3)를 명세에 남긴다.

---

## 7. 프로그래머가 할 일

- [Resources.md](Resources.md)(본 문서)의 **배치·네이밍 규칙**을 따른다.
- 기획 명세의 **필요 리소스 목록·경로**를 보고 에셋을 참조·연동한다. 새 리소스를 추가할 때는 위 경로·네이밍에 맞춰 넣는다.
- **Resources.Load**를 쓸 경우 **Resources 하위 상대경로만** 사용한다 (확장자 제외). §5 배치 경로와 로드 경로를 구분한다.
- 리소스 추가 후 **참조 깨짐이 없는지**, 빌드에 포함되는지(Resources 사용 시 해당 폴더에 넣었는지) 확인한다.
- **대용량 리소스**(고해상도 텍스처, 긴 오디오 등)는 버전 관리 부담이 될 수 있음. 필요 시 [Conventions](../code/Conventions.md) §5의 Git LFS 검토를 참고한다.
