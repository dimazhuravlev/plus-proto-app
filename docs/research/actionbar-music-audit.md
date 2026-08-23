# Аудит мини-плеера музыки (режим `.music`) — Фигма ↔ код ↔ симулятор

Дата: 2026-08-23. Только разведка, код не менялся.
Предмет: расширенный мини-плеер внутри action bar — режим `.music`, поле поиска сжато в круг 60pt.

Источники:
- Фигма: файл `0HzFEKtm9oYdkksrDg7U14`, ноды `2001:111009` (state=music player) → `2001:111011` (mini-player). Данные свежие, снято `get_metadata` + `get_design_context` + `get_screenshot` (рендер 284×60 @1x).
- Код: `PlusProtoApp/Chrome/ActionBarView.swift` (`MiniPlayerPill`, `MiniPlayerProgressFill`, `ActionBarGeometry`), `DesignSystem/Tokens.swift`, `DesignSystem/Typography.swift`, `DesignSystem/GlassSurface.swift`.
- Симулятор: `xcrun simctl launch booted com.dima.PlusProtoApp -debugActionBar music -debugMockFeed`, скриншот `/tmp/audit_music.png` (1206×2622 = 402×874 pt ×3). Все числа ниже — замер PIL, не глаз.

Оговорка про ширину: в Фигме бар 400pt при полях 24 → пилюля плеера 284. На экране 402 → пилюля 286 (замер: 92.0…378.0). Это не расхождение, зона гибкая. Все сравнения ведутся от левой кромки пилюли.

---

## 1. Эталон из Фигмы (нода `2001:111011`)

Дерево с абсолютными координатами (`get_metadata`):

```
mini-player 284×60
└ player 284×60          r32, fill #FFFFFF1A, backdrop-blur 35, border 0.66 Fill/Nine, clip
  ├ stack        260×48 @ (6, 6)     HStack gap 12, items-center
  │ ├ track info 182×48 @ (0, 0)     flex-1, HStack gap 8, items-center
  │ │ ├ image/music   48×48 @ (0, 0)   r1000, border 0.66 Fill/Nine, img 480×480 cover
  │ │ └ track name   126×32 @ (56, 8)  flex-1, VStack gap 0, items-start
  │ │   ├ title       97×16 @ (0, 0)
  │ │   └ description 90×16 @ (0, 16)
  │ └ actions     66×24 @ (194, 12)   HStack gap 18, justify-end
  │   ├ icon/love  24×24 @ (0, 0)
  │   └ icon/pause 24×24 @ (42, 0)
  └ progress     130×60 @ (0, 0)     absolute: left/top/bottom −0.66, w 130 (мок)
```

Ключевые значения:

| Свойство | Фигма |
|---|---|
| Отступы пилюли | `pl 6` / `pr 18` / `py 8` (min), контент центрирован → фактически 6 сверху и снизу |
| Обложка | 48×48, радиус 1000 (круг), обводка 0.66 `Fill/Nine` (#FFFFFF14, white 8%) |
| **Зазор обложка → тексты** | **8** (`track info` gap) |
| Зазор тексты → кнопки | 12 (`stack` gap) |
| **Зазор название → исполнитель** | **0** — два бокса по 16pt встык, `track name` = 32pt |
| Типографика обеих строк | `Text S・13/Medium`: Yango Text Medium, 13px / lh 16 / **letter-spacing 0** / weight 500 |
| Цвет названия | `Fill/One` #FFFFFF |
| Цвет исполнителя | `Fill/Subtitle` #FFFFFF80 (white 50%) |
| Зазор ♥ ↔ ⏸ | 18 (между боксами 24) |
| Бокс иконки | 24×24 |
| Глиф ♥ (`icon/love`, вектор `;19:3848`) | **20.0 × 17.78** (inset 15.05 / 8.33 / 10.88 / 8.33 %) |
| Глиф ⏸ (`icon/pause`, вектор `;19:2276`) | **13.5 × 16.5** (inset V 15.63 / H 21.88 %) |
| Прогресс | прямоугольник во всю высоту, якорь слева, вылет −0.66 влево/вверх/вниз (перекрывает обводку), заливка `Fill/Ten` #FFFFFF0F = **white 6%**, ширина 130 — мок |
| Радиус пилюли | 32 (при h60 схлопывается в капсулу) |

Замер по рендеру Фигмы @1x (перекрёстная проверка дерева): обложка 6…54, левый край ink текста 62/63, ink «Strawberry Line» 95pt, ink «Cocteau Twins» 89pt; ♥ ink 20×17 на x 202…221, ⏸ ink 14×16 на x 247…260. Дерево и рендер сходятся.

**Иконки play в макете нет** — в состоянии `music player` показана только пауза. Эталона для `iconPlay` в Фигме не существует, сверять не с чем.

---

## 2. Замер по скриншоту симулятора

Пилюля плеера: x 92.0…378.0 (286), y 710.0…769.7 (59.7 ≈ 60). Центр бара 740.

| Что | Замер (pt) |
|---|---|
| Обложка | x 97.7…145.8 (48.1), y 716.3…763.7 (47.4) → отступы 5.7 / 6.3 ✓ |
| ink «Strawberry Line» | x 158.67…249.33 (90.67), y 726.0…737.33 |
| ink «Cocteau Twins» | x 158.33…241.00 (82.67), y 743.67…753.33 |
| Базовая линия названия | 735.33 |
| Базовая линия исполнителя | 753.33 |
| **Baseline-to-baseline** | **18.0** |
| Левый край текста от кромки пилюли | **66.3** |
| ♥ ink | 16.33 × 14.67, центр (305.83, 740.0) → бокс 293.8…317.8 |
| ▶ ink | 14.0 × 16.33, центр (347.67, 739.8) → бокс ≈335.7…359.7 |
| Расстояние центров ♥→▶ | 41.83 (эталон 42) ✓ |
| Правый отступ (правая кромка бокса ▶ → кромка пилюли) | 18.3 ✓ |
| Правый край заливки прогресса | 212.0 (жёсткая вертикаль) |
| Дельта RGB на кромке прогресса | (11.2, 11.1, 12.1) над фоном (72.2, 68.1, 59.3) → ровно white 6% ✓ |

---

## 3. Таблица расхождений (по убыванию величины)

| Элемент | В Фигме | В коде | На скриншоте | Расхождение | Что править |
|---|---|---|---|---|---|
| **Зазор обложка ↔ тексты** | 8 (`track info` gap) | 12 — один плоский `HStack(spacing: miniPlayerContentGap)` на обложку, тексты и кнопки | левый край текста 66.3 от кромки пилюли (эталон 62) | **+4 pt**, весь текстовый блок сдвинут вправо | Разбить на два стека: внешний 12, внутренний 8 |
| **Глиф ♥** | leaf 20.0 × 17.78 | ассет `iconHeart.svg` = 16.6665 × 14.8146; `glyphSize()` отдаёт натуральный размер (fit = 1) | ink 16.33 × 14.67 | **−3.33 × −2.96 pt (−17 %)** | Нужен отдельный 24-боксовый экспорт ноды `I2001:111011;2127:128` |
| **Зазор название ↔ исполнитель** | **0** (боксы 16 + 16 = 32) | `VStack(alignment: .leading, spacing: 2)` | baseline-to-baseline 18.0 против 16.0 | **+2 pt**, строки разъехались; блок 34pt вместо 32 | `spacing: 0` |
| **Трекинг подписей** | `letter-spacing 0` | `plusTextS()` → `tracking: -0.2` | ink «Cocteau Twins» 82.67 против 89 (−7 %); из них ≈2.6pt даёт трекинг, остальное — подмена шрифта | **−0.2 pt на знак** | Решение пользователя: правка задевает и карточки витрины |
| Семейство шрифта | Yango Text Medium | YSText-Medium | подписи на 4–5 % уже эталона даже без трекинга | подмена, шрифт Yango в проект не бандлится | Информационно, не правится |
| Прогресс: ширина | 130 из 284 (45.8 %) | живой `musicProgress`, ширина через `scaleEffect(x:)` | 120.0 из 286 (42.0 %) | не расхождение — в макете мок | — |
| Прогресс: цвет и геометрия | white 6 %, жёсткая вертикаль, вылет −0.66 | `Color.fillTen` = white 6 %, overlay поверх обводки | дельта ровно white 6 %, кромка жёсткая | ✓ | — |

### Сошлось точно (проверено замером)

| Свойство | Значение |
|---|---|
| Отступы пилюли `pl 6` / `pr 18` | обложка 5.7 от кромки, бокс ▶ 18.3 до кромки |
| Обложка 48×48, круг, обводка 0.66 white 8 % | 48.1 × 47.4, `PlusMetrics.miniPlayerCover` = 48, `Color.fillNine`, `hairline` 0.66 |
| Вертикальное центрирование контента | обложка 716.3…763.7, центр 740.0 = центр бара |
| Зазор ♥ ↔ ⏸ = 18 | расстояние центров 41.83 ≈ 42 |
| Бокс иконки 24 | `actionIcon(box: 24)` |
| Глиф ⏸ 13.5 × 16.5 | `iconPause.svg` = ровно 13.5 × 16.5 |
| Зазор тексты ↔ кнопки 12 | `miniPlayerContentGap` = 12 |
| Материал: fill white 10 %, blur 35, border 0.66 white 8 % | `glassPill()` → `buttonsPrimary` / `glassBlur` / `fillNine` / `hairline` |
| Радиус 32 при h60 = капсула | `Capsule(style: .continuous)` |
| Цвета текста `Fill/One` / `Fill/Subtitle` | `Color.fillOne` / `Color.fillSubtitle` (white 50 %) |
| Кегль/интерлиньяж 13/16 | `plusTextS()` → `FigmaTextStyle(size: 13, lineHeight: 16)`; замерено: строка занимает ровно 16pt (натуральный lh YS Text 13 ≈ 15.24, `FigmaTextStyle` добирает `delta/2` симметричным паддингом) |

---

## 4. Правки

Нумерация строк — по состоянию `ActionBarView.swift` на момент аудита (файл параллельно правит другой агент, номера могли уехать; ориентируйся на текст-якорь).

### П1. Зазор обложка ↔ тексты: 12 → 8

Причина: в Фигме два вложенных стека с разными зазорами, в коде — один плоский.

`PlusProtoApp/Chrome/ActionBarView.swift:56` — добавить константу рядом с существующей:

```swift
/// Зазор обложка ↔ подписи внутри `track info` (figma-actionbar §4.2, нода I2001:111011;741:53204).
static let miniPlayerCoverGap: CGFloat = 8
```

`PlusProtoApp/Chrome/ActionBarView.swift:681` (`MiniPlayerPill.content`) — вложить `track info`:

```swift
HStack(spacing: ActionBarGeometry.miniPlayerContentGap) {   // 12 — Figma `stack`
    HStack(spacing: ActionBarGeometry.miniPlayerCoverGap) { // 8  — Figma `track info`
        cover
        trackInfo
            .opacity(trackInfoOpacity)
    }
    actions
        .opacity(trackInfoOpacity)
}
.padding(.leading, ActionBarGeometry.miniPlayerPaddingLeading)
.padding(.trailing, ActionBarGeometry.miniPlayerPaddingTrailing)
.frame(maxWidth: .infinity, alignment: .leading)
```

Гибкость сохраняется: у `trackInfo` уже стоит `.frame(maxWidth: .infinity, alignment: .leading)`, поэтому внутренний `HStack` сам становится гибким ребёнком внешнего — как `flex-[1_0_0]` у `track info` в Фигме. Свёрнутое состояние (`.search`, круг 60pt) не задевается: обложка остаётся первым элементом на `pl 6`.

Проверка после правки: левый край ink названия должен встать на 92 + 62 ≈ 154.3 pt (сейчас 158.7).

### П2. Зазор название ↔ исполнитель: 2 → 0

`PlusProtoApp/Chrome/ActionBarView.swift:722`:

```swift
VStack(alignment: .leading, spacing: 0) {
```

Обоснование: `title` 16pt и `description` 16pt стоят встык (`y = 0` и `y = 16` при высоте контейнера 32). `plusTextS()` уже выдаёт строку ровно в 16pt, так что `spacing: 0` даёт эталонные 16pt между базовыми линиями.

Проверка после правки: baseline-to-baseline должно стать 16.0 (сейчас 18.0), блок текста — 32pt вместо 34pt.

### П3. Глиф сердца: 16.67 × 14.82 → 20.0 × 17.78

`iconHeart.svg` — это 20-боксовый экспорт, он же используется в `GlassIconButton` (`DesignSystem/GlassIconButton.swift:63`, бокс 20). Подменять сам файл нельзя — сломаются кнопки на карточках витрины. Нужен отдельный ассет.

1. Экспортировать ноду `I2001:111011;2127:128` (вектор `;19:3848`) как `iconHeart24.svg` размером `19.9998 × 17.77752`.
2. `PlusProtoApp/Chrome/ActionBarView.swift:737`: `actionIcon("iconHeart", liked: isLiked)` → `actionIcon("iconHeart24", liked: isLiked)`.

Готовый файл уже лежит в ворктри другого агента: `.claude/worktrees/awesome-nash-c0ebee/PlusProtoApp/Assets.xcassets/iconHeart24.imageset/iconHeart24.svg` (`width="19.9998" height="17.77752"`) — размеры совпадают с эталоном до сотых. Ту же правку он там уже сделал, но ворктри отстал от `main` (в его версии `actions` ещё без `playPauseButton`). **Скорее всего эта правка приедет сама — перед тем как делать, проверь, не влилась ли она.**

Побочно (вне зоны мини-плеера, из того же ворктри): `iconClose` — тоже 20-боксовый экспорт (13.08²) в 24-боксовой позиции креста поиска; `iconClose24.svg` (15.697²) там уже подготовлен.

### П4. Трекинг подписей: −0.2 → 0 — нужно решение

`PlusProtoApp/DesignSystem/Typography.swift:98`:

```swift
modifier(FigmaTextStyle(family: PlusFont.textMedium, size: 13, lineHeight: 16, tracking: 0))
```

Токен `Text S・13/Medium` в Фигме имеет `letter-spacing 0` — это подтверждают два независимых снапшота разведки (`figma-actionbar.md:24`, `figma-tokens.md:35`). Откуда в коде взялось −0.2, из макета не следует: единственный трекинг −0.2, который в разведке зафиксирован явно, — у заголовка H1 (`figma-tokens.md:41`).

Радиус поражения — `plusTextS()` используется ещё в трёх местах:
- `PlusProtoApp/Showcase/ContinueWatchingCard.swift:182`
- `PlusProtoApp/Showcase/ContinueReadingCard.swift:134`
- `PlusProtoApp/Showcase/ContinueReadingCard.swift:141`

Поэтому правка либо общая (и тогда стоит заодно перепроверить −0.2 у `plusTextM` / `plusReaderText`, для которых эталона в разведке тоже нет), либо мини-плееру нужен локальный вариант без трекинга. Вопрос к пользователю.

Замечание про ожидаемый эффект: трекинг объясняет только ~3 % от 7 %-й недостачи ширины подписей. Оставшиеся ~4 % — подмена Yango Text на YS Text, это не лечится без бандла шрифта Yango.

---

## 5. Открытые вопросы

- Трекинг −0.2 у `plusTextS` / `plusTextM` / `plusReaderText`: осознанная правка «на глаз» или наследие? В Фигме у `Text S` ls = 0.
- Иконки play в макете нет вовсе (в состоянии `music player` только пауза). `iconPlay.svg` — 24-боксовый, треугольник 14.29 × 16.5, рисуется по центру бокса; эталона нет, сверить не с чем. Если нужен канон — попросить дизайнера добавить вариант с play.
- Ширина прогресса в макете фиксированная (130 из 284). Что это в проде — реальный прогресс воспроизведения (как сейчас в коде) — по-прежнему открытый вопрос из `figma-actionbar.md`.
