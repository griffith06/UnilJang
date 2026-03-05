# Godius Remaster — 작업 순서 (WorkFlow)

---

## Phase 1: DX11 기본 프레임워크 (Step 1)

### 1-A. 개발 환경 구성
- [ ] VS2005 → 최신 Visual Studio 마이그레이션 (또는 VS2005에서 DX11 SDK 연동)
- [ ] DirectX 11 SDK 헤더/라이브러리 프로젝트에 추가
- [ ] 기존 DirectDraw 링크 제거 (ddraw.lib, dinput.lib, dxguid.lib, dsound.lib)
- [ ] d3d11.lib, dxgi.lib, d3dcompiler.lib 링크 추가

### 1-B. DX11 디바이스 & SwapChain 초기화
- [ ] D3D11CreateDeviceAndSwapChain() 래퍼 작성
- [ ] Feature Level: D3D_FEATURE_LEVEL_11_0 (최소 10_0 폴백)
- [ ] SwapChain: DXGI_FORMAT_B8G8R8A8_UNORM, 더블 버퍼링
- [ ] RenderTargetView 생성
- [ ] 기본 뷰포트 설정 (1280×960)

### 1-C. 윈도우 모드 전환
- [ ] `InitAppWin()` 수정 — 1280×960 창모드 기본
- [ ] 풀스크린 전환 (Alt+Enter): SwapChain::SetFullscreenState()
- [ ] Alt+Tab 전환 시 디바이스 로스트 처리
- [ ] 창 크기 변경 시 SwapChain 리사이즈 대응
- [ ] `gWIN` 플래그 연동

### 1-D. 기존 DirectDraw 제거
- [ ] Ddrawmem.h / Ddrawmem.cpp 코드 비활성화
- [ ] `CreateDDMem()` / `CreateDDMemEx()` 호출 제거
- [ ] DirectDraw 7 버전 체크 코드 제거 (Winmain.cpp:650-658)
- [ ] DirectDraw 관련 전처리기 매크로 정리

### 1-E. 기본 렌더 루프 연결
- [ ] 게임 루프에 `ClearRenderTargetView()` → `Present()` 삽입
- [ ] 기존 `ViewVideoMem()` 호출 지점에 DX11 Present 연결
- [ ] 빈 화면(클리어 컬러)이 정상 출력되는지 확인
- [ ] FPS 카운터 / 디버그 오버레이 (선택)

---

## Phase 2: 800×600 텍스처 렌더링 (Step 2)

### 2-A. SPR 로드 & 팔레트 준비
- [ ] `LoadSpr()` 유지: 8-bit RLE 데이터를 **원본 그대로** 메모리에 보관
- [ ] 팔레트 테이블 로드 (기존 DIB 팔레트 → ARGB8888 룩업 테이블로 변환, 1회)
- [ ] 기존 SPR_NODE refcount 캐싱 시스템 유지
- [ ] Char.dat 아카이브 로드 경로는 그대로 유지 (sFileBind)

### 2-B. DrawSprite 함수 교체 (1차: 실시간 RLE→ARGB 변환)
- [ ] 새 `DrawSprite()` 작성: RLE 디코딩 + 팔레트→ARGB8888 변환을 실시간으로 수행, 800×600 텍스처 버퍼에 직접 기록
- [ ] 클리핑 로직 포팅 (기존 DrawClipping 참조)
- [ ] 알파 블렌딩 DrawSprite 변형 (기존 m_blendPalTable → ARGB 알파 블렌딩)
- [ ] 기존 `DrawClipping()` / `DrawClippingX()` 호출부를 새 함수로 교체
- [ ] 프로파일링 후 CPU 병목 시 → 2차 방식(LoadSpr 시점 PreProcess 캐싱)으로 전환 검토

### 2-C. 800×600 텍스처 생성 & 업로드
- [ ] D3D11_USAGE_DYNAMIC 텍스처 800×600 ARGB8888 생성
- [ ] 매 프레임: CPU 텍스처 버퍼 → Map/Unmap으로 GPU 업로드
- [ ] 화면 쿼드(풀스크린 삼각형 2개) + 텍스처 매핑
- [ ] 기본 버텍스/픽셀 셰이더 작성 (패스스루)

### 2-D. 팔레트 이펙트 교체
- [ ] FadeIn/FadeOut → 검정 폴리곤 + 알파 블렌딩으로 교체
- [ ] 기존 DIB 팔레트 조작 코드 비활성화
- [ ] `MakeDIBPalette()` 호출 → 전처리 시점으로 이동 (1회만)

### 2-E. DIB 시스템 제거
- [ ] DIBMem.h / DIBMem.cpp 코드 비활성화
- [ ] `CreateDIBMem()` → 800×600 ARGB CPU 버퍼 할당으로 교체
- [ ] `ViewDIBMem()` / BitBlt 호출 제거
- [ ] Video.h의 `sVIDEO` 구조체에서 DIB 관련 필드 제거

### 2-F. 안정화 & 검증
- [ ] 기존 모든 화면 (로그인, 캐릭터 선택, 인게임) 정상 출력 확인
- [ ] 스프라이트 깨짐 / 클리핑 오류 검수
- [ ] 성능 프로파일링 (CPU 텍스처 업로드 병목 확인)
- [ ] Alt+Tab, 풀스크린 전환, 창 리사이즈 안정성 테스트

---

## Phase 3: 배경 타일 GPU 전환 (Step 3-배경)

### 3-A. 순환버퍼 GPU 텍스처화
- [ ] 928×608 ARGB8888 GPU 텍스처 생성 (D3D11_USAGE_DEFAULT)
- [ ] 기존 `PutQtile()` 수정: 타일을 CPU 버퍼에 ARGB로 그린 후 `UpdateSubresource()` 부분 업데이트
- [ ] `scbufftoscreen()` 제거 → UV Wrap 쿼드 렌더링으로 교체
- [ ] D3D11_TEXTURE_ADDRESS_WRAP 샘플러 스테이트 설정

### 3-B. 카메라 댐핑
- [ ] 카메라 위치를 float로 관리 (cameraX, cameraY)
- [ ] Lerp 기반 스무스 팔로우: `camera += (target - camera) * damping`
- [ ] damping 계수 조절 가능하게 (기본 0.1)
- [ ] 스크롤 오프셋 → UV 오프셋으로 변환
- [ ] 기존 키보드 스크롤(MapScroll)과 병행

### 3-C. 타일 렌더링 분리
- [ ] 배경 바닥 타일: Layer 1 (순환버퍼 텍스처)
- [ ] 필드 오브젝트/캐릭터 등: Layer 2로 분리
- [ ] `StartPutMap()` → GPU 순환버퍼 갱신으로 교체
- [ ] 800×600 CPU 텍스처 버퍼에서 배경 부분 제거

---

## Phase 4: 캐릭터/몬스터 캐시 텍스처 (Step 3-캐릭터)

### 4-A. 캐시 텍스처 매니저
- [ ] 캐시 텍스처 풀 생성 (D3D11_USAGE_DYNAMIC, ARGB8888)
- [ ] 키: (엔티티ID, 액션, 방향, 프레임) → 텍스처 해시맵
- [ ] 캐시 히트 시 기존 텍스처 재사용
- [ ] LRU 기반 자동 해제

### 4-B. 플레이어 캐릭터 합성
- [ ] 5파츠 (Leg→Body→Weapon→Shield→Head) 순서로 캐시 텍스처에 합성
- [ ] 136×160 바운딩 박스 기준
- [ ] 장비 변경 / 프레임 변경 시에만 재합성
- [ ] 코스튬 파츠 대응

### 4-C. 몬스터 캐시 텍스처
- [ ] 동일 종류 + 동일 프레임 → 텍스처 공유
- [ ] 275종 × 6액션 × 4방향 × N프레임 → 필요 시에만 생성
- [ ] 화면에서 벗어난 몬스터 텍스처 해제

### 4-D. NPC / 유저 건물
- [ ] NPC: 캐시 텍스처 (몬스터와 동일 방식)
- [ ] 유저 건물: 정적 텍스처 (BC7 압축, 맵 로드 시)

---

## Phase 5: 정적 텍스처 & 오브젝트 렌더링 (Step 3-오브젝트)

### 5-A. 필드 오브젝트 정적 텍스처
- [ ] 맵 로드 시 Object/ SPR → ARGB → BC7 압축 → GPU 업로드
- [ ] 텍스처 아틀라스 구성 (DrawCall 절감)
- [ ] `DrawFieldGroupClipping()` → 쿼드 렌더링으로 교체

### 5-B. 이펙트/아이템/트랩
- [ ] 이펙트: 정적 텍스처 (BC7), 가산 블렌딩 지원
- [ ] 바닥 아이템: 정적 텍스처
- [ ] 트랩: 정적 텍스처

### 5-C. Y-정렬 통합 렌더링
- [ ] `PrtMapScreenObject()` 수정: 오브젝트 수집 & Y-정렬은 유지
- [ ] 정렬된 순서대로 쿼드 배칭 → 텍스처 변경 시 DrawCall 분할
- [ ] 동적 정점 버퍼 관리 (매 프레임 리셋 & 누적)

---

## Phase 6: UI & 마무리

### 6-A. UI 렌더링
- [ ] UI 텍스처 정적 로드
- [ ] 화면 고정 좌표 기준 렌더링 (Layer 3)
- [ ] 채팅창, 미니맵, 스킬바, HP/MP바 등

### 6-B. 다중 해상도 대응
- [ ] 1280×960 기본 → FHD/QHD/4K 스케일링
- [ ] UI 앵커링: 좌측 UI → 좌측 끝정렬, 우측 UI → 우측 끝정렬, 하단 → 하단 고정
- [ ] 와이드스크린: 좌우 추가 영역 렌더링 또는 레터박스

### 6-C. 최종 안정화
- [ ] 전체 맵 순회 테스트
- [ ] 200명 밀집 시나리오 성능 테스트
- [ ] Alt+Tab / 풀스크린 전환 / 창 리사이즈 안정성
- [ ] 메모리 누수 검사 (캐시 텍스처 해제 확인)
- [ ] 최저사양 하드웨어 테스트

---

## 작업 순서 요약

```
Phase 1 (DX11 기본)          Phase 2 (800×600 RTT)
  1-A 환경 구성                 2-A SPR 전처리
  1-B 디바이스 초기화            2-B DrawSprite 교체
  1-C 윈도우 모드                2-C 텍스처 생성/업로드
  1-D DirectDraw 제거            2-D 팔레트 이펙트 교체
  1-E 렌더 루프 연결             2-E DIB 시스템 제거
                                2-F 안정화
        ↓                            ↓
Phase 3 (배경 GPU)           Phase 4 (캐시 텍스처)
  3-A 순환버퍼 GPU화             4-A 캐시 매니저
  3-B 카메라 댐핑               4-B 플레이어 합성
  3-C 타일 렌더링 분리           4-C 몬스터 캐시
                                4-D NPC/건물
        ↓                            ↓
Phase 5 (정적 텍스처)        Phase 6 (UI & 마무리)
  5-A 필드 오브젝트              6-A UI 렌더링
  5-B 이펙트/아이템              6-B 다중 해상도
  5-C Y-정렬 통합                6-C 최종 안정화
```

### 의존성
- Phase 1 완료 후 Phase 2 시작 가능
- Phase 2 완료 후 Phase 3, 4 병행 가능
- Phase 3, 4 완료 후 Phase 5 시작
- Phase 5 완료 후 Phase 6 시작
