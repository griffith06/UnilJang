# Godius Remaster - 추후 작업 계획 (NextWorkFlow)


---

## 4주 작업 범위

**이번 스프린트 포함 (4주):**
- Phase A (64비트 전환) — DirectInput 완료, RESTools x64 제외
- Phase B (최적화)
- Phase C (버그 수정) — Phase A와 병행
- Phase D (스팀 클라이언트만) — 서버 작업 별도
- Phase E-2 (SPR2 True Color), E-3 (인게임 에디터)
- 렌더링 개선 Step 0 ~ Step 9 (Rendering개선작업.md 참조)

**후순위 (이번 스프린트 이후):**
- Phase E-1 (업스케일링) — 리소스 200MB→800MB 문제, 최대한 후순위
- Phase F (다국어) — Early Access 이후 단계적 추가
- 렌더링 Step 10~15
- D-3 (서버 측 스팀 작업), D-4 (스토어 준비)
- 마무리 통합 테스트

**작업 순서 (비주얼 완성도 우선):**
1. SPR2 동작 + 라이트맵/밤낮 + 렌더 기반 + 기본 에디터 모드
2. 물 렌더링 + 배경 흔들림 + 후처리
3. 왜곡 + 파티클 + 환경 통합
4. 전투 타격감 + 스팀 SDK

> Phase A (64비트 전환)는 1주차 앞부분에서 ~2.5일로 먼저 완료 후 비주얼 작업 돌입


---

## Phase A: 32비트 → 64비트 전환 (~2.5일)

> **게임 클라이언트(GcX.exe)만 x64 전환. RESTools는 Win32 유지.**
> SPR2 파일 포맷은 고정 크기 타입(uint32_t, int16_t)으로 설계되어 32/64비트 무관.

### A-1. 프로젝트 설정 전환 (~2h)
- [ ] vcxproj에 x64 플랫폼 구성 추가 (Debug|x64, Release|x64)
- [ ] 현재 Win32 전용 설정 → x64 병행 빌드 가능하도록 구성
- [ ] 출력 디렉토리/중간 디렉토리 x64 분리

### A-2. MSSDK7 의존성 제거
MSSDK7\lib (32비트 전용)에서 링크하는 라이브러리 — **모두 제거 대상**:

| 라이브러리 | 용도 | 상태 |
|-----------|------|------|
| dinput.lib | DirectInput (마우스 입력) | ✅ **제거 완료** (Raw Input 전환) |
| dsound.lib | DirectSound (효과음) - `DSWave.cpp` | → XAudio2 교체 (A-4) |
| dxguid.lib | DirectX GUID 정의 | → Windows SDK dxguid.lib 사용 또는 필요 GUID 직접 정의 |

MSSDK7\include 헤더 — **모두 불필요**:
- ~~`dinput.h`~~ → ✅ 제거 완료
- `dmusici.h` → DirectMusic 제거 시 불필요
- `dsound.h` → DirectSound 제거 시 불필요

### ~~A-3. DirectInput 제거~~ → ✅ 완료

### A-4. DirectMusic / DirectSound 제거 → XAudio2 통일 (~1일)
- [ ] `DSWave.cpp` — `DirectSoundCreate()` 제거, **XAudio2**로 WAV 효과음 재생 교체
- [ ] `DmidiPlay.cpp` — DirectMusicPerformance 제거
- [ ] **MIDI 18곡 (East1~18.mid, 합계 189KB) → OGG 사전 변환** (예상 +5~20MB)
- [ ] XAudio2로 WAV 효과음 + OGG 배경음악 통일 재생
- [ ] MSSDK7\include, MSSDK7\lib 참조 완전 제거

> **XAudio2**: Windows SDK 내장 (`#include <xaudio2.h>`), 추가 의존성 없음

### A-5. NPGameLib (nProtect GameGuard) 제거 (~2h)
- [x] ~~패킷 암/복호화~~ → 미사용 확인 완료
- [ ] `NO_GAMEGUARD` 전처리기 Release에도 활성화
- [ ] NPGameLib 관련 파일 정리: `NPGameLib/`, `GameGuard/`, 콜백 코드(`Winmain.cpp:220-365`)
- [ ] 스팀 Anti-Cheat (VAC/EAC) 도입은 Phase D에서 검토

### A-6. CharBind.dll 64비트 대응 (~2~4h)
- [ ] `Winmain.cpp:722` — `LoadLibrary("CharBind.dll")` 런타임 로드
- [ ] CharBind.dll 소스가 있으면 x64로 재빌드
- [ ] 소스가 없으면 기능을 본체에 통합하거나 대체

### A-7. 커스텀 PE 로더 (Dll.h/Dll.cpp) 64비트 수정 (~2~4h)
- [ ] `RVATOVA` 매크로: `(DWORD)(base)` → `(ULONG_PTR)(base)` 변경 (Dll.h:30)
- [ ] CDLL 클래스 전체 포인터/주소 캐스팅 검토 — DWORD → DWORD_PTR/ULONG_PTR
- [ ] PE32+ (64비트 PE) 구조체 대응 (`IMAGE_OPTIONAL_HEADER` → `IMAGE_OPTIONAL_HEADER64`)
- [ ] 또는 커스텀 PE 로더가 불필요하면 제거 검토

### A-8. AES 암호화 모듈 확인 (~1h)
- [ ] `AES.h` / `AES.cpp` — 64비트 정수/포인터 크기 변경에 따른 호환성 점검
- [ ] 자체 AES 암호화 보안 개선은 후순위 — 현재 키/IV 하드코딩 문제 인지

### A-9. 코드 레벨 64비트 호환성 수정 (~2~4h)
- [ ] `SetWindowLong(GWL_WNDPROC)` → `SetWindowLongPtr(GWLP_WNDPROC)` (`Hangul.cpp:87`)
- [ ] 프로젝트 전체 DWORD↔포인터 캐스팅 검토
- [ ] `sprintf`/`printf` 포인터 포맷 (`%x` → `%p`, `%d` → `%zd` 등)

### 참고: 기타 링크 라이브러리 (자동 대응, 작업 불필요)
아래는 Windows SDK가 64비트 버전을 제공하므로 별도 작업 불필요:

| 라이브러리 | 용도 |
|-----------|------|
| ws2_32.lib | WinSock2 (네트워크) |
| d3d11.lib / dxgi.lib / d3dcompiler.lib | DX11 렌더링 |
| imm32.lib | IME 한글 입력 |
| winmm.lib | 멀티미디어 타이머 (`timeGetTime`) |
| version.lib / iphlpapi.lib / wbemuuid.lib | 시스템 정보 |
| Msimg32.lib / DbgHelp.lib | GDI / 미니덤프 |
| odbc32.lib / odbccp32.lib | ODBC (사용 여부 확인 필요) |
| strmiids.lib | DirectShow (Debug 빌드만) |

### 참고: 도구 프로젝트 현황

| 프로젝트 | 플랫폼 | x64 전환 | 비고 |
|----------|--------|----------|------|
| RESTools (EF.vcxproj) | Win32 | **안 함** | SPR2 포맷이 고정 크기 타입이라 32비트에서 생성해도 무관 |
| SPRToDDS (SPRToDDS.vcxproj) | x64 | 불필요 | 이미 64비트 |


---

## Phase B: 최적화 (4주차 병행)

### B-1. 초기화 부분 최적화
- [ ] 초기화 로딩 병목 지점 프로파일링 (SPR 로드, 맵 로드, 리소스 초기화)
- [ ] 병렬 로딩 또는 지연 로딩 적용 가능 지점 확인
- [ ] 로딩 화면/진행바 개선

### B-2. 실행 부분 최적화
- [ ] FPS 카운터 출력 → 프레임 속도 안정성 확인
- [ ] 프레임 병목 지점 프로파일링 (렌더링, 네트워크, 로직)
- [ ] 핫스팟 최적화 적용

### B-3. 배포 최적화 / 패키징
- [ ] 스팀 배포 방식 결정:
  - **스팀 권장**: Steamworks의 Depot 시스템 사용 — 파일 단위 diff 기반 업데이트 자동 처리
  - 초기 패키지는 1개 Depot에 전체 파일 포함 (개별 파일을 스팀 diff로 처리)
  - 대용량 리소스(맵, 스프라이트)는 별도 Depot으로 분리 가능 (DLC/선택적 다운로드)


---

## Phase C: 문제점 수정 (Phase A와 병행)

### C-1. 컴파일 워닝 정리
- [ ] 전체 빌드 워닝 목록 수집 (Warning Level 4)
- [ ] 타입 불일치, 미사용 변수, deprecated 함수 등 정리

### C-2. 포맷 문자열 버그 수정
- [ ] `sprintf`/`printf` 인자 타입 불일치 수정
- [ ] 버퍼 오버플로우 위험이 있는 `sprintf` → `snprintf` 전환 검토

### C-3. 기타 잠재적 문제 수정
- [ ] 메모리 누수 점검
- [ ] 버퍼 오버런 위험 코드 수정
- [ ] 초기화되지 않은 변수 사용 수정


---

## Phase D: 스팀 런칭 필요 작업 (4주차)

### D-1. Steamworks SDK 통합 (클라이언트)
- [ ] Steamworks SDK 다운로드 및 프로젝트 연동
- [ ] Steam 초기화 (`SteamAPI_Init`) / 종료 (`SteamAPI_Shutdown`)
- [ ] Steam 오버레이 호환성 확인 (DX11 렌더링과 연동)
- [ ] Steam 인증 (Auth Session Ticket) — 기존 로그인 시스템과 연동

### D-2. Steam 기능 연동 (클라이언트)
- [ ] 도전과제 (Achievements) 시스템 연동
- [ ] Steam 클라우드 세이브 (설정 파일 등)
- [ ] Steam 친구 목록 / 초대 기능 (선택)
- [ ] Steam 리치 프레즌스 (현재 게임 상태 표시)

### D-3. 서버 측 작업 — **별도 진행**
- [ ] Steam Auth Ticket 서버 검증 API 구현
- [ ] Steam ID 기반 계정 연동 (기존 계정 시스템 ↔ Steam ID 매핑)
- [ ] VAC (Valve Anti-Cheat) 또는 자체 보안 방안 결정
- [ ] 동시접속자 관리 / 스팀 매치메이킹 (필요 시)

### D-4. 스팀 스토어 준비 — **별도 진행**
- [ ] 스토어 페이지 에셋 (캡처, 트레일러, 설명)
- [ ] Depot 구성 및 빌드 업로드 테스트
- [ ] 연령 등급 (IARC / 게임물관리위원회)
- [ ] 출시 지역 / 가격 정책 결정


---

## Phase E: 기타 요구 및 수정사항

### E-1. 원본 타일 및 업스케일링 — **후순위**
> 리소스 200MB → 4배 업스케일 시 800MB. 최대한 뒤로 미룸.

- [ ] 원본 타일 리소스 정리
- [ ] AI 업스케일링 적용 방안 검토 (ESRGAN, Real-ESRGAN 등)
- [ ] 업스케일된 리소스 품질 검수 및 적용

### E-2. RESTools SPR2 True Color 포맷 지원 (1주차)
- [ ] 기존 SPR 포맷 (256컬러 팔레트) → SPR2 True Color 포맷 지원 추가
- [ ] **CDib32 신규 클래스 작성** — 기존 CDib(8bit)는 그대로 유지하고 32bit ARGB 전용 클래스를 병렬 추가. PNG 소스 → CDib32 경로, PCX 소스 → 기존 CDib 경로로 분기. 기존 코드 수정 최소화.
- [ ] SPR2 이미지 데이터: DDS BC7 블록 압축 적용 (GPU 네이티브 디코딩)
- [ ] **SPR2 ARGB8888(비압축) 포맷 호환** — 라이팅 스탬프 등 정확한 색상/알파 그라데이션이 필요한 리소스용 (BC Format = 0xFF). `DXGI_FORMAT_B8G8R8A8_UNORM`으로 GPU 텍스쳐 생성
- [ ] RESTools (EF.vcxproj)에서 SPR2 읽기/쓰기 구현 (BC 압축 + ARGB8888 비압축 양쪽 지원, CDib32 + CSprite2 기반)
- [ ] 캐릭터 에디터 트루컬러 파츠 합성 — CDib32 기반 5레이어 32bit ARGB 합성
- [ ] 클라이언트 측 SPR2 로딩/렌더링 대응 (BC 포맷 및 ARGB8888 포맷 분기 처리)
- [ ] **SPR / SPR2 듀얼 포맷 지원** — 게임에서 기존 SPR과 신규 SPR2 모두 로딩 가능하도록 구현

**SPR vs SPR2 (DDS BC7) 비교 분석:**

| 관점 | SPR (현재) | SPR2 (DDS BC7) |
|------|-----------|----------------|
| 색상 | 256컬러 팔레트 | True Color (32bit ARGB) |
| 압축 | RLE (투명 영역 0 byte, 매우 효율적) | BC7 고정 1 byte/pixel (4×4 블록 단위) 또는 ARGB8888 비압축 4 byte/pixel (라이팅 스탬프 등) |
| 디스크 용량 | 기준 (100MB / 3214파일) | 증가 예상 (1.5~2.5배) — RLE의 투명 영역 효율을 잃음 |
| GPU 메모리 | 4 byte/pixel (BGRA로 디코딩 후 업로드) | **1 byte/pixel** (BC7 그대로 사용) |
| CPU 프레임 부하 | RLE 디코딩 + 팔레트 LUT + DYNAMIC 텍스처 매 프레임 전송 | **없음** (IMMUTABLE, 로딩 시 1회) |
| 렌더링 성능 | 매 프레임 CPU→GPU 전송 (WRITE_DISCARD) | **GPU SRV 바인딩만** (CPU 개입 없음) |
| 화질 | 256색 제한 | True Color (거의 무손실) |

**성능 이점 요약:**
- CPU 부하 제거: RLE 디코딩 + 팔레트 변환 + 매 프레임 텍스처 업로드 → 로딩 시 1회로 감소
- GPU 메모리 절약: BGRA 4byte/pixel → BC7 1byte/pixel (4:1 압축)
- 렌더링: DYNAMIC → IMMUTABLE 전환으로 드라이버 오버헤드 감소

### E-3. 인게임 에디터 모드 (GcX.exe -editor + ImGui) (1주차)
> 렌더링개선작업.md Step 0과 동일. 렌더링 파라미터 편집의 기반 인프라.

- [ ] GcX.exe에 `-editor` 커맨드라인 모드 추가 (오프라인, 서버 접속 불필요)
- [ ] `-map <맵이름> -pos <x,y>` 커맨드라인 지원 — 지정 맵/위치 바로 진입
- [ ] 핫리로드 기능 — `'r'` 키로 현재 맵 데이터(`.lgt`, `.cfg`, `.map` 등) 재로드
- [ ] **ImGui docking 브랜치 통합** — DX11 백엔드 연결
- [ ] **ImGui Multi-Viewport 활성화** (`ImGuiConfigFlags_ViewportsEnable`) — 에디터 패널을 OS 독립 창으로 분리하여 게임 뷰포트를 가리지 않음
- [ ] `-editor` 플래그 없으면 ImGui 미초기화 (일반 유저 무영향)
- [ ] 에디터 패널 프레임워크 — 패널 등록/활성화/비활성화, 레이아웃 저장/복원
- [ ] **RESTools ↔ GcX.exe Named Pipe IPC 연동** — 맵 열기/스크롤 동기화, 저장 시 자동 리로드 (3주차 병행)
- [ ] RESTools 맵 에디터 시작 시 `GcX.exe -editor` 자동 실행 (3주차 병행)

**역할 분담:**
| 역할 | 담당 |
|------|------|
| SPR/SPR2 제작, 타일맵 편집, FGP 배치 | RESTools (EF.exe) — Win32 유지 |
| 광원/물/환경/포스트프로세싱 파라미터 편집 | GcX.exe -editor (ImGui 독립 창) |

**주의사항 및 향후 개선:**
- [ ] 프레임별 개별 DDS 파일 → 파일 수 폭증 문제 → **아틀라스(Spritesheet) 패킹** 검토
- [ ] 작은 스프라이트 BC7 패딩 낭비 → 스프라이트 크기별 BC 포맷 선택 검토 (BC1/BC3/BC7)
- [ ] 초기 로딩 시 다수 파일 I/O → 로딩 최적화 필요 (메모리 맵, 번들링 등)


---

## Phase F: 다국어 지원 (Localization) — **후순위**

> Early Access 이후 단계적 추가. 이번 4주 스프린트에 포함하지 않음.

### F-1. 다국어 시스템 기반 구축
- [ ] 텍스트 데이터 외부화 — 하드코딩된 한국어 문자열을 키-값 리소스 파일로 분리
- [ ] 언어별 리소스 파일 구조 설계 (JSON/CSV/PO 등)
- [ ] 런타임 언어 전환 시스템 구현 (설정 파일 또는 스팀 언어 감지)
- [ ] 폰트 시스템 — 각 언어별 글리프 지원 폰트 준비 (CJK, 라틴, 키릴 등)
- [ ] 텍스트 렌더링 — 가변 폭 문자/줄바꿈/오버플로 처리

### F-2. 이미지 내 한글 텍스트 처리
- [ ] UI에 이미지로 박혀있는 한글 텍스트 목록 전수 조사
- [ ] 이미지 텍스트 → 런타임 텍스트 렌더링으로 교체 (언어별 동적 생성)
- [ ] 교체 불가능한 이미지는 언어별 이미지 세트 제작

### F-3. 지원 언어 (우선순위순)

| 순위 | 언어 | 코드 | 스팀 점유율 | 비고 |
|------|------|------|-----------|------|
| 1 | **English** (US) | en | 22.27% | 필수. 스팀 매출 1위, 레트로/인디 RPG 최대 시장 |
| 2 | **Japanese** (JP) | ja | 1.60% | 필수. 픽셀 아트/레트로 RPG 최적 시장, MMORPG 팬 다수 |
| 3 | **Korean** (KR) | ko | 1.06% | 필수. 홈 시장, 기존 UI 한국어 기반 |
| 4 | **Simplified Chinese** (CN) | zh-CN | 54.60% | 필수. MMORPG 거대 시장, 스팀 중국 버전 별도 심사 필요 |
| 5 | **Traditional Chinese** (TW/HK) | zh-TW | — | 필수. 대만/홍콩 시장 |
| 6 | French (FR) | fr | 1.44% | EFIGS 핵심 |
| 7 | German (DE) | de | 1.77% | EFIGS |
| 8 | Spanish (ES/LATAM) | es | 2.58% | EFIGS + 남미 |
| 9 | Russian (RU) | ru | 6.09% | 스팀 사용자 3위 |
| 10 | Portuguese-Brazil (BR) | pt-BR | 2.37% | 인디/레트로 붐 |

> 1~5번은 **필수** 지원, 6~10번은 시장 반응 보고 결정

### F-4. 서버 측 다국어 대응
- [ ] 서버 → 클라이언트 메시지 다국어 처리 (에러 메시지, 시스템 공지 등)
- [ ] 채팅 인코딩 — UTF-8 통일 (기존 EUC-KR/CP949 → UTF-8 전환)
- [ ] 아이템/스킬/퀘스트 이름 다국어 DB 또는 리소스 테이블

### F-5. 스팀 다국어 연동
- [ ] Steamworks 언어 API 연동 (`SteamApps()->GetCurrentGameLanguage()`)
- [ ] 스토어 페이지 다국어 설명 작성
- [ ] 언어별 스크린샷/트레일러 (필요 시)

### 다국어 출시 전략

| 단계 | 언어 | 시점 |
|------|------|------|
| Early Access 출시 | 한국어 + 영어 + 일본어 | 초기 출시 |
| 1차 언어 추가 | 중국어 간체/번체 | 출시 후 업데이트 |
| 2차 언어 추가 | 프랑스어, 독일어, 스페인어 (EFIGS) | 정식 출시 또는 이후 |
| 3차 언어 추가 | 러시아어, 브라질 포르투갈어 | 시장 반응 보고 결정 |


---

## 작업 순서 및 의존성

```
Phase A (64비트 전환, ~2.5일) ─── Phase C (버그 수정, 병행)
  A-1  프로젝트 설정 (2h)
  A-2  MSSDK7 제거
  ~~A-3  DirectInput~~ ✅ 완료
  A-4  오디오→XAudio2 통일 (1일)
  A-5  GameGuard 제거 (2h)
  A-6  CharBind.dll (2~4h)
  A-7  PE 로더 (2~4h)
  A-8  AES 확인 (1h)
  A-9  코드 호환성 (2~4h)
        │
        ▼
1주차: 비주얼 기반 ──────────────────────────────────────
  E-2  SPR2 (CDib32, CSprite2, BC압축, FGP v2)
  E-3  에디터 모드 (-editor, ImGui Multi-Viewport)
  Step 1  렌더 파이프라인 기반 (RT 관리, 셰이더, 블렌드 스테이트)
  Step 2  라이트맵 + 밤낮 사이클 + 광원 배치
        │
        ▼
2주차: 환경 렌더링 ──────────────────────────────────────
  Step 4  물 렌더링 (오버레이 + 굴절 + 맵별 설정)
  Step 5  포스트 프로세싱 (블룸, LUT, 비네트)
  Step 6  배경 오브젝트 흔들림 (바람 시스템)
        │
        ▼
3주차: 효과 + 통합 ──────────────────────────────────────
  Step 7  화면 왜곡 (타격/보스/열기/수중)
  Step 8  파티클 (엔진 + 환경 파티클)
  Step 9  분위기/환경 통합 (프리셋 + 날씨)
  Step 0-3  IPC 연동 (병행)
        │
        ▼
4주차: 전투 + 스팀 + 마무리 ─────────────────────────────
  Step 3  전투 피드백 (셰이크, 히트플래시, 히트프리즈, 데미지넘버)
  D-1,D-2  Steamworks SDK 클라이언트 통합
  B-1,B-2  프로파일링 + 최적화 (병행)
```

### 후순위 버퍼 (여유 생기면 추가)
- Step 3-5~3-7: 잔상, 스쿼시&스트레치, 트레일
- Step 4-5: 물 디테일 3단계 (파문/거품/깊이별 색조)
- Step 5-5~5-6: 크로매틱 어버레이션, 모션블러, 필름그레인
- Step 8-2 나머지: 낙엽/먼지/불씨 파티클
- Step 8-3: 인터랙션 파티클
- E-2 Phase 5: SPR→SPR2 일괄 변환기


---

## 예상 일정

| 주차 | 핵심 산출물 | 예상 |
|------|------------|------|
| **1주차** | x64 빌드 + SPR2 동작 + 라이트맵/밤낮 + 에디터 모드 | 5일 |
| **2주차** | 물 렌더링 + 후처리(블룸/LUT/비네트) + 배경 흔들림 | 5일 |
| **3주차** | 왜곡 + 파티클 + 환경 통합 + IPC | 5일 |
| **4주차** | 전투 타격감 + 스팀 SDK + 프로파일링/최적화 | 5일 |

| Phase | 항목 | 예상 시간 | 배치 |
|-------|------|----------|------|
| A | 64비트 전환 | ~2.5일 | 1주차 전반 |
| C | 버그 수정 | Phase A 병행 | 1주차 |
| E-2 | SPR2 True Color | ~2일 | 1주차 |
| E-3 | 에디터 모드 | ~1.5일 | 1주차 + 3주차(IPC) |
| 렌더링 Step 0~2 | 기반 + 라이트맵 | ~3일 | 1주차 |
| 렌더링 Step 4~6 | 물 + 후처리 + 배경 | ~5일 | 2주차 |
| 렌더링 Step 7~9 | 왜곡 + 파티클 + 환경 | ~4일 | 3주차 |
| 렌더링 Step 3 | 전투 피드백 | ~2일 | 4주차 |
| D | 스팀 클라이언트 | ~1일 | 4주차 |
| B | 최적화 | ~1일 | 4주차 병행 |
