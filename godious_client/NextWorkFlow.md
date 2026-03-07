# Godius Remaster - 추후 작업 계획 (NextWorkFlow)


---

## Phase A: 32비트 → 64비트 전환 (스팀 런칭 필수)

### A-1. 프로젝트 설정 전환
- [ ] vcxproj에 x64 플랫폼 구성 추가 (Debug|x64, Release|x64)
- [ ] 현재 Win32 전용 설정 → x64 병행 빌드 가능하도록 구성
- [ ] 출력 디렉토리/중간 디렉토리 x64 분리

### A-2. MSSDK7 의존성 제거
현재 MSSDK7\lib (32비트 전용)에서 링크하는 라이브러리:

| 라이브러리 | 용도 | 대체 방안 |
|-----------|------|----------|
| dinput.lib | DirectInput (마우스 입력) - `DirectMouse.cpp` | 윈도우 메시지 처리 (WM_INPUT / Raw Input) |
| dsound.lib | DirectSound (효과음) - `DSWave.cpp` | 오픈소스 오디오 라이브러리 (SDL_mixer, FMOD, miniaudio 등) |
| dxguid.lib | DirectX GUID 정의 | 필요한 GUID만 직접 정의 또는 Windows SDK dxguid.lib 사용 |

MSSDK7\include 헤더 의존:
- `dinput.h` → DirectInput 제거 시 불필요
- `dmusici.h` → DirectMusic 제거 시 불필요
- `dsound.h` → DirectSound 제거 시 불필요

### A-3. DirectInput 제거 → Windows 메시지 처리 전환
- [ ] `DirectMouse.cpp` — `DirectInputCreate()` 제거
- [ ] Raw Input API (`RegisterRawInputDevices`, `WM_INPUT`) 또는 `WM_MOUSEMOVE`/`WM_LBUTTONDOWN` 등으로 교체
- [ ] `GETDXVER.CPP` — DirectInput DLL 로드 코드 제거 (이미 비활성화 중)

### A-4. DirectMusic / DirectSound 제거 → 오픈소스 오디오 교체
- [ ] `DmidiPlay.cpp` — DirectMusicPerformance 제거, MIDI 배경음악 재생 교체
- [ ] `DSWave.cpp` — `DirectSoundCreate()` 제거, WAV 효과음 재생 교체
- [ ] 오디오 라이브러리 후보 선정:
  - **miniaudio** (헤더 전용, 경량, MIT 라이선스) — 추천
  - **SDL2_mixer** (MIDI+WAV+MP3, 검증된 라이브러리)
  - **FMOD** (상용, 스팀 게임에서 널리 사용)

### A-5. NPGameLib (nProtect GameGuard) 처리
- [ ] 현재 `NPGameLib_MT.lib` / `NPGameLib_MTd.lib` — **32비트 전용 정적 라이브러리**
- [ ] D3D 디바이스 체크 함수 (`SetD3DDeviceInfo`, `CheckD3DDevice`) 포함 — DX11 연동 영향
- [ ] 패킷 암/복호화 기능 포함 — 제거 시 자체 구현 필요
- [ ] 스팀 런칭 시 GameGuard 유지 여부 결정
  - 유지 시: INCA에 64비트 라이브러리 요청
  - 제거 시: `NO_GAMEGUARD` 전처리기 활성화 (이미 코드에 분기 존재)
- [ ] 스팀 자체 Anti-Cheat (VAC 또는 EAC) 도입 검토

### A-6. CharBind.dll 64비트 대응
- [ ] `Winmain.cpp:722` — `LoadLibrary("CharBind.dll")` 런타임 로드
- [ ] CharBind.dll 소스가 있으면 x64로 재빌드
- [ ] 소스가 없으면 기능을 본체에 통합하거나 대체

### A-7. 커스텀 PE 로더 (Dll.h/Dll.cpp) 64비트 수정
- [ ] `RVATOVA` 매크로: `(DWORD)(base)` → `(ULONG_PTR)(base)` 변경 (Dll.h:30)
- [ ] CDLL 클래스 전체 포인터/주소 캐스팅 검토 — DWORD → DWORD_PTR/ULONG_PTR
- [ ] PE32+ (64비트 PE) 구조체 대응 (`IMAGE_OPTIONAL_HEADER` → `IMAGE_OPTIONAL_HEADER64`)
- [ ] 또는 커스텀 PE 로더가 불필요하면 제거 검토

### A-8. AES 암호화 모듈 확인
- [ ] `AES.h` / `AES.cpp` — 자체 AES 구현 (패킷 암호화)
- [ ] 64비트 정수/포인터 크기 변경에 따른 호환성 점검
- [ ] 필요 시 검증된 라이브러리로 교체 검토

### A-9. 코드 레벨 64비트 호환성 수정
- [ ] `SetWindowLong(GWL_WNDPROC)` → `SetWindowLongPtr(GWLP_WNDPROC)` (`Hangul.cpp:87`)
- [ ] 프로젝트 전체 DWORD↔포인터 캐스팅 검토 (현재 소수 확인됨, 추가 점검 필요)
- [ ] `sprintf`/`printf` 포인터 포맷 (`%x` → `%p`, `%d` → `%zd` 등)

### A-10. 기타 링크 라이브러리 (64비트 전환 시 자동 대응)
아래는 Windows SDK가 64비트 버전을 제공하므로 별도 작업 불필요:

| 라이브러리 | 용도 | 비고 |
|-----------|------|------|
| ws2_32.lib | WinSock2 (네트워크) | Windows SDK 제공 |
| d3d11.lib / dxgi.lib / d3dcompiler.lib | DX11 렌더링 | Windows SDK 제공 |
| imm32.lib | IME 한글 입력 | Windows SDK 제공 |
| winmm.lib | 멀티미디어 타이머 (`timeGetTime`) | Windows SDK 제공 |
| version.lib | 버전 정보 API | Windows SDK 제공 |
| iphlpapi.lib | IP 헬퍼 (MAC 주소 등) | Windows SDK 제공 |
| wbemuuid.lib | WMI (하드웨어 정보) | Windows SDK 제공 |
| Msimg32.lib | GDI `TransparentBlt()` | Windows SDK 제공 |
| DbgHelp.lib | 미니덤프 | Windows SDK 제공 |
| odbc32.lib / odbccp32.lib | ODBC 데이터베이스 | Windows SDK 제공 (사용 여부 확인 필요) |
| strmiids.lib | DirectShow (Debug 빌드만) | Windows SDK 제공 |

### A-11. 관련 도구 프로젝트 64비트 현황

| 프로젝트 | 현재 플랫폼 | 외부 의존성 | 비고 |
|----------|------------|------------|------|
| RESTools (EF.vcxproj) | Win32 | cpprestsdk v2.9.1 (NuGet), jsoncpp | x64 전환 시 NuGet 패키지 재설정 필요 |
| SPRToDDS (SPRToDDS.vcxproj) | **x64** | DirectXTex (NuGet) | 이미 64비트 — 대응 불필요 |


---

## Phase B: 최적화

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

## Phase C: 문제점 수정

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

## Phase D: 스팀 런칭 필요 작업

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

### D-3. 서버 측 작업
- [ ] Steam Auth Ticket 서버 검증 API 구현
- [ ] Steam ID 기반 계정 연동 (기존 계정 시스템 ↔ Steam ID 매핑)
- [ ] VAC (Valve Anti-Cheat) 또는 자체 보안 방안 결정
- [ ] 동시접속자 관리 / 스팀 매치메이킹 (필요 시)

### D-4. 스팀 스토어 준비
- [ ] 스토어 페이지 에셋 (캡처, 트레일러, 설명)
- [ ] Depot 구성 및 빌드 업로드 테스트
- [ ] 연령 등급 (IARC / 게임물관리위원회)
- [ ] 출시 지역 / 가격 정책 결정


---

## Phase E: 기타 요구 및 수정사항

### E-1. 원본 타일 및 업스케일링
- [ ] 원본 타일 리소스 정리
- [ ] AI 업스케일링 적용 방안 검토 (ESRGAN, Real-ESRGAN 등)
- [ ] 업스케일된 리소스 품질 검수 및 적용


---

## Phase F: 다국어 지원 (Localization)

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
| 6 | French (FR) | fr | 1.44% | EFIGS 핵심. 레트로 커뮤니티 활발, 인디 판매 높음 |
| 7 | German (DE) | de | 1.77% | EFIGS. EU 대형 시장, RPG/레트로 팬 다수 |
| 8 | Spanish (ES/LATAM) | es | 2.58% | EFIGS + 남미 성장세, 인디 레트로 인기 |
| 9 | Russian (RU) | ru | 6.09% | 스팀 사용자 3위, RPG/MMORPG 팬 다수 |
| 10 | Portuguese-Brazil (BR) | pt-BR | 2.37% | 인디/레트로 붐, MMORPG 팬 대량 |

> 1~5번은 **필수** 지원, 6~10번은 레트로 게임 시장성 기준 검토 후 추가

### F-4. 서버 측 다국어 대응
- [ ] 서버 → 클라이언트 메시지 다국어 처리 (에러 메시지, 시스템 공지 등)
- [ ] 채팅 인코딩 — UTF-8 통일 (기존 EUC-KR/CP949 → UTF-8 전환)
- [ ] 아이템/스킬/퀘스트 이름 다국어 DB 또는 리소스 테이블

### F-5. 스팀 다국어 연동
- [ ] Steamworks 언어 API 연동 (`SteamApps()->GetCurrentGameLanguage()`)
- [ ] 스토어 페이지 다국어 설명 작성
- [ ] 언어별 스크린샷/트레일러 (필요 시)


---

## 작업 순서 및 의존성

```
Phase A (64비트 전환)
  A-1  프로젝트 설정
  A-2  MSSDK7 제거         ← 선행: A-3, A-4
  A-3  DirectInput 제거
  A-4  오디오 교체
  A-5  GameGuard 처리
  A-6  CharBind.dll
  A-7  PE 로더 수정
  A-8  AES 암호화 확인
  A-9  코드 호환성 수정
  A-10 라이브러리 확인
  A-11 도구 프로젝트
        ↓
Phase B (최적화)          Phase C (버그 수정)       Phase F (다국어)
  B-1 초기화                C-1 워닝 정리              F-1 기반 구축
  B-2 실행                  C-2 포맷 문자열            F-2 이미지 텍스트
  B-3 배포/패키징            C-3 기타 문제              F-3 번역 작업
                                                      F-4 서버 대응
        ↓                         ↓                    F-5 스팀 연동
Phase D (스팀 런칭)       Phase E (기타)                  ↓
  D-1 SDK 통합               E-1 업스케일링          Phase D에 합류
  D-2 기능 연동
  D-3 서버 작업
  D-4 스토어 준비
```

### 의존성 요약
- **Phase A**가 최우선 — 64비트 전환 완료 후 다른 작업 진행
- Phase B, C, F는 Phase A 완료 후 병행 가능
- Phase F (다국어)는 Phase A 이후 독립 진행 가능하나, F-5(스팀 연동)는 Phase D와 연계
- Phase D는 Phase A 완료 필수 (스팀은 64비트 권장)
- Phase E는 독립적으로 진행 가능


---

## 예상 일정

| Phase | 항목 | 난이도 | 예상 시간 | 비고 |
|-------|------|--------|----------|------|
| A | 64비트 전환 | 높음 | 1~2주| MSSDK7 제거 + 오디오 교체가 핵심 |
| B | 최적화 | 중간 | 0.5주| 프로파일링 후 판단 |
| C | 버그 수정 | 낮음 | 0.5주| 워닝/포맷 문자열은 기계적 작업, Phase A와 병행 가능 |
| D | 스팀 런칭 | 중간 | 1주| SDK 통합 + 서버 연동 |
| E | 업스케일링 | 낮음 |2주 | 도구 기반 작업 |
| F | 다국어 (기반 구축) | 높음 |1주 | 시스템 설계 + 이미지 텍스트 교체 |
| F | 다국어 (번역 작업) | 중간 |1주 | 언어 수에 비례하여 증가 |

### 다국어 출시 전략

다국어 10개 언어 전부를 출시 전에 넣으려 하면 일정이 크게 늘어남.
스팀에서는 **Early Access로 2~3개 언어 먼저 출시 → 언어 추가 업데이트** 패턴이 일반적.

| 단계 | 언어 | 시점 |
|------|------|------|
| Early Access 출시 | 한국어 + 영어 | 초기 출시 |
| 1차 언어 추가 | 일본어, 중국어 간체/번체 | 출시 후 업데이트 |
| 2차 언어 추가 | 프랑스어, 독일어, 스페인어 (EFIGS) | 정식 출시 또는 이후 |
| 3차 언어 추가 | 러시아어, 브라질 포르투갈어 | 시장 반응 보고 결정 |
