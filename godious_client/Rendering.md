# Godius Remaster — 렌더링 파이프라인

---

## 1. 전체 렌더링 구조


┌─────────────────────────────────────────────────┐
│  Layer 1: 배경 바닥 타일 (순환버퍼 텍스처)       │
├─────────────────────────────────────────────────┤
│  Layer 2: 오브젝트 (Y-정렬, Painter's Algorithm) │
│   - 필드 오브젝트, 플레이어, 몬스터, NPC         │
│   - 아이템, 이펙트, 트랩, 유저 건물              │
├─────────────────────────────────────────────────┤
│  Layer 3: UI / 채팅 / 커서 / 페이드             │
└─────────────────────────────────────────────────┘


### 렌더링 흐름 (매 프레임)
1. **배경 순환버퍼 갱신** → 스크롤 발생 시 가장자리 타일만 CPU→GPU 부분 업데이트
2. **배경 쿼드 렌더링** → 순환버퍼 텍스처를 UV Wrap으로 1회 Draw
3. **오브젝트 수집 & Y-정렬** → `g_vecDrawObj`에 화면 내 오브젝트 수집, Y좌표 기준 오름차순 정렬
4. **오브젝트 순서대로 렌더링** → Back-to-Front (Painter's Algorithm), 텍스처 변경 시 DrawCall 분할
5. **UI 렌더링** → 화면 고정 좌표 기준
6. **페이드 오버레이** → 필요 시 검정 폴리곤 알파 0.0~1.0
7. **Present** → SwapChain Flip

---

## 2. 배경 타일 — GPU 순환버퍼

### 원본 방식
- CPU 메모리에 928×608 바이트 순환(Circular) 버퍼
- 스크롤 시 가장자리 타일만 `PutQtile()`로 그림
- `scbufftoscreen()`에서 모듈러스(%) 연산으로 래핑하여 800×600 화면에 복사

### 리마스터 방식
- **928×608 ARGB8888 텍스처** 1장을 GPU에 상주 (~2.2 MB)
- 스크롤 시 변경된 가장자리 타일만 `UpdateSubresource()`로 부분 업데이트
- **D3D11_TEXTURE_ADDRESS_WRAP 샘플러** 사용 → UV 오프셋만 조정하면 순환 래핑 자동 처리
- 1장 텍스처 + 1개 쿼드 = **DrawCall 1회**

### UV 계산
```
float u_offset = (float)scrollX / 928.0f;
float v_offset = (float)scrollY / 608.0f;

// 쿼드 UV: WRAP 샘플러가 0~1 범위 초과 시 자동 래핑
UV_TopLeft     = (u_offset, v_offset)
UV_BottomRight = (u_offset + 800.0/928.0, v_offset + 600.0/608.0)
```

### 타일 시스템
- 아이소메트릭 다이아몬드 타일: 64×32 픽셀
- 좌표 변환: `screenX = (mapX - mapY) × 32`, `screenY = (mapX + mapY) × 16`
- 스크롤 속도: 기본 4px/tick, 가드 모드 8~16px/tick

---

## 3. 스프라이트 렌더링 파이프라인

### 1차 방식: 실시간 RLE→ARGB 변환 (Draw 시점)

```
[원본]                    [리마스터 1차]
LoadSpr()                 LoadSpr()
  ↓                         ↓
8-bit RLE 메모리 보관      8-bit RLE 그대로 메모리 보관
  ↓                         ↓
DrawClipping() 시          DrawSprite() 시
8-bit → DIB 버퍼 memcpy   RLE 디코딩 + 팔레트 룩업 → ARGB8888
                            ↓
                          800×600 텍스처버퍼에 직접 Write
```

### 핵심 변경점
1. **LoadSpr()**: SPR 파일의 8-bit RLE 데이터를 **원본 그대로** 메모리에 보관 (기존과 동일)
2. **SPR_NODE 캐싱 유지**: 기존 참조 카운팅(refcount) 시스템 그대로 활용
3. **DrawSprite()**: 호출 시점에 RLE 디코딩 + 팔레트→ARGB8888 변환을 실시간으로 수행, 800×600 텍스처 버퍼에 직접 기록
4. 100개 스프라이트 = DrawSprite() 100회 호출 (각각 실시간 RLE→ARGB 변환) → 텍스처버퍼 완성 → GPU 업로드 → 쿼드 렌더

### 2차 방식 (1차가 느릴 경우): LoadSpr 시점 PreProcess 캐싱

```
[리마스터 2차 — 속도 개선용]
LoadSpr()
  ↓
8-bit RLE 로드
  ↓
PreProcess(): 팔레트 룩업 → ARGB8888 변환
  ↓
ARGB8888 메모리 보관 (SPR_NODE에 캐싱)
  ↓
DrawSprite() 시
ARGB8888 → 800×600 텍스처버퍼에 memcpy (디코딩 불필요)
```

- 1차 실시간 변환으로 우선 구현 후 프로파일링
- CPU 병목이 확인되면 LoadSpr() 시점에 ARGB8888로 미리 변환하여 캐싱
- 트레이드오프: RAM 사용량 증가 (RLE 대비 ~4~8배) vs CPU 부하 감소

---

## 4. 캐시 텍스처 시스템 (플레이어/몬스터/NPC)

### 동작 원리
1. 엔티티의 (액션, 방향, 프레임) 조합이 **변경될 때만** 텍스처 갱신
2. 애니메이션 딜레이가 ~130ms이므로, 대부분의 프레임에서 **캐시 히트** (갱신 불필요)
3. 동일 몬스터 종류 + 동일 프레임 → **텍스처 공유** (별도 생성하지 않음)

### 플레이어 캐릭터 합성
```
렌더링 순서 (아래에서 위로):
  1. Leg  (하체)  — lImg[action]
  2. Body (상체)  — bImg[action]
  3. Weapon       — wImg[action]
  4. Shield       — sImg[action]
  5. Head (머리)  — hImg[action]
```
- 바운딩 박스: 136×160 px (`dCHAR_OBJ_WIDTH × dCHAR_OBJ_HEIGHT`)
- ARGB8888 1프레임: ~87 KB
- 5파츠를 캐시 텍스처에 합성 → GPU 업로드

### 몬스터
- 275종, 6액션 (walk, attack, damage, die, magic, transform)
- 파일 패턴: `MON{ID:03d}{action:02d}.spr`
- 동일 종류 + 동일 프레임 = 1개 캐시 텍스처 공유
- 화면 내 같은 몬스터 10마리 → 텍스처 1개만 사용

### 캐시 텍스처 관리
- **생성**: D3D11_USAGE_DYNAMIC, ARGB8888 포맷
- **갱신**: Map() → CPU memcpy → Unmap()
- **해제**: 화면에서 벗어나거나 LRU 기반 자동 해제
- **최대 동시 사용**: ~250장 (200 플레이어 + 30 몬스터 + 20 NPC)

---

## 5. 정적 텍스처 시스템 (필드 오브젝트/이펙트/UI)

### 로드 시점
- **맵 진입 시**: 해당 맵의 필드 오브젝트, 이펙트, 트랩 등을 일괄 로드
- **게임 시작 시**: UI 텍스처 로드 (상시 유지)

### BC7 압축
- ARGB8888 → BC7: 4:1 압축 (품질 최상, 알파 포함)
- 런타임 변환 또는 오프라인 프리프로세싱
- GPU 디코딩 (하드웨어 지원, CPU 부하 없음)

### 필드 오브젝트 구조
```
sMAP_OBJECT
  └─ sOBJ_GROUP[] (그룹 배열)
       ├─ 바운딩 박스 (sx, sy, ex, ey)
       ├─ 위치 (x, y)
       └─ sFIELD_OBJ[] (오브젝트 배열)
            ├─ originX, originY
            └─ sUSER_IMG sprite
```
- 맵당 Object/ 디렉토리에서 .spr + .fgp 로드
- 정적이므로 텍스처 아틀라스로 합치면 DrawCall 절감 가능

---

## 6. Y-정렬 Painter's Algorithm

### 원본 방식 (GamePlay.cpp:PrtMapScreenObject)
1. 화면 내 모든 drawable 오브젝트를 `g_vecDrawObj` 벡터에 수집
2. Y좌표 기준 버블소트 (오름차순)
3. 앞(위)에서 뒤(아래)로 순서대로 렌더링

### 오브젝트 타입 (sDRAW_OBJ)
| 타입 ID | 이름 | 설명 |
|---------|------|------|
| 1 | dPLAYER | 플레이어 |
| 2 | dFIELD_OBJ | 필드 오브젝트 (나무, 건물 등) |
| 3 | dMONS | 몬스터 |
| 4 | dMAPITEM | 바닥 아이템 |
| 5 | dMAP_NPC | NPC |
| 6 | dMAGIC_EFF | 마법 이펙트 |
| 7 | dEFF | 일반 이펙트 |
| 8 | dTRAP | 트랩 |
| 9 | dUSERBUILD | 유저 건물 |

### 리마스터 렌더링
- 동일한 Y-정렬 로직 유지
- 정렬된 순서대로 쿼드 버텍스 누적
- **텍스처가 바뀌는 시점에만 DrawCall 발행** (동적 정점 배칭)

---

## 7. 카메라 댐핑 (Camera Damping)

### 원본
- 캐릭터 이동 시 화면이 즉시 따라감 (스냅)
- 딱딱하고 기계적인 느낌

### 리마스터 — Lerp 기반 스무스 팔로우
```cpp
// 매 프레임
float damping = 0.1f;  // 0.0 = 정지, 1.0 = 즉시 스냅
cameraX += (targetX - cameraX) * damping;
cameraY += (targetY - cameraY) * damping;
```

### 구현 포인트
- `targetX/Y`: 플레이어 캐릭터의 월드 좌표
- `cameraX/Y`: 현재 카메라 위치 (float)
- `damping`: 조절 가능한 감쇠 계수 (0.08~0.15 권장)
- 스크롤 오프셋 계산 시 cameraX/Y를 정수로 변환하여 사용
- **순환버퍼 UV 오프셋에 반영** → 부드러운 배경 스크롤
- 원본 키보드 스크롤(dSCROLL_SPEED)과 병행 가능

---

## 8. 동적 정점 배칭 (Dynamic Vertex Batching)

### 개요
Y-정렬된 오브젝트들을 순서대로 하나의 정점 버퍼에 쿼드로 누적하고, 텍스처가 변경되는 시점에만 DrawCall을 발행하는 방식.

### 동작 과정
```
정렬된 오브젝트 리스트:
  [몬스터A, 몬스터A, 플레이어1, 플레이어2, 나무, 몬스터B, ...]
     tex1    tex1      tex2       tex3    tex4   tex5

배칭 결과:
  DrawCall 1: 몬스터A × 2 (tex1)
  DrawCall 2: 플레이어1    (tex2)
  DrawCall 3: 플레이어2    (tex3)
  DrawCall 4: 나무         (tex4)
  DrawCall 5: 몬스터B      (tex5)
```

### 구현
1. 프레임 시작: 정점 버퍼 리셋
2. Y-정렬 순서대로 순회:
   - 현재 텍스처와 동일 → 쿼드 추가 (정점 4개 + 인덱스 6개)
   - 텍스처 변경 → 이전까지 누적된 쿼드 DrawCall → 새 텍스처 바인딩
3. 순회 완료 후 마지막 배치 DrawCall

### 정점 포맷
```cpp
struct Vertex {
    float x, y;      // 스크린 좌표
    float u, v;      // 텍스처 좌표
    // 필요 시: float alpha; (반투명 오브젝트용)
};
```

### 효과
- 동일 몬스터가 연속으로 배치되면 1 DrawCall로 합쳐짐
- 최악의 경우(전부 다른 텍스처): 오브젝트 수 = DrawCall 수
- 평균적으로 DrawCall 20~30% 감소 기대

---

## 9. 인스턴싱 관련

### Y-정렬과 인스턴싱의 충돌
- 인스턴싱은 **동일 메시+텍스처**를 한 번에 수백 개 그리는 기법
- Painter's Algorithm은 **렌더링 순서가 중요** (앞 오브젝트가 뒤를 가려야 함)
- Y-정렬 사이에 다른 텍스처가 끼어 있으면 인스턴싱 불가

### 제한적 적용 가능 케이스
- 바닥 아이템 (dMAPITEM): 다른 오브젝트에 가려지지 않는 경우
- 트랩 (dTRAP): 바닥에 깔리는 오브젝트
- 이펙트 중 가산 블렌딩 (Additive Blend): 순서 무관

### 결론
- **주력 최적화: 동적 정점 배칭**
- 인스턴싱은 특수 케이스에서만 선택적 적용
- 현재 DrawCall 수준 (~100~330)에서는 인스턴싱 없이도 충분

---

## 10. 페이드 인/아웃

### 원본
- 팔레트 조작으로 화면 전체를 어둡게/밝게 처리
- `FadeIn()` / `FadeOut()` — DIB 팔레트의 RGB 값을 점진적으로 0에 수렴/복원

### 리마스터
- **검정색 풀스크린 폴리곤** + 알파 블렌딩
- 알파 값 0.0 (투명) ~ 1.0 (완전 검정) 보간
- 팔레트 조작 코드 완전 제거
- 구현이 가장 단순하고 GPU 부하 없음

---

## 11. 800×600 RTT (Render To Texture)

### Step 2 단계 구조
```
CPU 영역:
  SPR(8-bit) → PreProcess → ARGB8888 메모리
  DrawSprite() × N → 800×600 텍스처 버퍼에 Copy

GPU 영역:
  800×600 텍스처 → 화면 쿼드에 매핑
  → 1280×960 (또는 FHD/4K) 백버퍼에 렌더링
  → Present
```

### 스케일링
- 800×600 → 타겟 해상도로 쿼드 스트레칭
- 포인트 필터링: 원본 픽셀아트 느낌 유지
- 바이리니어 필터링: 부드럽게 보이게 (선택 옵션)

### Step 3 이후
- 800×600 중간 텍스처 제거
- 오브젝트별로 직접 고해상도 백버퍼에 렌더링
- 배경 타일: 순환버퍼 → UV Wrap으로 직접 렌더
- 캐릭터/오브젝트: 캐시/정적 텍스처에서 직접 쿼드 렌더



