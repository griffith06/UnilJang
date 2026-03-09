# RESTools (EF.exe) 상세 분석

## 개요

**EF** (Editor for Field/Effect) — MFC MDI(Multi Document Interface) 기반의 **게임 리소스 에디터**
- 빌드: **Win32 (x86)**, Visual Studio v143 (VS2022), MFC Dynamic(Debug)/Static(Release)
- 문자셋: **MultiByte** (MBCS)
- 구조체 정렬: **1Byte** (`StructMemberAlignment`)
- 버전: 1.2.4.4 (2022_01_13)

---

## 5개 메인 모듈 (MDI Document/View)

`CMainFrame`에서 5개 MDI 자식 윈도우를 생성한다.

### 1. Sprite Editor (SPR 도구)

| 파일 | 역할 |
|------|------|
| SprDoc.h/cpp | SPR 문서 — PCX 소스로부터 .spr 생성 |
| SprMainView.h/cpp | 3개 뷰: CSprMainView(소스), CSprTmpView(프레임 목록), CSprOriginView(원점 편집) |
| SprChildFrm.h/cpp | Splitter 프레임 |
| Sprite.h/cpp | 핵심 SPR 엔진 |
| BasicOriDlg.h/cpp | 기본 원점(Origin) 설정 다이얼로그 |

**기능:**
- PCX 이미지를 로드 → 영역 선택(Box/Free 모드) → **RLE 압축** → .spr 파일 생성
- 프레임 크기: 4x4, 8x8, 16x16, 32x32, 32x64, Free, UserSet
- 프레임 드래그&드롭으로 **순서 변경**, 복사/삭제
- 각 프레임별 **원점(Origin) 설정** — 애니메이션 기준점
- `CompressData()`: 스프라이트 RLE 압축 알고리즘
- `MakeCharSprite()` / `MakeObjSprite()`: 캐릭터용/오브젝트용 스프라이트 자동 생성
- `DrawSelectedProBlend()`: 블렌딩 렌더링 지원

### 2. Character Editor (캐릭터 도구)

| 파일 | 역할 |
|------|------|
| CharDoc.h/cpp | 캐릭터 파츠 조합 문서 |
| CharMainView.h/cpp | 캐릭터 소스 이미지 뷰 |
| CharMixView.h/cpp | 파츠 믹스 미리보기 |
| CharObjView.h/cpp | 오브젝트 뷰 |
| CharOriginView.h/cpp | 원점 편집 뷰 |
| CharTreeView.h/cpp | 트리 구조 탐색 |

**기능:**
- **5개 파츠 레이어** 합성: Leg(0), Weapon(1), Body(2), Head(3), Shield(4)
- 파츠별 속성: Part / Gender / Style / Color / Action
- 파일명 규칙 기반 자동 파츠 분류 (`GetDataStringByName()`)
- **애니메이션 타입**: `dANI_1213` (1-2-1-3 패턴), `dANI_123` (1-2-3 패턴)
- `sMIXSPRITE` 구조로 5개 파츠를 레이어 합성 → 캐릭터 완성 SPR 생성
- `BindingCharSprite()`: 최종 캐릭터 스프라이트 바인딩

### 3. Map Editor (맵 도구)

| 파일 | 역할 |
|------|------|
| MapDoc.h/cpp | 맵 문서 — 타일/속성/이벤트/몹배치 통합 관리 |
| Map.h/cpp | 맵 데이터 엔진(EFMap, CMapSou, CMapAttr, CFontBrush) |
| MapMainView.h/cpp | 맵 편집 뷰 |
| MapChildFrm.h/cpp | 맵 MDI 자식 프레임 |
| Mob.h/cpp | 몬스터 배치 데이터 |
| MobPlaceDlg.h/cpp | 몹 배치 다이얼로그 |

**기능:**
- **쿼터뷰(Isometric) 타일맵 에디터**
  - `GetCoodFromMapPosition()` 등 — 마름모(쿼터) ↔ 직교 좌표 변환 함수군
  - 페이지/폰트/도트 3단위 맵 사이즈 관리
- **PCX → 타일 폰트 소스**: `CMapSou`가 PCX를 로딩, 타일 폰트로 분할
- **브러시 시스템**: `CFontBrush` — 타일 선택/배치/그룹 브러시
- **속성 편집**: `CMapAttr` — 이동불가, 이벤트, 몬스터영역, 안전지대, 외곽 등 8종 비트플래그
  - `dEMPTY_ATTR(0)`, `dDONT_ATTR(1)`, `dEVENT_ATTR(2)`, `dMONAREA_ATTR(4)`, `dSAFEJON_ATTR(8)`, `dOUT_ATTR(16)`, `dATTR_32(32)`, `dATTR_64(64)`, `dATTR_128(128)`
- **이벤트 시스템**: 맵 이동, 캐릭터 방향 등 설정
- **FGP(Field Group)**: 맵에 필드 오브젝트 배치 (최대 50,000개)
- **몬스터 배치**: `CMob` 기반, 위치/방향/ID, 정렬/레이어 관리
- **자동 백업**: 60초 타이머, Undo 지원
- **레이더맵(미니맵)** 렌더링
- Fill, Resize 기능

### 4. Object Editor (필드 오브젝트 도구)

| 파일 | 역할 |
|------|------|
| ObjDoc.h/cpp | 오브젝트 문서 |
| ObjMainView.h/cpp | 오브젝트 편집 뷰 |
| ObjChildFrm.h/cpp | 오브젝트 MDI 자식 프레임 |
| FieldSprite.h/cpp | 필드 스프라이트/필드 오브젝트 엔진 |

**기능:**
- **3가지 오브젝트 타입**: Static(정적), Animation(애니), Action(액션)
- **레이어 시스템**: 최대 100개 레이어 (`dFIELD_SPR_MAX`)
- `CFieldObj` → 여러 `CFieldSprite`를 묶어 FGP(Field Group) 파일로 저장/로드
- 맵 에디터에서 사용할 배경 오브젝트(나무, 건물 등) 제작

### 5. Object Group Manager (오브젝트 그룹 관리)

| 파일 | 역할 |
|------|------|
| ObjGrpDoc.h/cpp | 그룹 문서 |
| ObjGrpMainView.h/cpp | 그룹 편집 뷰 |
| ObjGrpChildFrame.h/cpp | 그룹 MDI 자식 프레임 |
| FgpDlg.h/cpp | FGP 삽입 다이얼로그(트리뷰 + 썸네일 미리보기) |

**기능:**
- FGP 파일들을 트리 구조로 관리, 썸네일 미리보기
- 프레임별 오프셋/사이즈 계산, 피봇 편집
- FGP 리스트 저장 기능

---

## 핵심 엔진 클래스 (공통 의존성)

```
Float3 ──→ CDib ──→ CSprite ──→ CFieldSprite / CFieldObj
               │          │
               └→ CPcx    └→ CSprDoc, CCharDoc, CObjDoc, CMapSou
                                 │
                            EFMap ──→ CMapAttr, CFontBrush, CMob
```

| 클래스 | 역할 | 핵심 기술 |
|--------|------|-----------|
| **CDib** | 8bit DIB(Device Independent Bitmap) 래퍼 | 256색 팔레트, LPBYTE 직접 픽셀 접근, 블렌딩 테이블 `g_blendPalTable[4][255][255]` |
| **CSprite** | SPR 포맷 핵심 엔진 | RLE 압축/해제, Origin 관리, 클리핑, 블렌딩 드로우, 임시 스프라이트 링크드리스트 |
| **CPcx** | PCX 이미지 I/O | 8bit PCX 읽기/쓰기, RLE 디코딩 (`LineDec`) |
| **CFieldSprite** | 위치 + 원점 + 스프라이트 묶음 | 단일 스프라이트의 필드 배치 단위 |
| **CFieldObj** | 필드 오브젝트 | 다중 레이어 스프라이트 묶음, FGP 파일 I/O, 바운딩박스/히트테스트 |
| **EFMap** | 맵 데이터 | 타일 배열(LPWORD), 쿼터뷰 좌표 변환, Undo, FGP 배치 관리 |
| **Float3** | 3D 벡터 유틸 | 팔레트 블렌딩 보간 계산용 |
| **EFConfig** | 설정/맵 이름 관리 | `map<CString, IntArray>` 맵ID↔이름 매핑 |

### 기타 유틸 파일

| 파일 | 역할 |
|------|------|
| DDMem.h/cpp | DirectDraw 메모리 관리 (레거시) |
| Dlg.h/cpp | 공통 다이얼로그 유틸 |
| MyComboBox.h/cpp | 커스텀 콤보박스 컨트롤 |
| MiniDump/MinidumpHelp.h/cpp | 크래시 덤프 |
| EFConfig.h/cpp | 맵 이름/ID 설정 관리 |

---

## 파일 포맷 정리

| 확장자 | 용도 | 생성 모듈 |
|--------|------|-----------|
| **.spr** | 스프라이트 (RLE 압축 프레임 모음) | Sprite Editor / Char Editor |
| **.pal** | 256색 팔레트 (RGBQUAD[256]) | CDib |
| **.pcx** | 소스 이미지 (8bit) | CPcx (입력/출력) |
| **.fgp** | 필드 그룹 (다중 레이어 스프라이트 묶음) | Object Editor |
| **.map** | 타일맵 데이터 (WORD 배열) | Map Editor |
| **.att** | 맵 속성 데이터 (비트플래그) | Map Editor |
| **.nod** | 트리 구조 데이터 (CharTree, ObjTree, FgpTree, MobMgrTree) | 각 트리뷰 |
| **.dat** | 캐릭터/몬스터 데이터 | Char Editor |
| **.cfg** | 맵 설정 | Map Editor |

---

## 리소스 파일

| 파일 | 용도 |
|------|------|
| EF.rc | 메인 리소스 스크립트 |
| resource.h | 리소스 ID 정의 |
| GODIUS.ICO | 앱 아이콘 |
| H_move.cur | 이동 커서 |
| res/*.bmp | 툴바 비트맵 |
| res/*.cur | 커서 리소스 |

---

## 64비트 변환 시 주의사항

1. **`LPBYTE`, `HGLOBAL`, `LPWORD` 직접 포인터 연산** — 포인터 크기 변경 영향 큼 (특히 `CSprite`의 `m_iIdx`(int*) 오프셋 계산)
2. **구조체 1바이트 정렬** (`StructMemberAlignment: 1Byte`) — 파일 I/O와 직결, 64비트에서도 유지 필수 (`#pragma pack(1)`)
3. **SPR 파일 포맷**: `int *offset` + `LPBYTE image` — 오프셋이 int(4바이트) 고정이면 호환, 포인터 크기면 비호환
4. **Win32 API 타입**: `WORD`(16bit), `DWORD`(32bit)는 안전. `LONG_PTR`/`UINT_PTR` 미사용 부분 확인 필요
5. **`TargetMachine: MachineX86`** → `MachineX64`로 변경, Platform 추가 필요
6. **MFC Dynamic DLL**: 64비트 MFC DLL 필요
7. **`sFileBind`**: `fileName[21]` + `int` + `int` — 패딩 주의

---

## RESTools 개선 리스트

### 배경

- 게임 엔진이 DX11 트루컬러로 전환 완료 (WorkFlow.md 참조)
- 기존 256색 리소스 하위호환 유지하면서 트루컬러 리소스 제작 환경 필요
- 신규 SPR2 포맷 도입: BC 압축 기반 DX11 텍스쳐

### pragma pack(1) 판단

현재 파일 I/O는 **필드 단위 fread/fwrite**를 사용하므로 구조체 통째 읽기가 아님:
```cpp
// 현재 방식 (Sprite.cpp) — 필드별 개별 읽기
fread(com, 4, 1, fp);              // "EAST"
fread(&ver, sizeof(WORD), 1, fp);
fread(&m_iSprMax, sizeof(int), 1, fp);
fread(m_iIdx, sizeof(int), m_iSprMax + 1, fp);
```
- **SPR2 신규 포맷**: pack(1) 없이 설계 가능 (고정 크기 타입 uint32_t, int16_t 사용)
- **기존 SPR 리더**: 필드별 fread라 64비트에서도 문제없음
- **FGP 치명적 버그**: `fread(&location, sizeof(LPBYTE), 1, fp)` — 32bit=4바이트, 64bit=8바이트로 깨짐. FGP v2에서 수정 필수

### SPR2 도입 시 파일 포맷 영향

| 파일 | 영향 | 설명 |
|------|------|------|
| **.spr** | 대체됨 (하위호환 읽기 유지) | SPR2가 대체, 기존 CSprite 로더 공존 |
| **.pal** | 축소됨 | 레거시 SPR용으로만 필요, SPR2는 팔레트 불필요 |
| **.fgp** | 수정 필요 | 내부에서 .spr 파일명 참조 → .spr2 지원 추가, sizeof(LPBYTE) 버그 수정 |
| **.loc** | 수정 불필요 | FGP 파일명만 참조, SPR 직접 참조 없음 |
| **.map** | 수정 불필요 | 타일 인덱스(WORD[])만 저장, SPR 무관 |
| **.att** | 수정 불필요 | 속성 비트플래그만, SPR 무관 |
| **.pcx** | 입력으로 유지 | 기존 소스 입력용으로 계속 사용 |
| **.nod** | 확인 필요 | 트리 데이터에 파일 경로 포함 시 .spr2 인식 필요 |
| **.dat** | 확인 필요 | 캐릭터 파일명 규칙에 확장자 포함 여부 |

### SPR2 파일 포맷 (안)

```
SPR2 Header (자연 정렬, pragma pack 불필요):
  Offset  Size    Type        Description
  0       4       char[4]     Magic: "SPR2"
  4       4       uint32_t    Version (0x0100)
  8       4       uint32_t    Frame Count
  12      4       uint32_t    BC Format (0=BC1, 1=BC3, 7=BC7, 0xFF=ARGB8888 비압축 등)
  16      4       uint32_t    Flags (블렌딩 스타일, 알파 모드 등)
  20      4       uint32_t    Original Width (소스 이미지 전체 폭)
  24      4       uint32_t    Original Height
  28      4       uint32_t    Reserved

Frame Table (32 bytes per frame x Frame Count):
  +0      4       uint32_t    Data Offset (파일 내 BC 블록 시작)
  +4      4       uint32_t    Data Size (BC 압축 크기)
  +8      2       uint16_t    Width (프레임 폭)
  +10     2       uint16_t    Height (프레임 높이)
  +12     2       int16_t     Origin X
  +14     2       int16_t     Origin Y
  +16     4       uint32_t    Mip Levels
  +20     4       uint32_t    Row Pitch
  +24     8       uint8_t[8]  Reserved
```

핵심 차이점:
- 모든 타입이 **고정 크기** (uint32_t, int16_t 등) → 32/64비트 모두 동일
- RLE 대신 **BC(Block Compression)** → GPU에서 직접 텍스쳐로 사용
- Flags 필드에 **블렌딩 스타일** 저장 (Normal, Additive, Alpha 등)
- BC 포맷 옵션: BC0~BC7까지 속성에서 지정한 값으로 저장
- **ARGB8888(비압축) 포맷 지원** (BC Format = 0xFF): 라이팅 스탬프 등 정확한 색상/알파 그라데이션이 필요한 리소스용. BC 압축 없이 ARGB 32bit 원본 그대로 저장. `DXGI_FORMAT_B8G8R8A8_UNORM`으로 GPU 텍스쳐 생성

### 툴 작업 순서

#### Phase 1: 기반 인프라 (선행 작업)

| # | 작업 | 설명 | 영향 파일 |
|---|------|------|-----------|
| 1-1 | PNG 로더 추가 | stb_image 도입, CDib에 PNG→32bit 로딩 추가 | Dib.h/cpp, StdAfx.h |
| 1-2 | CDib 트루컬러 확장 | 8bit 전용 → 32bit RGBA 지원 추가 (기존 8bit 공존) | Dib.h/cpp |
| 1-3 | BC 압축 라이브러리 도입 | DirectXTex 통합 | 신규, StdAfx.h |
| 1-4 | SPR2 포맷 클래스 작성 | CSprite2 — SPR2 읽기/쓰기, BC 압축/해제 + **ARGB8888(비압축) 포맷 호환** (라이팅 스탬프 등) | Sprite2.h/cpp (신규) |
| 1-5 | FGP 포맷 v2 | sizeof(LPBYTE) 버그 수정, .spr/.spr2 양쪽 참조 지원 | FieldSprite.h/cpp |

#### Phase 2: Sprite Editor 개선

| # | 작업 | 설명 | 영향 파일 |
|---|------|------|-----------|
| 2-1 | 소스 로딩 확장 | PCX + PNG 모두 지원, 파일 다이얼로그 필터 추가 | SprDoc.cpp, SprMainView.cpp |
| 2-2 | 트루컬러 프리뷰 | CSprMainView에서 32bit 소스 이미지 표시 | SprMainView.cpp |
| 2-3 | SPR2 저장 | 프레임 선택 → BC 압축 → .spr2 저장 | SprDoc.cpp |
| 2-4 | BC 포맷 옵션 UI | 속성/툴옵션에서 BC0~BC7 + ARGB8888(비압축) 선택 | EFConfig.h/cpp, Dlg.cpp |
| 2-5 | SPR2 로딩/편집 | 기존 .spr2 파일 열어서 프레임 편집 | SprDoc.cpp, Sprite2.cpp |
| 2-6 | 블렌딩 스타일 UI | 이펙트용: Normal/Additive/Alpha 선택 저장 | SprDoc.cpp, Dlg.cpp |

#### Phase 3: Character Editor 개선

| # | 작업 | 설명 | 영향 파일 |
|---|------|------|-----------|
| 3-1 | 트루컬러 파츠 합성 | 5개 레이어 32bit 합성 | CharDoc.cpp, CharMixView.cpp |
| 3-2 | 캐릭터 SPR2 출력 | 합성 결과를 .spr2로 저장 | CharDoc.cpp, CharOriginView.cpp |

#### Phase 4: Object/Map Editor 개선

| # | 작업 | 설명 | 영향 파일 |
|---|------|------|-----------|
| 4-1 | FGP v2 저장/로드 | .spr2 참조 지원, 64비트 안전 | FieldSprite.cpp |
| 4-2 | Object Editor SPR2 | 오브젝트에 .spr2 레이어 지원 | ObjDoc.cpp, ObjMainView.cpp |
| 4-3 | Map Editor SPR2 프리뷰 | 맵에 SPR2 오브젝트 표시 | MapMainView.cpp |

#### Phase 5: 레거시 호환 / 마무리

| # | 작업 | 설명 | 영향 파일 |
|---|------|------|-----------|
| 5-1 | SPR→SPR2 일괄 변환기 | 기존 .spr + .pal → .spr2 배치 변환 | 신규 유틸 또는 메뉴 |
| 5-2 | 기존 SPR 로더 유지 | CSprite 클래스 그대로 공존 | Sprite.h/cpp (변경 없음) |
| 5-3 | .nod/.dat 확장자 처리 | 트리 데이터에서 .spr2 인식 | CharTreeView.cpp 등 |

### 게임 엔진 쪽 작업 (별도)

| # | 작업 | 설명 |
|---|------|------|
| G-1 | SPR2 로더 | BC 데이터 → DX11 CreateTexture2D 직접 생성 (CPU 디코딩 불필요). **ARGB8888 포맷은 `DXGI_FORMAT_B8G8R8A8_UNORM`으로 텍스쳐 생성** |
| G-2 | 블렌딩 모드 적용 | SPR2 Flags에서 블렌딩 스타일 → BlendState 전환 (Normal/Additive/Alpha) |
| G-3 | 기존 SPR 공존 | 현재 SPR 렌더링 파이프라인 유지, SPR2는 별도 경로 |
| G-4 | FGP v2 로더 | .spr/.spr2 양쪽 참조 지원 |
| G-5 | 팔레트 제거 경로 | SPR2 사용 시 팔레트 로딩/변환 스킵 → 직접 텍스쳐 바인딩 |
