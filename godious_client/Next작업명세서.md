# Godius Remaster — 세부 작업 명세서

> 이 문서는 NextWorkFlow.md의 4주 스프린트를 **step-by-step 실행 가능한 수준**으로 상세화한 것이다.
> 각 작업마다 **대상 파일, 구체적 변경 내용, 검증 방법**을 명시한다.

---

## 해상도 체계 — 런타임 변수 정리

렌더링 파이프라인에서 실제로 사용하는 3가지 크기 변수. render.ini `[Resolution]`에서 산출.

> `OriginalWidth` × `OriginalHeight`는 render.ini 설정값(1024×768)으로, 아래 `g_ViewWidth/Height` 계산의 **입력**으로만 쓰이고 런타임 렌더링에 직접 참조되지 않는다.

| 런타임 변수 | 기본값 예시 | 산출 방식 | 용도 |
|-------------|-------------|-----------|------|
| `g_ViewWidth` × `g_ViewHeight` | 1024×768 | Original 종횡비(4:3) × 윈도우 비율 → 4px 정렬 | 뷰 영역. 게임 로직 기준 화면 크기. `g_FBWidth/Height`와 동일 |
| `g_ScrollBuffXLen` × `g_ScrollBuffYLen` | 1280×896 | `g_ViewWidth+256` × `g_ViewHeight+128` | 순환버퍼 GPU 텍스처(`CTileRenderer::pSRV`). 뷰 + 타일 2개 여유분. WRAP 샘플링. **타일(지면)만 포함** → 물 굴절 소스로 직접 사용 |
| `RenderWidth` × `RenderHeight` | 1600×900 | render.ini 직접 읽음 | 최종 출력 해상도. 뷰를 이 크기로 스트레칭하여 화면 출력 |

**흐름:**
```
render.ini Original(1024×768) → g_ViewWidth × g_ViewHeight 계산
  → 순환버퍼(g_ScrollBuff*) 에 타일 렌더
    → 뷰 영역 추출
      → RenderWidth × RenderHeight 로 스트레칭
        → 최종 출력
```

> 순환버퍼는 건물·캐릭터를 포함하지 않으므로, 물 굴절 시 별도 RT 복사 없이 `CTileRenderer::pSRV`를 직접 바인딩한다 (RT_PrevScene 불필요).

---

## 1. x64 전환 (~2.5일)

> 게임 클라이언트(GcX.exe)만 x64 전환. RESTools는 Win32 유지.

---

### 1-1. vcxproj x64 플랫폼 추가 (~2h)

**대상 파일:** `GodiusClient/GcX.vcxproj`

**현재 상태:**
- `Debug|Win32`, `Release|Win32` 2개 구성만 존재
- Release 출력: `.\ReleaseX\`, Debug 출력: `.\DebugX\`

**작업 내용:**

1. `<ItemGroup Label="ProjectConfigurations">`에 x64 구성 2개 추가:
   ```xml
   <ProjectConfiguration Include="Debug|x64">
     <Configuration>Debug</Configuration>
     <Platform>x64</Platform>
   </ProjectConfiguration>
   <ProjectConfiguration Include="Release|x64">
     <Configuration>Release</Configuration>
     <Platform>x64</Platform>
   </ProjectConfiguration>
   ```

2. x64 Configuration 속성 추가 (Win32와 동일, PlatformToolset=v143):
   ```xml
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <PlatformToolset>v143</PlatformToolset>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
   </PropertyGroup>
   ```
   Release|x64도 동일하게 추가.

3. x64 출력/중간 디렉토리 분리:
   - Debug|x64: `.\DebugX64\`
   - Release|x64: `.\ReleaseX64\`

4. x64 PropertySheets 추가 (Win32와 동일 구조, Platform만 x64)

5. x64 `<ItemDefinitionGroup>` 추가 — Win32 설정을 복사 후 아래 변경:
   - `<TargetEnvironment>` 제거 (Midl 섹션)
   - `<TargetMachine>MachineX64</TargetMachine>` (Link 섹션)
   - `/MACHINE:I386` 제거 (Debug Link AdditionalOptions)
   - `<ImageHasSafeExceptionHandlers>` 제거 (x64에서 불필요)
   - `WIN32` 전처리기 → 그대로 유지 (호환성, 많은 Win32 프로젝트가 x64에서도 WIN32 유지)

**검증:**
- [ ] VS2022에서 솔루션 열기 → 구성 관리자에서 Debug|x64, Release|x64 선택 가능 확인
- [ ] Debug|x64 빌드 시도 → 링크 에러 나올 수 있음 (MSSDK7 32비트 라이브러리), 이는 다음 단계에서 해결

---

### 1-2. MSSDK7 참조 제거 + 레거시 라이브러리 정리

**대상 파일:** `GodiusClient/GcX.vcxproj`

**현재 상태 (Release|Win32 기준):**
```xml
<AdditionalIncludeDirectories>$(ProjectDir)..\MSSDK7\include;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
<AdditionalLibraryDirectories>$(ProjectDir)..\MSSDK7\lib;%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>
<AdditionalDependencies>ws2_32.lib;d3d11.lib;dxgi.lib;d3dcompiler.lib;imm32.lib;winmm.lib;dinput.lib;dxguid.lib;dsound.lib;version.lib;odbc32.lib;odbccp32.lib;%(AdditionalDependencies)</AdditionalDependencies>
```
Debug|Win32도 동일한 구조.

**작업 내용:**

1. **x64 구성에서 MSSDK7 경로 제거** (AdditionalIncludeDirectories, AdditionalLibraryDirectories)
   - x64 구성에는 MSSDK7 경로를 처음부터 넣지 않는다

2. **x64 구성에서 레거시 라이브러리 제거:**
   - `dinput.lib` — DirectInput 제거 완료, 불필요
   - `dsound.lib` — DirectSound 제거 예정 (1-3에서 XAudio2 교체 후)
   - `dxguid.lib` — DirectInput/DirectSound GUID용이었으므로 제거. 필요한 GUID가 있으면 Windows SDK의 dxguid.lib 사용

3. **x64 AdditionalDependencies 최종:**
   ```
   ws2_32.lib;d3d11.lib;dxgi.lib;d3dcompiler.lib;imm32.lib;winmm.lib;version.lib;odbc32.lib;odbccp32.lib;xaudio2.lib;%(AdditionalDependencies)
   ```
   > 참고: XAudio2는 Windows 10에서 xaudio2.lib 없이 `#include <xaudio2.h>`만으로 사용 가능 (COM 인터페이스). xaudio2.lib가 필요하면 추가.

4. **Win32 구성은 당분간 유지** — 기존 빌드 깨지지 않도록. 최종 전환 완료 후 Win32 구성 제거 검토.

**검증:**
- [ ] x64 구성에서 MSSDK7 경로가 없는 상태로 빌드 시도 (dsound/dinput 관련 헤더 에러는 1-3에서 해결)

---

### 1-3. DirectSound / DirectMusic 제거 → XAudio2 통일 (~1일)

> 이 작업이 64비트 전환의 핵심이자 가장 큰 작업.

#### 1-3-1. DSWave 현재 구조 분석

**현재 API (DSWave.h):**
```cpp
// 구조체
struct sWAVE { DWORD size; BYTE* data; WAVEFORMATEX format; LPDIRECTSOUNDBUFFER device; };
struct sDIRSOUND { HWND hwnd; LPDIRECTSOUND device; };

// 전역 변수
extern sWAVE gWAVE[dWAVE_MAX + dMON_MAX_CNT];
extern sDIRSOUND gDS;

// 공개 함수
BOOL CreateDIRSOUND(HWND hwnd);        // DirectSound 초기화
void ReleaseDIRSOUND(void);             // DirectSound 해제
int  LoadWave(int waveIdx, char *filename);  // WAV 로드
void UnLoadWave(int channel);           // WAV 해제
BOOL PlayWave(int waveIdx, BOOL looping, BOOL bOnSkip = FALSE);  // 재생
BOOL StopWave(int waveIdx);             // 정지
BOOL IsSoundPlaying(int waveIdx);       // 재생 중 확인
void LoadWaveFile(void);                // 전체 WAV 로드
void UnLoadWaveFile(void);              // 전체 WAV 해제
```

**WAV 파일 정보:**
- 393개 효과음, `.\Sound\EFF####.wav` 형식
- PCM, 22050Hz, 8-bit, mono
- 총 ~16MB

#### 1-3-2. DmidiPlay 현재 구조 분석

**현재 상태:** `#define MCI_MIDI_SOUND`가 정의되어 **이미 MCI API로 MIDI 재생 중**. DirectMusic 코드는 조건부 컴파일로 비활성화됨.

**현재 API (DmidiPlay.h):**
```cpp
// 주요 함수 (MCI_MIDI_SOUND 활성 시 실제 사용)
DWORD AttemptFileOpen(char *openName);   // MIDI 파일 열기
DWORD PlaySegment(void);                 // 재생
DWORD RePlaySegment(void);              // 일시정지 후 재개
DWORD PauseSegment(void);              // 일시정지
void  StopSegment(void);                // 정지
BOOL  InitDirectMusic(void);            // 초기화 (MCI 모드에서는 간소화)
void  UnInitDirectMusic(void);           // 해제
```

**MIDI 파일 정보:**
- 18곡: East1.mid ~ East18.mid
- 합계 189KB

#### 1-3-3. XAudio2 교체 작업 순서

**Step 1: XAudio2 오디오 엔진 클래스 작성**

**신규 파일:** `GodiusClient/AudioEngine.h`, `GodiusClient/AudioEngine.cpp`

```cpp
// AudioEngine.h — XAudio2 기반 통합 오디오 엔진
#pragma once
#include <xaudio2.h>
#include <windows.h>

#define AUDIO_MAX_SOUNDS  (dWAVE_MAX + dMON_MAX_CNT)
#define AUDIO_MAX_BGM     4  // 동시 BGM 버퍼 (크로스페이드용)

struct AudioSound {
    BYTE*           data;       // PCM 데이터
    DWORD           size;       // 데이터 크기
    WAVEFORMATEX    format;     // WAV 포맷
    IXAudio2SourceVoice* voice; // XAudio2 소스 보이스
    bool            playing;
};

struct AudioBGM {
    BYTE*           data;
    DWORD           size;
    WAVEFORMATEX    format;
    IXAudio2SourceVoice* voice;
    bool            playing;
    char            filename[MAX_PATH];
};

class AudioEngine {
public:
    BOOL Initialize(HWND hwnd);
    void Shutdown();

    // 효과음 (기존 DSWave API 1:1 대응)
    int  LoadSound(int idx, const char* filename);
    void UnloadSound(int idx);
    BOOL PlaySound(int idx, BOOL looping, BOOL bOnSkip = FALSE);
    BOOL StopSound(int idx);
    BOOL IsSoundPlaying(int idx);
    void LoadAllSounds();
    void UnloadAllSounds();

    // 배경음악 (기존 DmidiPlay API 1:1 대응)
    BOOL OpenBGM(const char* filename);
    BOOL PlayBGM();
    BOOL StopBGM();
    BOOL PauseBGM();
    BOOL ResumeBGM();

private:
    IXAudio2*               m_pXAudio2;
    IXAudio2MasteringVoice* m_pMasterVoice;
    AudioSound              m_sounds[AUDIO_MAX_SOUNDS];
    AudioBGM                m_bgm;

    BOOL LoadWavFile(const char* filename, BYTE** outData, DWORD* outSize, WAVEFORMATEX* outFormat);
    BOOL LoadOggFile(const char* filename, BYTE** outData, DWORD* outSize, WAVEFORMATEX* outFormat);
};

extern AudioEngine gAudioEngine;
```

> OGG 디코딩: `stb_vorbis.c` (헤더 하나) 사용 권장. MIT 라이선스.

**Step 2: 기존 DSWave 호출부 교체**

프로젝트 전체에서 기존 함수 호출을 새 API로 교체:

| 기존 호출 | 교체 |
|-----------|------|
| `CreateDIRSOUND(hwnd)` | `gAudioEngine.Initialize(hwnd)` |
| `ReleaseDIRSOUND()` | `gAudioEngine.Shutdown()` |
| `LoadWave(idx, file)` | `gAudioEngine.LoadSound(idx, file)` |
| `UnLoadWave(idx)` | `gAudioEngine.UnloadSound(idx)` |
| `PlayWave(idx, loop, skip)` | `gAudioEngine.PlaySound(idx, loop, skip)` |
| `StopWave(idx)` | `gAudioEngine.StopSound(idx)` |
| `IsSoundPlaying(idx)` | `gAudioEngine.IsSoundPlaying(idx)` |
| `LoadWaveFile()` | `gAudioEngine.LoadAllSounds()` |
| `UnLoadWaveFile()` | `gAudioEngine.UnloadAllSounds()` |

**호출부 파일 목록** (grep으로 확인 필요):
- `Winmain.cpp` — CreateDIRSOUND, ReleaseDIRSOUND, LoadWaveFile, UnLoadWaveFile
- `GamePlay.cpp` — PlayWave 다수
- `Effect.cpp` — PlayWave
- `Magic.cpp` — PlayWave
- `Player.cpp` — PlayWave
- `mons.cpp` — PlayWave
- `Item.cpp` — PlayWave
- 기타 전투/UI 관련 파일

**Step 3: 기존 DmidiPlay 호출부 교체**

| 기존 호출 | 교체 |
|-----------|------|
| `InitDirectMusic()` | `gAudioEngine.Initialize(hwnd)`에 통합 (이미 초기화) |
| `UnInitDirectMusic()` | `gAudioEngine.Shutdown()`에 통합 |
| `AttemptFileOpen(name)` | `gAudioEngine.OpenBGM(name)` |
| `PlaySegment()` | `gAudioEngine.PlayBGM()` |
| `RePlaySegment()` | `gAudioEngine.ResumeBGM()` |
| `PauseSegment()` | `gAudioEngine.PauseBGM()` |
| `StopSegment()` | `gAudioEngine.StopBGM()` |

**Step 4: MIDI → OGG 사전 변환**

- 18곡 (East1~18.mid) → East1~18.ogg로 변환
- 변환 도구: `timidity` + `ffmpeg` 또는 온라인 변환
- 품질: 128kbps OGG Vorbis
- 예상 용량: 곡당 0.3~1.5MB, 총 5~20MB
- 파일 위치: `.\Sound\East1.ogg` ~ `.\Sound\East18.ogg`
- `OpenBGM()` 내부에서 확장자로 WAV/OGG 분기

**Step 5: 레거시 파일 제거/비활성화**

- `DSWave.h` / `DSWave.cpp` → vcxproj에서 제거 (또는 주석 처리)
- `DmidiPlay.h` / `DmidiPlay.cpp` → vcxproj에서 제거
- `#include <dsound.h>` 제거
- `#include <dmusici.h>`, `#include <dmusicc.h>` 제거
- vcxproj AdditionalDependencies에서 `dsound.lib`, `dinput.lib`, `dxguid.lib` 제거

**Step 6: vcxproj에 신규 파일 추가**

- `AudioEngine.h`, `AudioEngine.cpp` 추가
- OGG 디코딩용 `stb_vorbis.c` 추가 (또는 헤더 인클루드)

**검증:**
- [ ] x64 Debug 빌드 성공 (dsound.h, dmusici.h 참조 없음)
- [ ] 게임 실행 → 효과음 재생 확인 (아무 WAV 효과음)
- [ ] 게임 실행 → 배경음악 재생 확인 (OGG 파일)
- [ ] 볼륨/루프/정지 동작 확인
- [ ] Win32 빌드도 동일하게 동작 확인 (XAudio2는 32/64 모두 지원)

---

### 1-4. GameGuard 제거 정리 (~1h)

**현재 상태:**
- `Winmain.cpp:83`에 `#define NO_GAMEGUARD` **이미 정의됨**
- GameGuard 코드는 `#ifndef NO_GAMEGUARD`로 이미 비활성화 상태
- `GameGuard/` 디렉토리 존재 (~23MB, 20개 파일)
- `LangK.cpp`에 NPGameLibMsg 배열과 NPGameLibMsgFunc() 존재

**작업 내용:**

1. **GameGuard 디렉토리 삭제:**
   - `GodiusClient/GameGuard/` 전체 삭제 (GameGuard.des, GameMon.des 등 ~23MB)

2. **NO_GAMEGUARD 관련 데드 코드 정리** (선택적, 시간 여유 시):
   - `Winmain.cpp`: `#ifndef NO_GAMEGUARD` 블록 내부 코드 삭제 가능
   - `LangK.cpp`: NPGameLibMsgFunc(), NPGameLibMsg[] 삭제 가능
   - 단, 지금은 전처리기로 이미 비활성화되어 있으므로 **기능상 영향 없음**
   - 코드 정리는 Phase C (버그 수정/정리)에서 병행 가능

3. **vcxproj 확인:**
   - NPGameLib 관련 .lib 참조가 없는지 확인 (현재 없음 — 이미 `#pragma comment(lib, ...)` 방식이었고 NO_GAMEGUARD로 비활성화)

**검증:**
- [ ] GameGuard 디렉토리 삭제 후 x64 빌드 성공
- [ ] 게임 실행 시 GameGuard 관련 에러 없음

---

### 1-5. CharBind.dll 제거 + Char.dat 폐기 전략 (~2h)

**현재 상태:**

`CharBind.dll` (28KB, 소스 없음):
```cpp
// Winmain.cpp:717~735
hLib = LoadLibrary("CharBind.dll");
if (hLib) {
    f = GetProcAddress(hLib, "UpdateCharBind");
    updateCharBind = (UpdateCharBind)f;
    gLOAD_SPR = updateCharBind();  // BOOL 반환, TRUE여야 캐릭터 SPR 로딩 진행
    FreeLibrary(hLib);
}
```

`Char.dat` / `Char.Off` 구조:
- `Char.Off` (637KB) — 인덱스: `sFileBind` 구조체 × 22,487개 (fileName[21] + fileOffset + fileSize)
- `Char.dat` (391MB) — **캐릭터 부위별 SPR 22,487개를 하나로 패킹한 아카이브** (비압축)
- 파일명 패턴: `B{sex}{armor}{color}{action}.SPR` (몸통), `H{...}.SPR` (머리), `L{...}.SPR` (다리), `W{...}.SPR` (무기) 등
- 개별 SPR 파일과 **중복 없음** — `Char/` 디렉토리는 비어있고 Char.dat만 존재
- `Sprite.cpp`의 `InitCharBind()`/`CharBindFileRead()`로 인덱스 검색 → seek → 로드

RESTools 관련:
- `MapDoc.cpp`에서 Char.dat **읽기만** 함 (몬스터 SPR 프리뷰용)
- RESTools C++ 코드에 Char.dat **생성 기능 없음** — CharBind.dll 또는 별도 외부 도구가 패킹 담당
- Character Editor는 부위별 개별 SPR을 생성하는 도구 (Char.dat 패킹은 별도)

**폐기 근거:**
- SPR→SPR2 전환 후, 부위별 SPR2를 GPU에서 실시간 합성 + 캐싱하면 **사전 패킹된 Char.dat 불필요**
- 현재 매 프레임 부위별 DrawClipping × 4~5회 → SPR2 GPU 합성 후 캐시 텍스쳐 1회 DrawCall로 개선
- 현재 22,487개 SPR은 액션(8종)별로 개별 파일 → SPR2 멀티프레임으로 통합 시 **~1,500개**로 감소
- 391MB 비압축 → **~15-30MB** (BC7 압축, 부위별 멀티프레임 SPR2)
- CharBind.dll 소스 없음 → DLL 의존성 제거 필요

**용량 비교:**

| 방식 | 파일 수 | 예상 용량 |
|------|---------|-----------|
| 현재 Char.dat | 22,487 SPR (액션별 개별) | 391MB (비압축) |
| **SPR2 (부위별 멀티프레임)** | **~1,500 SPR2** | **~15-30MB (BC7)** |

**작업 내용:**

1. **CharBind.dll 제거 — ✅ 완료:**
   - `Winmain.cpp:716~756` LoadLibrary/GetProcAddress/FreeLibrary 블록 전체 제거
   - `gLOAD_SPR = InitCharBind()` 직접 호출로 변경 (DLL 경유 제거)
   - `CharBind.dll` 파일 삭제 예정 (바이너리만 남아있음, 소스 없음)
   - 검증: Debug 빌드 + `render.ini bOnline=0` 오프라인 모드에서 정상 동작 확인

2. **Char.dat 유지 → SPR2 전환 완료 후 폐기 (Phase 5):**
   - 당장은 InitCharBind() / CharBindFileRead() 유지 (기존 SPR 로딩 경로)
   - SPR2 전환 완료 시점에 Char.dat에서 22,487개 SPR 추출 → 동일 부위 액션별 SPR을 1개 멀티프레임 SPR2로 통합 (~1,500개)
   - 변환 완료 후 Char.dat, Char.Off, InitCharBind(), EndCharBind(), CharBindFileRead() 코드 전부 제거
   - `LoadCharData()` → 개별 SPR2 파일에서 직접 로드 + GPU 합성 캐시로 전환

3. **RESTools MapDoc.cpp Char.dat 읽기 제거 (Phase 5):**
   - 몬스터 SPR 프리뷰를 개별 SPR2 파일에서 직접 로드하도록 변경

**검증:**
- [x] CharBind.dll 제거 후 `gLOAD_SPR = InitCharBind()`로 캐릭터 SPR 정상 로딩 확인 (Debug + bOnline=0 오프라인 모드)
- [ ] x64 빌드에서 DLL 관련 에러 없음
- [ ] (Phase 5) Char.dat 삭제 후 ~1,500개 부위별 SPR2에서 캐릭터 정상 렌더링 확인

---

### 1-6. 커스텀 PE 로더 64비트 수정 또는 제거 (~2h)

**현재 상태:**
- `Dll.h` / `Dll.cpp` — CDLL 클래스, 커스텀 PE 로더
- **핵심 64비트 버그: RVATOVA 매크로**
  ```cpp
  #define RVATOVA(base,offset) ((LPVOID)((DWORD)(base) + (DWORD)(offset)))
  #define VATORVA(base,offset) ((LPVOID)((DWORD)(offset) - (DWORD)(base)))
  ```
  → 포인터를 DWORD(32비트)로 캐스팅하여 상위 32비트 손실

- `Dll.cpp` 전체에 DWORD↔포인터 캐스팅 ~20곳 이상

**판단: 사용 여부 확인**
- CDLL 클래스가 실제로 어디서 사용되는지 확인 필요
- CharBind.dll 로딩은 표준 `LoadLibrary`/`GetProcAddress` 사용 (CDLL 미사용)
- CDLL이 사용되지 않으면 → **제거가 최선**

**작업 내용 (사용 안 하는 경우):**
1. `Dll.h`, `Dll.cpp`를 vcxproj에서 제거
2. `#include "Dll.h"` 참조 제거

**작업 내용 (사용하는 경우):**
1. RVATOVA/VATORVA 매크로 수정:
   ```cpp
   #define RVATOVA(base,offset) ((LPVOID)((ULONG_PTR)(base) + (DWORD)(offset)))
   #define VATORVA(base,offset) ((LPVOID)((ULONG_PTR)(offset) - (ULONG_PTR)(base)))
   ```
2. `Dll.cpp` 전체 DWORD→ULONG_PTR 교체 (~20곳)
3. `IMAGE_OPTIONAL_HEADER` → 플랫폼별 분기:
   ```cpp
   #ifdef _WIN64
   #define SECHDROFFSET(ptr) ((LPVOID)((BYTE*)(ptr)+...+sizeof(IMAGE_OPTIONAL_HEADER64)))
   #else
   #define SECHDROFFSET(ptr) ((LPVOID)((BYTE*)(ptr)+...+sizeof(IMAGE_OPTIONAL_HEADER32)))
   #endif
   ```
4. 릴로케이션 처리에서 `IMAGE_REL_BASED_DIR64` 타입 추가

**검증:**
- [ ] CDLL 사용처 grep → 사용 안 하면 제거 후 빌드 성공 확인
- [ ] 사용하면 수정 후 x64 빌드 + 실행 확인

---

### 1-7. AES 암호화 모듈 64비트 점검 (~30m)

**현재 상태 (AES.h/AES.cpp):**
- 자체 AES-128 CBC 구현
- 키: `"20190819abcdefgh"`, IV: `"20190819ABCDEFGH"` (하드코딩)
- DWORD를 길이 파라미터로 사용 — 포인터가 아니므로 64비트 문제 없음
- `BYTE*` 포인터 연산 — 정상

**작업 내용:**

1. **점검 항목:**
   - `AES_CBC_encrypt_buffer(BYTE* buf, DWORD length)` — DWORD length는 OK (4GB 제한이지만 패킷 크기에 충분)
   - `memcpy(g_SendDataEncrypt, &iBlockSize, sizeof(int))` — int 크기는 32/64비트 모두 4바이트, OK
   - `(int)*((int*)g_RecvDataDecrypt)` — 정렬 이슈 가능성 있으나 실제 문제 없음

2. **결론: 수정 불필요**
   - AES 모듈은 고정 크기 타입(BYTE, DWORD, int)만 사용
   - 포인터를 정수로 캐스팅하는 코드 없음
   - 보안 개선(키 하드코딩 문제)은 후순위

**검증:**
- [ ] x64 빌드 후 로그인 서버 접속 → AES 암호화 통신 정상 확인

---

### 1-8. 코드 레벨 64비트 호환성 수정 (~2h)

#### 1-8-1. SetWindowLong → SetWindowLongPtr

**대상:** `Hangul.cpp:87`

**현재:**
```cpp
MainProc = (WNDPROC)SetWindowLong(editWin, GWL_WNDPROC, (LONG)EditWinProc);
```

**수정:**
```cpp
MainProc = (WNDPROC)SetWindowLongPtr(editWin, GWLP_WNDPROC, (LONG_PTR)EditWinProc);
```

#### 1-8-2. DirectMouse.h 레거시 선언 정리

**현재:** `DirectMouse.h`에 `IDirectInput*`, `IDirectInputDevice*` 멤버 변수 선언 남아있음 (코드는 `#if 0`으로 비활성화)

**작업:**
- DirectInput 관련 헤더 참조 제거: `#include <dinput.h>` 제거
- 비활성화된 멤버 변수 제거 또는 조건부 컴파일

#### 1-8-3. time(NULL) → DWORD 캐스팅 (~99곳)

**현재:** `(DWORD)time(NULL)` 패턴 ~99곳

**판단:** time_t는 64비트에서 8바이트이지만, DWORD(4바이트)로 잘려도 2038년까지 유효. 게임 로직에서 시간차 계산용이므로 **당장 수정 불필요**. Phase C에서 정리 가능.

#### 1-8-4. DWORD↔포인터 캐스팅 전체 검색

**검색 패턴:** `(DWORD)` 캐스팅 중 포인터 변수를 대상으로 하는 것

**확인된 주요 이슈:**
- `Dll.cpp` — 1-6에서 처리
- `DIBMem.cpp:58` — `(DWORD)NULL` → `0`으로 교체 (사소)
- `Winmain.h` MAKEDWORD/HIGHWORD 매크로 — 포인터에 사용하지 않으면 OK

**검증:**
- [ ] x64 빌드 시 포인터 절삭 경고(C4311, C4312) 0건 확인
- [ ] Warning Level 4로 빌드하여 추가 경고 확인

---

### 1-9. 최종 x64 빌드 검증

**전체 검증 체크리스트:**
- [ ] Debug|x64 빌드 성공 (에러 0, 경고 최소화)
- [ ] Release|x64 빌드 성공
- [ ] GcX.exe (x64) 실행 → 윈도우 생성 확인
- [ ] 효과음 재생 (XAudio2)
- [ ] 배경음악 재생 (OGG via XAudio2)
- [ ] 로그인 서버 접속 (AES 암호화 통신)
- [ ] 게임 진입 → 맵 로딩 → 스프라이트 표시
- [ ] 기존 Win32 빌드도 여전히 동작 확인


---
---

## 2. SPR2 + 라이트맵/밤낮 + 렌더 기반 + 에디터 모드

> 비주얼 기반 인프라 구축. 이후 모든 렌더링 개선의 토대.

---

### 2-1. 렌더 파이프라인 확장 기반 (Rendering Step 1)

#### 2-1-1. 렌더 타겟 관리자

**신규 파일:** `GodiusClient/RenderTargetManager.h`, `RenderTargetManager.cpp`

**작업 내용:**
1. `RenderTargetManager` 클래스 설계:
   - 이름 기반 RT 생성/해제/바인딩 (`CreateRT(name, width, height, format)`, `GetRT(name)`, `SetRT(name)`)
   - 내부에 `std::unordered_map<std::string, RT_Resource>` 관리

2. 필수 RT 생성:
   - `RT_Scene` — 씬 렌더링용 (render.ini 해상도)
   - `RT_LightMap` — 라이트맵용 (1/2 또는 1/4 해상도, `DXGI_FORMAT_R8G8B8A8_UNORM`, `D3D11_USAGE_DYNAMIC`)
   - ~~`RT_PrevScene`~~ — **불필요**: 물 굴절은 순환버퍼 SRV 직접 참조 (해상도 체계 개념 정리 참조)
   - `RT_PostA`, `RT_PostB` — 후처리 핑퐁 RT 2장

3. 유틸 함수:
   - `SetRenderTarget(name)` — 지정 RT를 현재 렌더 타겟으로 설정
   - `RestoreBackBuffer()` — 백버퍼 복원
   - `CopyRT(src, dst)` — RT 간 복사

**검증:**
- [ ] RT 생성 → 특정 색상으로 클리어 → 백버퍼에 출력 → 색상 확인

#### 2-1-2. 셰이더 관리 시스템

**신규 파일:** `GodiusClient/ShaderManager.h`, `ShaderManager.cpp`
**신규 디렉토리:** `GodiusClient/Shaders/`

**작업 내용:**
1. `ShaderManager` 클래스:
   - VS/PS 로드 (`LoadShader(name, vsFile, psFile)`)
   - 캐싱 (동일 셰이더 재로드 방지)
   - 디버그 모드: 핫리로드 (파일 변경 감지 → 재컴파일)

2. 기본 셰이더 세트:
   - `PassThrough.hlsl` — 기존 스프라이트 렌더용 (입력 그대로 출력)
   - `FullscreenQuad.hlsl` — 후처리 패스용 풀스크린 쿼드

3. 공통 상수 버퍼 구조 정의:
   ```hlsl
   // Common.hlsli
   cbuffer PerFrame : register(b0) {
       float  time;
       float2 screenSize;
       float2 cameraOffset;
       float  padding[3];
   };
   ```

4. 셰이더 컴파일:
   - 런타임 `D3DCompile()` 사용 (빌드 스텝 불필요)
   - Release에서는 `.cso` 프리컴파일 검토 (후순위)

**검증:**
- [ ] 커스텀 셰이더로 화면 전체 세피아 톤 적용 → 정상 출력 확인

#### 2-1-3. 블렌드 스테이트 세트

**대상 파일:** `D3DRenderer.h/cpp` 또는 신규 `BlendStates.h/cpp`

**작업 내용:**
1. 알파 블렌딩: `SrcAlpha × InvSrcAlpha` (기본 반투명)
2. 가산 블렌딩: `SrcAlpha × One` (이펙트, 라이트 합성)
3. 곱셈 블렌딩: `DestColor × Zero` (라이트맵 합성)
4. 블렌드 스테이트 전환 API: `SetBlendMode(BlendMode mode)`

**검증:**
- [ ] 반투명 쿼드 + 가산 쿼드를 화면에 올려 블렌딩 동작 확인

---

### 2-2. SPR2 True Color 포맷 구현 (E-2)

> RESTools(Win32)와 클라이언트(x64) 양쪽에서 SPR2를 지원한다.
> 상세 포맷은 RESTools.md 참조.

#### 2-2-1. RESTools 측 — CDib32 신규 클래스

**대상 프로젝트:** `RESTools (EF.vcxproj)` — Win32 유지

**신규 파일:** `EF/Dib32.h`, `EF/Dib32.cpp`

**작업 내용:**
1. `CDib32` 클래스 작성:
   - 32bit ARGB 버퍼 관리
   - `Create(width, height)` — ARGB 버퍼 할당
   - `GetPixel(x, y)` / `SetPixel(x, y, argb)`
   - `AlphaBlit(src, dstX, dstY)` — 알파 합성
   - `StretchDIBits()` 기반 화면 표시
   - PNG 로딩: `stb_image.h` 사용 → RGBA → ARGB 변환

2. 기존 `CDib`(8bit)는 **수정 없이 유지**

**검증:**
- [ ] PNG 파일 로드 → CDib32 생성 → MFC View에 표시

#### 2-2-2. RESTools 측 — CSprite2 클래스 (SPR2 R/W)

**신규 파일:** `EF/Sprite2.h`, `EF/Sprite2.cpp`

**작업 내용:**
1. `CSprite2` 클래스 작성:
   - SPR2 파일 포맷 읽기/쓰기 (RESTools.md 참조)
   - BC7 압축: DirectXTex 라이브러리 활용 (이미 SPRToDDS에서 NuGet 사용)
   - ARGB8888 비압축 포맷 지원 (BC Format = 0xFF, 라이팅 스탬프용)
   - 프레임별 Origin(원점) 관리
   - CDib32 ↔ SPR2 프레임 변환

2. SPR2 파일 포맷 구현 (고정 크기 타입, 32/64비트 무관):
   ```
   Header: "SPR2" + Version(uint32) + FrameCount(uint32) + BCFormat(uint32) + Flags(uint32) + ...
   Frame Table: DataOffset(uint32) + DataSize(uint32) + Width(uint16) + Height(uint16) + OriginX(int16) + OriginY(int16) + ...
   Frame Data: BC7 블록 또는 ARGB8888 원본
   ```

**검증:**
- [ ] PNG → CDib32 → BC7 압축 → SPR2 저장 → SPR2 로드 → CDib32 → 화면 표시 → 원본 PNG와 비교

#### 2-2-3. RESTools 측 — Sprite Editor 개선

**대상 파일:** `EF/SprDoc.cpp`, `EF/SprMainView.cpp`

**작업 내용:**
1. 소스 로딩 확장: PCX + PNG 모두 지원 (파일 다이얼로그 필터 추가)
2. PNG → CDib32 경로, PCX → 기존 CDib 경로 분기
3. SPR2 저장: 프레임 선택 → BC7/ARGB8888 압축 → .spr2 저장
4. SPR2 로딩: .spr2 파일 열기 → 프레임 편집

**검증:**
- [ ] Sprite Editor에서 PNG 소스 로드 → 영역 선택 → SPR2 저장 → 다시 열기 → 프레임 확인

#### 2-2-4. RESTools 측 — FGP v2 (sizeof(LPBYTE) 버그 수정)

**대상 파일:** `EF/FieldSprite.h`, `EF/FieldSprite.cpp`

**현재 버그:**
```cpp
fread(&location, sizeof(LPBYTE), 1, fp);  // 32bit=4바이트, 64bit=8바이트
```

**작업 내용:**
1. FGP v2 포맷: `sizeof(LPBYTE)` → `sizeof(uint32_t)` 고정 크기로 변경
2. .spr/.spr2 양쪽 참조 지원
3. FGP v1 하위 호환 읽기 유지

**검증:**
- [ ] FGP v2 저장 → 로드 → 오브젝트 위치/스프라이트 정상 확인
- [ ] 기존 FGP v1 파일 로드 정상 확인

#### 2-2-5. 클라이언트 측 — SPR2 로더 + 듀얼 포맷

**대상 파일:** `GodiusClient/Sprite.cpp` (기존), 신규 `GodiusClient/Sprite2.h/cpp` (클라이언트용 SPR2 로더)

**작업 내용:**
1. 클라이언트용 SPR2 로더:
   - BC7 데이터 → `ID3D11Texture2D` 직접 생성 (`DXGI_FORMAT_BC7_UNORM`, `D3D11_USAGE_IMMUTABLE`)
   - ARGB8888 데이터 → `DXGI_FORMAT_B8G8R8A8_UNORM` 텍스쳐 생성
   - CPU 디코딩 불필요 (GPU 네이티브)
   - 프레임별 SRV 생성 및 캐싱

2. 듀얼 포맷 지원:
   - 파일 확장자 또는 매직 넘버로 SPR/SPR2 분기
   - SPR: 기존 파이프라인 (RLE → 팔레트 → DYNAMIC 텍스쳐)
   - SPR2: 신규 파이프라인 (IMMUTABLE 텍스쳐 → SRV 바인딩)

3. SPR2 블렌딩 모드:
   - Flags 필드에서 블렌딩 스타일 읽기 → BlendState 전환

**검증:**
- [ ] SPR2 파일 로드 → 화면에 렌더링 → 원본 SPR과 비교
- [ ] SPR과 SPR2 혼합 맵에서 정상 렌더링 확인
- [ ] ARGB8888 포맷 SPR2 (라이팅 스탬프) 로드 → 텍스쳐 생성 확인

---

### 2-3. 인게임 에디터 모드 (E-3 / Rendering Step 0)

#### 2-3-1. -editor 커맨드라인 모드

**대상 파일:** `GodiusClient/Winmain.cpp`

**작업 내용:**
1. `WinMain()`에서 커맨드라인 파싱:
   ```cpp
   bool g_bEditorMode = false;
   char g_editorMap[64] = {0};
   int  g_editorPosX = 0, g_editorPosY = 0;

   // 커맨드라인 파싱
   if (strstr(lpCmdLine, "-editor")) g_bEditorMode = true;
   // -map <name> -pos <x,y> 파싱
   ```

2. 에디터 모드 동작:
   - 서버 접속 스킵 (오프라인)
   - 지정 맵 바로 로드
   - 자유 카메라 이동

3. 핫리로드: `'R'` 키 → `.lgt`, `.cfg`, `.map` 등 현재 맵 데이터 재로드

**검증:**
- [ ] `GcX.exe -editor -map 마을` 실행 → 서버 접속 없이 맵 로드 확인

#### 2-3-2. ImGui 통합

**신규 파일:** `GodiusClient/EditorUI.h`, `GodiusClient/EditorUI.cpp`
**외부 의존:** ImGui docking 브랜치 (git submodule 또는 소스 복사)

**작업 내용:**
1. ImGui docking 브랜치 도입 (`imgui_impl_win32.h/cpp`, `imgui_impl_dx11.h/cpp`)
2. Multi-Viewport 활성화: `ImGuiConfigFlags_ViewportsEnable`
3. `-editor` 모드에서만 ImGui 초기화 (일반 유저 무영향)
4. 에디터 패널 프레임워크:
   - 패널 등록/활성화/비활성화
   - 레이아웃 저장/복원 (`imgui.ini`)

**검증:**
- [ ] `-editor` 모드 → ImGui Demo Window 표시 확인
- [ ] Multi-Viewport → ImGui 창을 게임 윈도우 밖으로 드래그 → OS 독립 창 확인
- [ ] 일반 모드(에디터 플래그 없이) → ImGui 없음 확인

---

### 2-4. 라이트맵 시스템 (Rendering Step 2)

#### 2-4-1. 라이트맵 기본 구조

**신규 파일:** `GodiusClient/LightMap.h`, `LightMap.cpp`

**작업 내용:**
1. `LightMap` 클래스:
   - CPU 측 ARGB 버퍼 (render.ini 기준 1/4 해상도)
   - 매 프레임 앰비언트 컬러로 초기화

2. SPR2 기반 광원 스탬프:
   - SPR2 ARGB8888 리소스를 라이트맵 버퍼에 가산 블렌딩
   - 광원 위치, 색상, 스케일, 강도 적용

3. GPU 업로드: `Map/Unmap`으로 `RT_LightMap`에 전송

4. 합성 셰이더 `PS_LightMap`:
   ```hlsl
   float4 PS_LightMap(VS_OUTPUT input) : SV_Target {
       float4 sceneColor = sceneTexture.Sample(sampler, input.uv);
       float4 lightColor = lightMapTexture.Sample(sampler, input.uv);
       return sceneColor * lightColor;  // Multiply 블렌딩
   }
   ```

**검증:**
- [ ] 앰비언트를 어두운 색(0.3, 0.3, 0.5)으로 설정 → 화면 전체 어두워짐 확인
- [ ] 마우스 위치에 테스트 광원 배치 → 밝은 원형 영역 확인
- [ ] 바이리니어 샘플링으로 경계가 자연스러운지 확인

#### 2-4-2. 광원 매니저

**신규 파일:** `GodiusClient/LightManager.h`, `LightManager.cpp`

**작업 내용:**
1. `LightInstance` 구조체:
   ```cpp
   struct LightInstance {
       float2 position;
       char   spr2Name[64];
       int    frameIndex;
       DWORD  color;        // ARGB
       float  scale;
       float  intensity;
       float  lifetime;     // 이벤트 라이트용
       float  timeOfDayStart, timeOfDayEnd;  // 가로등용
       float  flickerPeriod, flickerIntensity;  // 플리커용
       float  scaleAnimPeriod, scaleAnimMin, scaleAnimMax;  // 스케일링 일렁임
   };
   ```

2. `LightManager`:
   - 풀 기반 메모리 관리 (최대 256개)
   - `AddLight()`, `RemoveLight()`, `UpdateAll(deltaTime)`
   - Time of Day 필터링
   - 플리커/스케일링 애니메이션 업데이트
   - 이벤트 라이트 API: `SpawnLight(spr2Name, pos, params)` / `DestroyLight(handle)`

**검증:**
- [ ] 여러 광원 배치 → 라이트맵에 정상 합성 확인
- [ ] Time of Day 변경 시 가로등 on/off 확인

#### 2-4-3. 밤낮 사이클

**대상 파일:** `LightMap.cpp` 또는 신규 `DayNightCycle.h/cpp`

**작업 내용:**
1. 10구간 앰비언트 테이블을 **render.ini `[DayNight]` 섹션**에 정의 (C++ 하드코딩 금지):
   ```ini
   [DayNight]
   ; 앰비언트 테이블: Hour, R, G, B (0.0~1.0)
   ; 실제 자연광 기준: 낮(8~17시) 밝기 유지, 일출/일몰 구간에서만 급변
   AmbientCount=10
   Ambient0=0,   0.10, 0.10, 0.20   ; 한밤중
   Ambient1=4,   0.12, 0.12, 0.25   ; 새벽 전
   Ambient2=5.5, 0.50, 0.40, 0.35   ; 일출 시작 (동틀녘)
   Ambient3=7,   0.90, 0.85, 0.80   ; 일출 완료 (따뜻한 아침)
   Ambient4=8,   1.00, 1.00, 1.00   ; 아침 (완전 밝음)
   Ambient5=17,  1.00, 1.00, 0.98   ; 오후 5시 (밝기 유지)
   Ambient6=18.5,0.85, 0.65, 0.45   ; 석양 (붉은 노을)
   Ambient7=19.5,0.40, 0.30, 0.40   ; 해질녘 (보라빛)
   Ambient8=21,  0.18, 0.16, 0.28   ; 초저녁
   Ambient9=23,  0.10, 0.10, 0.20   ; 깊은밤
   ```

   **설계 원칙:**
   - **낮(8~17시)**: 9시간 동안 밝기 거의 동일 (1.0) — 대낮 야외 활동 시간
   - **일출(4~8시)**: 4시간에 걸쳐 점진적으로 밝아짐
   - **일몰(17~19.5시)**: 2.5시간 집중 변화 (골든아워→블루아워)
   - **밤(21~4시)**: 7시간 동안 어두움 유지, 미세한 변화만

2. C++ 파서: 기존 render.ini 파싱 코드에 `[DayNight]` 섹션 추가
   - `AmbientCount` 읽기 → `Ambient0`~`AmbientN` 루프 파싱
   - 각 항목을 `hour(float), r(float), g(float), b(float)` 로 파싱하여 `std::vector<AmbientEntry>` 에 저장
   - 파싱 실패 또는 섹션 없을 경우 위 기본값을 폴백으로 사용

3. Lerp 보간: 현재 시간 → 인접 2구간 보간 → 앰비언트 색상
4. 실내 맵 예외:
   - 맵 `.cfg`에 `isIndoor=1` 플래그 → 밤낮 무시, 고정 앰비언트
   - **RESTools 맵 에디터에 `isIndoor` 체크박스 추가** (맵 속성 패널)
   - 체크 시 `.cfg` 저장에 `isIndoor=1` 기록, 게임 엔진이 로드 시 읽어서 밤낮 사이클 비활성화
5. 맵별 앰비언트 오버라이드: `.cfg`에 `ambientOverride` 섹션

**검증:**
- [ ] 에디터 모드에서 시간 빠르게 진행 → 하루 사이클 시각적 확인
- [ ] RESTools 맵 에디터에서 `isIndoor` 체크 → `.cfg` 저장 → 게임에서 로드 시 밤낮 고정 확인

#### 2-4-4. 맵 에디터 — 광원 배치 지원

**신규 파일 포맷:** `.lgt` (광원 배열 데이터)

**작업 내용:**
1. `.lgt` 파일 포맷 정의 (고정 크기 타입):
   ```
   Header: "LGT1" + uint32 LightCount
   Light Entry (per light): position(float2) + spr2Name(char[64]) + frameIndex(int32) + color(uint32) + scale(float) + intensity(float) + timeOfDayStart(float) + timeOfDayEnd(float) + flickerParams(float3) + scaleAnimParams(float3)
   ```

2. ImGui 에디터 패널:
   - 광원 리스트 뷰
   - SPR2 리소스 선택 브라우저
   - 광원 배치/이동/삭제
   - 속성 편집 (Time of Day, 플리커, 스케일링 등)

3. 게임 엔진 `.lgt` 로더: 맵 로드 시 자동 로드

**검증:**
- [ ] 에디터에서 SPR2 광원 배치 → 저장 → 게임에서 로드 → 동일 결과 확인
- [ ] 핫리로드 (`R` 키) → .lgt 수정 즉시 반영 확인


---
---

## 3. 물 렌더링 + 배경 흔들림 + 후처리

---

### 3-1. 물 렌더링 (Rendering Step 4)

#### 3-1-1. 물 속성 맵 에디터 지원

**대상 파일 (RESTools):** `EF/MapDoc.h`, `EF/Map.h`
**대상 파일 (클라이언트):** `GodiusClient/Map.cpp`

**작업 내용:**
1. `dATTR_32` → `dWATER_ATTR(32)` 이름 변경 (RESTools MapDoc.h)
2. 속성 브러시 UI: "물 속성" 메뉴 텍스트 변경
3. 속성 시각화: `GetAttrColorByID()`에 반투명 파란색 추가
4. 게임 엔진: `CMapAttr` 비트 32를 물 속성으로 인식

**검증:**
- [ ] 맵 에디터에서 물 속성 페인팅 → 시각화 확인 → .atr 저장/로드 정상

#### 3-1-2. 물 렌더링 1단계 — 오버레이

**작업 내용:**
1. 물 텍스처 에셋: 타일링 가능한 반투명 물 표면 (128×128 PNG)
2. 타일 순회 시 `dWATER_ATTR` 타일에 물 쿼드 수집
3. 물 셰이더 `PS_Water1`:
   ```hlsl
   float4 PS_Water1(VS_OUTPUT input) : SV_Target {
       float2 uv1 = input.uv + float2(time * 0.02, time * 0.01);
       float2 uv2 = input.uv + float2(-time * 0.015, time * 0.02);
       float4 layer1 = waterTex.Sample(sampler, uv1);
       float4 layer2 = waterTex.Sample(sampler, uv2);
       float4 water = (layer1 + layer2) * 0.5 * waterTint;
       water.a *= waterOpacity;
       return water;
   }
   ```
4. 렌더 순서: 바닥 → **물** → 오브젝트/캐릭터
5. 물 쿼드 배칭: 1회 DrawCall

**검증:**
- [ ] 물 속성 타일에 반투명 물 텍스처 스크롤 표시 확인

#### 3-1-3. 물 렌더링 2단계 — 굴절

> **핵심 설계**: 별도 RT 복사 없이 **순환버퍼 SRV(`CTileRenderer::pSRV`)를 직접 바인딩**.
> 순환버퍼는 타일(지면)만 포함 → 건물·가로등·캐릭터 일렁임 문제 원천 차단. 추가 복사/축소 비용 0.

**작업 내용:**
1. 순환버퍼 SRV 바인딩: 물 셰이더 `t1` 슬롯에 `CTileRenderer::pSRV` 바인딩. scroll offset 기반 UV 보정 (기존 `Render()`의 UV 계산 재활용)
2. 물 셰이더 `PS_Water2`:
   ```hlsl
   // t1 = 순환버퍼 SRV (CTileRenderer::pSRV)
   // s1 = pSamplerWrap (WRAP + bilinear)
   float4 PS_Water2(VS_OUTPUT input) : SV_Target {
       float2 distortion = float2(sin(input.uv.y * 20 + time * 3), cos(input.uv.x * 15 + time * 2)) * refractStrength;
       float2 scrollUV = input.uv + scrollOffset;  // 순환버퍼 UV 보정
       float4 refracted = scrollBufTex.Sample(wrapSampler, scrollUV + distortion);
       float4 water = refracted * waterTint;
       water.a = waterOpacity;
       return water;
   }
   ```
3. 코스틱 텍스처 추가: 가산 블렌딩
4. WaterParams 상수 버퍼에 `scrollOffset` 추가 (순환버퍼 UV 보정용)

**검증:**
- [ ] 물밑 바닥이 일렁이며 비치는지 확인
- [ ] 물 위 건물/캐릭터는 일렁이지 않는지 확인

#### 3-1-4. 맵별 물 설정

**작업 내용:**
1. `MapWaterConfig` 구조체: opacity, refractStrength, scrollSpeed, causticIntensity, tintColor
2. `.cfg` 파일에 `[Water]` 섹션 추가
3. ImGui 물 파라미터 편집 패널 (에디터 모드)
4. 프리셋: 맑은 강, 깊은 바다, 늪, 용암, 얼음

**검증:**
- [ ] 서로 다른 물 설정 맵 전환 시 물 느낌 변화 확인

---

### 3-2. 배경 오브젝트 흔들림 (Rendering Step 6)

#### 3-2-1. 바람 시스템

**작업 내용:**
1. 글로벌 바람 변수: `windDirection(float2)`, `windSpeed(float)` → 공통 상수 버퍼에 추가
2. 날씨 연동 (Step 9에서 확장): 비 → 강풍

#### 3-2-2. 오브젝트 흔들림 셰이더

**작업 내용:**
1. 버텍스 셰이더:
   ```hlsl
   float sway = sin(time * windSpeed + worldPos.x * 0.1) * swayAmount * heightFactor;
   output.position.x += sway * windDirection.x;
   ```
2. 오브젝트 분류 플래그: FGP에 "흔들림 타입" 추가 (나무/풀/깃발/없음)
3. 타입별 파라미터:
   - 큰 나무: 느리고 크게 (`swayAmount=3.0, speed=1.0`)
   - 풀: 빠르고 작게 (`swayAmount=0.5, speed=3.0`)
   - 깃발: 사인파+노이즈 (`swayAmount=2.0, speed=2.0, noise=0.5`)
4. ImGui 패널: 오브젝트별 흔들림 타입 편집

**검증:**
- [ ] 바람 방향에 따라 나무, 풀 동기화 흔들림 확인
- [ ] 무풍 ↔ 강풍 전환 확인

---

### 3-3. 포스트 프로세싱 (Rendering Step 5)

#### 3-3-1. 후처리 프레임워크

**신규 파일:** `GodiusClient/PostProcessChain.h`, `PostProcessChain.cpp`

**작업 내용:**
1. `PostProcessChain` 클래스:
   - 효과 리스트 관리, 활성화/비활성화, 순서 제어
   - 핑퐁 RT 전환: RT_PostA → 효과 → RT_PostB → 효과 → ...
   - 풀스크린 쿼드 렌더 함수

2. 렌더링 순서 통합:
   ```
   씬 렌더 → 라이트맵 합성 → 후처리 체인 → UI → Present
   ```

**검증:**
- [ ] 빈 후처리 체인(패스스루) → 화면 변화 없이 정상 동작

#### 3-3-2. 블룸

**작업 내용:**
1. 밝기 추출 셰이더: threshold 이상 픽셀만 추출 → 1/4 RT
2. 가우시안 블러: 가로+세로 분리 블러 (2패스)
3. 블룸 합성: 블러 결과를 원본에 가산 블렌딩
4. 파라미터: threshold, intensity, blurRadius

**검증:**
- [ ] 마법 이펙트/광원 주변 빛번짐 확인

#### 3-3-3. 컬러 그레이딩 (LUT)

**작업 내용:**
1. LUT 텍스처 로더: 16×16×16 3D LUT → 256×16 2D 펼침
2. LUT 셰이더: 색상 변환
3. 기본 LUT 에셋: Neutral, Dungeon(Cold), Desert(Warm), Night(DarkBlue)
4. LUT 블렌딩: 2개 LUT 보간 (맵 전환, 시간대 전환)
5. 상태이상 LUT 오버레이: 독=초록, 저주=보라

**검증:**
- [ ] 맵별 LUT 전환 시 분위기 변화 확인
- [ ] 전환 시 부드러운 보간 확인

#### 3-3-4. 비네트

**작업 내용:**
1. 비네트 셰이더: `smoothstep` 기반 가장자리 어둡게
2. 맵/상황별 강도: 던전=강, 필드=약, 저체력=붉은 비네트

**검증:**
- [ ] 화면 가장자리 자연스러운 어둡기 확인


---
---

## 4. 왜곡 + 파티클 + 환경 통합

---

### 4-1. 화면 왜곡 (Rendering Step 7)

#### 4-1-1. 왜곡 프레임워크

**신규 파일:** `GodiusClient/DistortionManager.h`, `DistortionManager.cpp`

**작업 내용:**
1. `DistortionManager`: 활성 왜곡 리스트, 우선순위
2. 기본 왜곡 셰이더: UV 오프셋 기반 후처리 (중심, 강도, 형태 파라미터)
3. 후처리 체인에 왜곡 패스 삽입: 블룸 후, LUT 전

#### 4-1-2. 왜곡 타입 구현

| 타입 | 설명 | 지속 |
|------|------|------|
| 타격 임팩트 | 타격 지점 중심 방사형 팽창 | 2~4프레임 |
| 보스 등장 | 화면 전체 진동 + 방사형 | 20~30프레임 |
| 열기/아지랑이 | 위쪽 사인파 UV 오프셋 | 사막/용암 맵 지속 |
| 수중 | 전체 화면 물결 | 수중 영역 지속 |
| 피격 순간 | 화면 전체 약한 수축 | 1~2프레임 |
| 폭발 | 강한 방사형 확장 + 감쇠 | 5~8프레임 |

**검증:**
- [ ] 디버그 키로 각 왜곡 타입 트리거 → 시각적 확인

---

### 4-2. 파티클 시스템 (Rendering Step 8)

#### 4-2-1. 파티클 엔진

**신규 파일:** `GodiusClient/ParticleSystem.h`, `ParticleSystem.cpp`

**작업 내용:**
1. `Particle` 구조체: 위치, 속도, 수명, 크기, 알파, 회전, 색상, 텍스처 인덱스
2. `ParticleEmitter` 클래스:
   - 방출 형태: 점/원/직사각형
   - 방출 속도, 파티클 초기값 범위 (최소~최대)
3. `ParticleManager`:
   - 이미터 리스트 관리
   - 파티클 풀 (최대 500개)
   - 쿼드 배칭 렌더링 (가산/알파 블렌딩)

4. 기본 파티클 텍스처 에셋: 원형, 별, 라인, 연기 (각 32×32 PNG)

**검증:**
- [ ] 테스트 이미터 → 파티클 방출/소멸 확인

#### 4-2-2. 환경 파티클 (핵심 4종 + 나머지 후순위)

| 파티클 | 개수 | 특성 | 우선순위 |
|--------|------|------|----------|
| **비** | 100~200 | 1×8px 라인, 위→아래 + 바람 | 핵심 |
| **눈** | 80~150 | 2~4px, 느리게 하강 + 좌우 흔들림 | 핵심 |
| **안개** | 10~20 | 64~128px 대형 반투명, 느리게 이동 | 핵심 |
| **반딧불** | 15~25 | 랜덤 부유 + 밝기 변동, 라이트맵 미약 광원 | 핵심 |
| 낙엽/꽃잎 | 20~40 | 하강+회전+좌우 | 후순위 |
| 먼지/모래 | 30~50 | 바닥→위+바람 | 후순위 |
| 불씨/연기 | 20~30 | 위로 상승+알파 감쇠 | 후순위 |

**검증:**
- [ ] 비/눈/안개/반딧불 각각 활성화 → 자연스러운 동작 확인

---

### 4-3. 분위기/환경 통합 (Rendering Step 9)

#### 4-3-1. 맵 환경 프리셋

**신규 파일:** `GodiusClient/EnvironmentPreset.h`, `EnvironmentPreset.cpp`

**작업 내용:**
1. `EnvironmentPreset` 구조체:
   ```cpp
   struct EnvironmentPreset {
       float3 ambientColor;
       char   lutName[64];
       char   particleSet[64];     // "rain", "snow", "fog", "firefly", "none"
       float  windSpeed, windDirX, windDirY;
       float  fogDensity;
       float  bloomThreshold, bloomIntensity;
       float  vignetteStrength;
   };
   ```

2. 프리셋 정의 파일: JSON/INI 기반
3. 기본 프리셋 세트: 숲(낮/밤), 사막, 던전, 화산, 눈산, 해변, 묘지, 성안
4. 맵 로드 시 프리셋 적용 (Lerp 보간으로 부드럽게 전환)

#### 4-3-2. 날씨 시스템

**작업 내용:**
1. `WeatherState` 구조체: rainIntensity, snowIntensity, fogDensity, windSpeed, windDirection, thunderTimer
2. 날씨 전환: 현재 → 목표 Lerp 보간
3. 날씨 → 파티클 연동: 비 강도 → 비 파티클 수
4. 날씨 → 앰비언트: 흐린 날 multiplier 0.7
5. 번개: 15~45초 간격 → 라이트맵 전체 플래시 → 천둥 사운드 딜레이

#### 4-3-3. ImGui 환경 설정 패널

**작업 내용:**
1. 환경 프리셋 드롭다운 + 커스텀 파라미터 편집
2. `.cfg`에 `[Environment]` 섹션 저장
3. 실시간 프리뷰 (게임 렌더러에서 즉시 반영)

**검증:**
- [ ] 서로 다른 환경 프리셋 맵 순회 → 분위기 차이 확인
- [ ] 맵 전환 시 부드러운 전환 확인
- [ ] 비 → 눈 전환 시 파티클 자연스러운 변화 확인
- [ ] 번개 → 라이트맵 플래시 + 천둥 사운드 딜레이 확인

#### 4-3-4. IPC 연동 (Step 0-3, 병행)

**작업 내용:**
1. Named Pipe: `\\.\pipe\GodiusEditor`
2. 프로토콜: 텍스트 커맨드 (`OPEN_MAP <name>`, `SCROLL_TO <x,y>`, `RELOAD_ALL`)
3. RESTools 측: 맵 열기/스크롤 시 IPC 전송
4. GcX.exe 측: 메인 루프에서 비동기 폴링 + 커맨드 디스패치
5. RESTools 맵 에디터 시작 시 `GcX.exe -editor` 자동 실행

**검증:**
- [ ] RESTools 맵 열기 → GcX.exe 동일 맵 자동 로드
- [ ] RESTools 스크롤 → GcX.exe 동기 이동
- [ ] RESTools 저장 → GcX.exe 자동 리로드


---
---

## 5. 전투 타격감 + 스팀 SDK

---

### 5-1. 전투/타격 비주얼 피드백 (Rendering Step 3)

#### 5-1-1. 화면 셰이크

**신규 파일:** `GodiusClient/ShakeManager.h`, `ShakeManager.cpp`

**작업 내용:**
1. `ShakeManager`: intensity, duration, decay
2. 카메라 Lerp에 `shakeX`, `shakeY` 오프셋 추가
3. 프리셋: 일반(약), 크리티컬(중), 보스(강)
4. 타격 판정 코드에서 `ShakeManager::Trigger()` 호출

**검증:**
- [ ] 타격 시 화면 흔들림 확인, 강도별 차이 체감

#### 5-1-2. 히트 플래시

**작업 내용:**
1. 셰이더 `PS_HitFlash`:
   ```hlsl
   float4 PS_HitFlash(VS_OUTPUT input) : SV_Target {
       float4 color = spriteTex.Sample(sampler, input.uv);
       return lerp(color, float4(1,1,1,color.a), flashIntensity);
   }
   ```
2. 엔티티별 `flashIntensity`: 피격 시 1.0 → 0.0 감쇠 (2~3프레임)
3. flashIntensity > 0이면 플래시 셰이더로 렌더

**검증:**
- [ ] 몬스터/캐릭터 피격 → 순간 하얗게 번쩍임 확인

#### 5-1-3. 히트 프리즈

**작업 내용:**
1. 글로벌 `hitFreezeFrames` 카운터
2. 0이 아니면 게임 로직 갱신 스킵, 렌더링은 계속
3. 프리셋: 일반 1~2프레임, 강공격 3~4프레임

**검증:**
- [ ] 강한 타격 시 짧은 멈춤 체감 확인
- [ ] 온라인 동기화 이슈 없는지 확인 (클라이언트 로컬 연출)

#### 5-1-4. 데미지 넘버 물리

**신규 파일:** `GodiusClient/DamageNumber.h`, `DamageNumber.cpp`

**작업 내용:**
1. `DamageNumber` 구조체: 위치, 속도, 중력, 알파, 값, 타입
2. `DamageNumberManager`: 풀 기반 (최대 64개)
3. 물리: 초기 속도(위+랜덤좌우) → 중력 감속 → 알파 감쇠 → 소멸
4. 타입별 비주얼: 크리티컬(크고 빨강), 힐(초록), 미스(회색 작게)
5. 기존 데미지 표시 로직 교체

**검증:**
- [ ] 다양한 데미지 타입 → 숫자가 다르게 튀어오름 확인

---

### 5-2. Steamworks SDK 클라이언트 통합 (Phase D)

#### 5-2-1. SDK 통합

**작업 내용:**
1. Steamworks SDK 다운로드 → `GodiusClient/Steamworks/` 에 배치
2. vcxproj에 인클루드/라이브러리 경로 추가
3. `steam_api64.dll` 배포 경로 설정

#### 5-2-2. 초기화/종료

**대상 파일:** `Winmain.cpp`

**작업 내용:**
1. 게임 시작 시: `SteamAPI_Init()` 호출
2. 메인 루프에서: `SteamAPI_RunCallbacks()` 호출
3. 게임 종료 시: `SteamAPI_Shutdown()` 호출
4. `steam_appid.txt` 배치 (개발용)

**검증:**
- [ ] Steam 클라이언트 실행 상태에서 게임 시작 → SteamAPI 초기화 성공 로그

#### 5-2-3. Steam 오버레이

**작업 내용:**
1. DX11 렌더링과 Steam 오버레이 호환성 확인
2. `Shift+Tab` → Steam 오버레이 표시 확인

**검증:**
- [ ] Steam 오버레이 정상 표시 + 게임 렌더링 깨짐 없음

#### 5-2-4. Steam 인증

**작업 내용:**
1. `SteamUser()->GetAuthSessionTicket()` → 인증 티켓 발급
2. 기존 로그인 패킷에 Steam 티켓 포함하여 서버 전송
3. 서버 측 검증은 별도 진행 (D-3)

**검증:**
- [ ] 인증 티켓 발급 성공 로그

#### 5-2-5. Steam 기능 연동

**작업 내용:**
1. 도전과제: `SteamUserStats()->SetAchievement()` / `StoreStats()`
2. 클라우드 세이브: `SteamRemoteStorage()` API로 설정 파일 동기화
3. 리치 프레즌스: `SteamFriends()->SetRichPresence()` (현재 맵/레벨 표시)

**검증:**
- [ ] 테스트 도전과제 달성 → Steam 팝업 확인
- [ ] 설정 파일 클라우드 동기화 확인

---

### 5-3. 프로파일링 + 최적화 (Phase B, 병행)

#### 5-3-1. 초기화 최적화

**작업 내용:**
1. 초기화 로딩 시간 측정 (SPR 로드, 맵 로드, 리소스)
2. 병목 지점 식별 → 병렬 로딩 또는 지연 로딩 적용
3. 로딩 진행바 개선

#### 5-3-2. 실행 최적화

**작업 내용:**
1. FPS 카운터 → 프레임 속도 안정성 확인
2. 프레임 병목 프로파일링 (VS Graphics Debugger, PIX)
3. 핫스팟 최적화 (드로우콜 줄이기, 배칭 개선 등)

**검증:**
- [ ] 로딩 시간 개선 전/후 비교
- [ ] FPS 안정성 확인 (목표: 60fps @ 1920×1080)


---
---

## 후순위 버퍼 (여유 생기면 추가)

| 항목 | 내용 | 배치 |
|------|------|------|
| Step 3-5 | 잔상 (After Image) | 5주차 |
| Step 3-6 | 스쿼시 & 스트레치 | 5주차 |
| Step 3-7 | 트레일 이펙트 (무기 궤적) | 5주차 |
| Step 4-5 | 물 디테일 3단계 (파문/거품/깊이별 색조) | 5주차 |
| Step 5-5 | 크로매틱 어버레이션 | 5주차 |
| Step 5-6 | 모션블러, 필름그레인 | 5주차 |
| Step 8-2 나머지 | 낙엽/먼지/불씨 파티클 | 5주차 |
| Step 8-3 | 인터랙션 파티클 (발자국/물파문/전투) | 5주차 |
| E-2 Phase 5 | SPR→SPR2 일괄 변환기 | 5주차 |
| Char.dat 폐기 | Char.dat 22,487개 SPR → 부위별 멀티프레임 SPR2 ~1,500개로 통합 변환 (391MB→~15-30MB) → Char.dat/Char.Off 삭제 | 5주차 |
| 캐릭터 GPU 합성 캐시 | 부위별 SPR2를 GPU에서 합성 → 캐시 텍스쳐 (장비 변경 시만 재합성, DrawCall 4~5→1) | 5주차 |
