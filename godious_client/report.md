# GodiusClient 컴파일 워닝 수정 리포트 (2차)

## 위험한 워닝 (근본적 수정)

### 1. C4474 - sprintf 인수 불일치 (버그)
| 파일 | 라인 | 문제 | 수정 |
|------|------|------|------|
| AllienceGuild.cpp | 563 | 포맷 문자열에 `%s` 없이 guildName 인수 전달 → 길드명 미출력 | `%s` 추가: `" 선택한 길드[%s]에게 연합요청 할까요? "` |
| AllienceGuild.cpp | 1155 | 포맷 문자열에 specifier 없이 `GetConvertStr()` 전달 → 불필요 인수 | 미사용 인수 `GetConvertStr()` 제거 |
| Item.cpp | 1236,1238 | `%s` 1개에 인수 2개 (`GetItemName`, `item.str`) 전달 | 불필요 인수 `item.str` 제거 |
| Item.cpp | 10073,10075 | 위와 동일 패턴 | 불필요 인수 `item.str` 제거 |
| Post.cpp | 202,1105,1399 | `"만료됨"` 포맷에 specifier 없이 `nRemainTime % 60` 전달 | 불필요 인수 제거 |
| Post.cpp | 1403 | `"무제한"` 포맷에 specifier 없이 `nRemainTime % 60` 전달 | 불필요 인수 제거 |

### 2. C4477 - sprintf 포맷 타입 불일치 (잘못된 출력값)
| 파일 | 라인 | 문제 | 수정 |
|------|------|------|------|
| AutoBotGuard.cpp | 685 | `%d`에 `unsigned __int64`(size_t) 전달 → 64비트에서 잘못된 값 출력 | `(int)vecActioMovePos.size()` 캐스트 |
| AutoBotGuard.cpp | 1423,1426 | 동일 | `(int)vecActioMovePos.size()` 캐스트 |

### 3. C4311/C4302 - 포인터 잘림 (64비트 크래시 위험)
| 파일 | 라인 | 문제 | 수정 |
|------|------|------|------|
| Hangul.cpp | 1716 | `isascii(checkStr+j)` - 포인터를 unsigned int로 캐스트 → x64에서 잘림 | `isascii((unsigned char)checkStr[j])` 로 수정 (포인터가 아닌 문자값 전달) |

### 4. DIRECTINPUT_VERSION undefined
| 파일 | 문제 | 수정 |
|------|------|------|
| DirectMouse.h | `#include <dinput.h>` 전에 DIRECTINPUT_VERSION 미정의 | `#ifndef DIRECTINPUT_VERSION / #define DIRECTINPUT_VERSION 0x0800 / #endif` 추가 |
| GETDXVER.CPP | 동일 | 동일 |

---

## 단순 워닝 (명시적 캐스트 추가)

### C4267 - size_t → int 변환 (약 500개소)
`strlen()`, `wcslen()`, `vector::size()`, `string::find()`, `fread()` 등의 반환값을 int 변수에 대입하는 경우. 게임 클라이언트 특성상 문자열/컨테이너 크기가 INT_MAX를 초과할 일이 없으므로 `(int)` 명시적 캐스트로 처리.

| 파일 | 수정 개소 |
|------|-----------|
| 5YearEvent.cpp | 2 |
| AllienceGuild.cpp | 16 |
| Alchemist.cpp | 5 |
| AlchemistTrans.cpp | 5 |
| ArenaSystem.cpp | 7 |
| AutoSizeMessageBox.cpp | 3 |
| BlacksmithEnhanceItem.cpp | 5 |
| BoardMenu.cpp | 13 |
| ChangeVisual.cpp | 1 |
| ChatEmote.cpp | 6 |
| CongraulationMsg.cpp | 2 |
| DailyDungeon.cpp | 3 |
| DailyDungeonGame.cpp | 3 |
| DmidiPlay.cpp | 1 |
| Equipment.cpp | 12 |
| EventExchangeCostume.cpp | 1 |
| ExchangeCostume.cpp | 1 |
| ExchangeLimitItem.cpp | 10 |
| FriendSystem.cpp | 1 |
| GamePlay.cpp | 31 |
| GcXStringData.cpp | 1 |
| GuildActivityPoint.cpp | 13 |
| GuildMenu.cpp | 28+ |
| GuildMoney.cpp | 21 |
| GuildMultyWar.cpp | 19 |
| HalloweenEvent.cpp | 1 |
| Hangul.cpp | 18 |
| ImeLib.cpp | 8 |
| InstanceDungeonGame.cpp | 9 |
| InstanceDungeonUI.cpp | 6 |
| Item.cpp | 18 |
| LangK.cpp | 1 |
| Magic.cpp | 1 |
| map.cpp | 2 |
| Market.cpp | 8 |
| MarketRegist.cpp | 22 |
| MoneyEdit.cpp | 4 |
| MonGhostEvent.cpp | 6 |
| NewbieOldbieEvent.cpp | 2 |
| NewYearGiftExchange.cpp | 8 |
| Npc.cpp | 15 |
| NpcEnhanceItem.cpp | 5 |
| Option.cpp | 8 |
| Party.cpp | 10 |
| Player.cpp | 9 |
| PositionWar.cpp | 6 |
| PositionWarBuilding.cpp | 4 |
| Post.cpp | 6 |
| PubUI.cpp | 15 |
| RaidDungeon.cpp | 4 |
| RecipeSystem.cpp | 8 |
| Resurrection.cpp | 1 |
| Sailor.cpp | 15 |
| SewingEnhanceItem.cpp | 5 |
| ShopMenu.cpp | 12 |
| Smuggler.cpp | 30 |
| sprite.cpp | 1 |
| Status.cpp | 16 |
| SummerEventInsami.cpp | 4 |
| Supplier.cpp | 8 |
| ThanksGivingDay.cpp | 1 |
| UserCharCon.cpp | 22 |
| UserCharMake.cpp | 6 |
| UserMenu.cpp | 29 |
| WaterPiaGame.cpp | 2 |
| WeaponShape.cpp | 2 |
| X-Event.cpp | 1 |
| Yut.cpp | 9 |

### C4244 - 타입 축소 변환
| 파일 | 라인 | 변환 | 수정 |
|------|------|------|------|
| Codeconv.cpp | 29692 | `__int64` → `int` | `(int)` 캐스트 |
| Alchemist.cpp | 744 | `float` → `int` | `(int)` 캐스트 |
| AlchemistTrans.cpp | 551 | `float` → `int` | `(int)` 캐스트 |
| AutoBotGuard.cpp | 1619,1620 | `LONG` → `short` | `(short)` 캐스트 |
| GcXStringData.cpp | 1406,1517,1628,1751 | `streamoff` → `int` | `(int)` 캐스트 |
| GuildMoney.cpp | 152 | `double` → `int` | `(int)` 캐스트 |
| GuildMoney.cpp | 210,390 | `__int64` → `double` | `(double)` 캐스트 |
| Item.cpp | 2116 | `short` → `BYTE` | `(BYTE)` 캐스트 |
| Magic.cpp | 3904 | `LONG` → `char` | `(char)` 캐스트 |
| PositionWarGame.cpp | 86 | `float` → `int` | `(int)` 캐스트 |
| ShopMenu.cpp | 4520,4525,4530 | `LONG` → `short` | `(short)` 캐스트 |
| Status.cpp | 605 | `LONG` → `BYTE` | `(BYTE)` 캐스트 |
| UserBuild.cpp | 495 | `short` → `char` | `(char)` 캐스트 |
| UserCharMake.cpp | 1741,1765 | `LONG` → `char` | `(char)` 캐스트 |
| Video.cpp | 191,192,193,200,210 | `double` → `float` | `(float)` 캐스트 |
| Winmain.cpp | 1563,2891 | `WPARAM` → `int` | `(int)` 캐스트 |
| Winmain.cpp | 2807 | `WPARAM` → `WORD` | `(WORD)` 캐스트 |
| X-Event.cpp | 115,258 | `float` → `int` | `(int)` 캐스트 |
| X-Event.cpp | 273 | `float` → `DWORD` | `(DWORD)` 캐스트 |
| Yut.cpp | 592,593 | `double` → `int` | `(int)` 캐스트 |

### C4305 - double → float / int → bool 잘림
| 파일 | 라인 | 수정 |
|------|------|------|
| Alchemist.cpp | 262,267,272 | `21` → `21 != 0` 처리 |
| Video.cpp | 196 | `0.4, 0.5, 0.6` → `0.4f, 0.5f, 0.6f` |

### C4018 - signed/unsigned 비교
| 파일 | 라인 | 수정 |
|------|------|------|
| ExchangeCostume.cpp | 304 | `(int)` 캐스트 |
| Npc.cpp | 2461,2483,2534 | `(int)` 캐스트 |
| ShopMenu.cpp | 685,692,699 | `(DWORD)` 캐스트 |

### C4838 - 축소 변환 (초기화 리스트)
| 파일 | 라인 | 수정 |
|------|------|------|
| GuildMultyWar.cpp | 148 | `(LONG)szList.size()` 캐스트 |

### C4996 - deprecated 함수
| 파일 | 수정 |
|------|------|
| StaticTexture.cpp | `#pragma warning(disable: 4996)` 추가 |
| timeGetTime.cpp | `#pragma warning(disable: 4996)` 추가 |
| RenderConfig.cpp | `#pragma warning(disable: 4996)` 추가 |

### C4101 - 미참조 지역 변수
| 파일 | 라인 | 수정 |
|------|------|------|
| Scroll.cpp | 27 | 미사용 변수 `int x, y;` 주석 처리 |

### C4566 - 유니코드 문자 표현 불가 (미수정)
| 파일 | 라인 | 비고 |
|------|------|------|
| PalScroll.cpp | 151 | `\u2014` (em dash) - 코드 페이지 949에서 표현 불가. 소스 인코딩 문제로 캐스트로 해결 불가. 빌드에 영향 없음. |
| OfflineMode.cpp | 196,320,331 | 동일 |

---

## 총 수정 파일: 약 75개, 수정 개소: 약 600+
## 빌드 결과: 성공 (1 성공, 0 실패)
