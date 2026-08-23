# Спецификация: «резиновый» свайп вверх по полю поиска

Всё правится в одном файле — `/Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/Chrome/ActionBarView.swift`. Ничего в `ActionBarState.swift`, `BottomChrome.swift`, `Tokens.swift` менять не нужно.

## 1. Формула резины

Каноническая из UIScrollView:

    f(x) = (x · d · c) / (d + c · x)

где `x` — путь пальца, `d` — асимптота (максимальный отклик, f(∞) = d), `c` — начальная скорость отклика (f′(0) = c, у Apple 0.55).

Делим на `d` и получаем **нормированное натяжение** — это ключ ко всей конструкции:

    p(x) = f(x) / d = x / (x + d/c),   p ∈ [0, 1)

Один `p` считается за кадр (одно деление), и от него линейно разводятся высота и ширина — они синхронны **по построению**, отдельной формулы для ширины не нужно:

    Δh = p · heightLimit      // прирост высоты
    Δw = p · widthLimit       // сжатие ширины (суммарное, по Δw/2 с каждой стороны)

Параметры под нашу капсулу 60×354:
- `c = 0.55` (значение Apple — под пальцем узнаётся как «системная» резина; 0.7 = живее, 0.45 = туже)
- `heightLimit d = 10` → капсула 60 → максимум 70
- `widthLimit = 16` (4.5% от макетных 354pt)
- `halfway = d/c = 10 / 0.55 = 18.1818` — путь пальца, на котором резина натянута ровно наполовину
- `activation = 8` — слоп распознавания вычитается из пути: `x = max(0, travel − 8)`, поэтому в момент срабатывания жеста скачка нет, растяжение стартует с нуля

Таблица отклика (travel — путь пальца вверх в pt):

| travel | x | p | Δh | Δw | высота | ширина (от 354) |
|---|---|---|---|---|---|---|
| 8 | 0 | 0.000 | 0.00 | 0.00 | 60.00 | 354.00 |
| 12 | 4 | 0.180 | 1.80 | 2.89 | 61.80 | 351.11 |
| 16 | 8 | 0.306 | 3.06 | 4.89 | 63.06 | 349.11 |
| 24 | 16 | 0.468 | 4.68 | 7.49 | 64.68 | 346.51 |
| 32 | 24 | 0.569 | 5.69 | 9.10 | 65.69 | 344.90 |
| **44 (порог)** | 36 | **0.664** | **6.64** | **10.63** | **66.64** | **343.37** |
| 60 | 52 | 0.741 | 7.41 | 11.85 | 67.41 | 342.15 |
| 120 | 112 | 0.860 | 8.60 | 13.77 | 68.60 | 340.23 |
| 200 | 192 | 0.914 | 9.13 | 14.62 | 69.13 | 339.38 |
| ∞ | ∞ | 1.000 | 10.00 | 16.00 | 70.00 | 338.00 |

Первые миллиметры идут за пальцем с коэффициентом 0.55 — отклик мгновенный; дальше резина жёстко «тупеет» (44pt пальца → всего 6.6pt растяжения). Это и есть ощущение натянутой резины, а не следования за пальцем.

**Почему не «сохранение объёма».** Честная несжимаемая резина дала бы при Δh=10 сжатие ширины 354·(1 − 60/70) = 50pt — карикатура. Берём ~⅓ от этого: 16pt.

## 2. Конфиг (рядом с `ActionBarGeometry`, стиль `ShareCardDragConfig`)

```swift
/// Резина свайпа по полю поиска. Формула из UIScrollView: f(x) = (x·d·c)/(d + c·x),
/// где d — асимптота отклика, c — начальная скорость. В нормированном виде это
/// p(x) = x/(x + d/c) ∈ [0,1): один прогресс за кадр, высота и ширина от него —
/// значит, они синхронны по построению.
private enum SearchPullConfig {
    /// Слоп распознавания: до него живёт тап, резина ещё не тянется.
    static let activation: CGFloat = 8
    /// c из UIScrollView — доля движения пальца, которую капсула отдаёт на старте.
    static let rate: CGFloat = 0.55
    /// d по высоте: капсула 60 тянется максимум до 70.
    static let heightLimit: CGFloat = 10
    /// d по ширине: 16pt — 4.5% от макетных 354pt поля.
    static let widthLimit: CGFloat = 16
    /// d/c — путь пальца, на котором резина натянута наполовину.
    static let halfway: CGFloat = heightLimit / rate   // 18.18

    /// Порог фокуса по пути пальца вверх.
    static let triggerDistance: CGFloat = 44
    /// Короткий, но резкий рывок вверх открывает поиск, не дотягивая до порога.
    static let flickVelocity: CGFloat = 500            // pt/s
    static let flickMinDistance: CGFloat = 16
    /// Гистерезис порога — чтобы хаптик не дребезжал на границе.
    static let triggerHysteresis: CGFloat = 8
    static let tickHapticIntensity: CGFloat = 0.45

    /// Отпустили, не дотянув: возврат с едва заметным перелётом ~11%.
    static let release: Animation = .spring(duration: 0.32, bounce: 0.42)

    /// Нормированное натяжение 0…1.
    static func progress(travel: CGFloat) -> CGFloat {
        let x = max(0, travel - activation)
        return x / (x + halfway)
    }
}
```

## 3. Модификаторы `SearchPill` (правка цепочки, строки 242–270)

Добавляется состояние **внутри `SearchPill`** — это критично для fps (см. §7):

```swift
/// Натяжение резины 0…1. Живёт здесь, а не в ActionBarState: запись 120 раз в секунду
/// в @Observable инвалидировала бы весь хром — мини-плеер, таббар, подложку.
@State private var pull: CGFloat = 0
/// Хаптик порога уже отдан.
@State private var tickArmed = false

private var stretch: CGFloat { pull * SearchPullConfig.heightLimit }
/// Сжимается только гибкая капсула. У круга 60pt в режиме music те же 16pt — это 27%,
/// и HStack потащил бы за собой мини-плеер каждый кадр.
private var squeeze: CGFloat {
    layout.searchWidth == nil ? pull * SearchPullConfig.widthLimit : 0
}
```

Цепочка (изменённые/новые строки помечены):

```swift
HStack(spacing: 8) { … }                                  // без изменений
    .padding(.horizontal, ActionBarGeometry.searchPaddingH)
    .frame(maxWidth: layout.searchWidth == nil ? .infinity : nil)
    .frame(width: layout.searchWidth)
    .frame(height: PlusMetrics.actionBarHeight + stretch)          // ← было .actionBarHeight
    .glassPill()
    .clipShape(Capsule(style: .continuous))
    .contentShape(Capsule(style: .continuous))
    .offset(y: -stretch / 2)                                       // ← новое: низ прилипает
    .simultaneousGesture(pullGesture)                              // ← новое
    .onTapGesture { searchFocused = true }                         // без изменений
    .padding(.horizontal, squeeze / 2)                             // ← новое: сжатие ширины
    .onChange(of: isSearchFocused) { _, focused in                 // ← новое: страховка
        if focused, pull != 0 { withAnimation(ActionBarMotion.morph) { pull = 0 } }
    }
```

Три нетривиальных решения в этой цепочке:

1. **`.offset(y: -stretch/2)`** — фрейм растёт симметрично вокруг центра, сдвиг на половину прижимает нижнюю кромку к бару, вверх уходит только верхняя. Читается как «низ прилип к таббару, тянешь верх». Это чистый transform, раскладку не трогает. Растянутая капсула вылезает на 6.6–10pt выше своей полосы — проверено: ни `ActionBarView`, ни `BottomChrome`, ни `.overlay(alignment:.bottom)` в `AppRootView` её там не клипают, а `TabBarUnderlay` рисуется слоем ниже.
2. **Сжатие ширины — внешним `.padding`, а не `.frame(width:)`.** HStack отдаёт гибкому ребёнку весь остаток независимо от его внутреннего паддинга, поэтому правая зона (мини-плеер / чип) **не едет** и лишнего прохода раскладки у неё нет. Условие `layout.searchWidth == nil` ровно совпадает со всеми случаями, где поиск — гибкая зона (search, book, movie, focused); фиксированный круг 60 в режиме music отсекается.
3. **Гейт `layout.searchWidth == nil` — по значению, а не через `if` во вью-дереве.** Ветвление вью здесь запрещено: на этом уже обжигались (поле ввода пересоздаётся → теряется фокус и каретка, см. DECISIONS 2026-08-23).

## 4. Жест

```swift
private var pullGesture: some Gesture {
    DragGesture(minimumDistance: SearchPullConfig.activation, coordinateSpace: .local)
        .onChanged { value in
            guard !isSearchFocused else { return }   // в фокусе поле принадлежит вводу
            let travel = -value.translation.height   // вверх — положительное
            // Без withAnimation: резина идёт 1:1 за пальцем, лишних кадров нет.
            pull = SearchPullConfig.progress(travel: travel)
            updateTick(travel: travel)
        }
        .onEnded { value in
            tickArmed = false
            guard !isSearchFocused else { pull = 0; return }
            let travel = -value.translation.height
            let flick = -value.velocity.height >= SearchPullConfig.flickVelocity
                && travel >= SearchPullConfig.flickMinDistance
                && travel > abs(value.translation.width)

            if travel >= SearchPullConfig.triggerDistance || flick {
                searchFocused = true                          // фокус + клавиатура
                // Резина расходится в тот же морф, каким бар переезжает в фокус.
                withAnimation(ActionBarMotion.morph) { pull = 0 }
            } else {
                withAnimation(SearchPullConfig.release) { pull = 0 }
            }
        }
}

/// Тик на пересечении порога — как у pull-to-refresh: палец ещё внизу, но уже «взведено».
private func updateTick(travel: CGFloat) {
    let cfg = SearchPullConfig.self
    if travel >= cfg.triggerDistance, !tickArmed {
        tickArmed = true
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: cfg.tickHapticIntensity)
    } else if travel < cfg.triggerDistance - cfg.triggerHysteresis {
        tickArmed = false
    }
}
```

Поведение по сценариям:
- **Свайп вниз или вбок** → `travel ≤ 0` → `x = 0` → `p = 0`, ничего не происходит, `onEnded` уходит в ветку возврата (no-op). Отдельный гейт по направлению не нужен.
- **Потянул и вернул палец обратно** → `p` непрерывно едет к 0, резина отпускается под пальцем. Естественно.
- **Отпустил, не дотянув** → `.spring(duration: 0.32, bounce: 0.42)` к нулю.
- **Дотянул 44pt или флик** → `searchFocused = true` + `withAnimation(ActionBarMotion.morph) { pull = 0 }`.
- **Фокус срабатывает ТОЛЬКО на отпускании.** Мид-драгом нельзя: `BottomChrome.focusedOffset` дёрнет бар вверх на ~347pt из-под пальца.

`value.velocity` (CGSize, pt/s) — iOS 17+, для таргета iOS 26 доступен; это точнее приёма `predictedEndLocation − location` из `ShareOverlay` (там 300 в «спроецированных точках», не pt/s). Из `ShareOverlay` берём сам каркас: `onChanged` пишет состояние без анимации, `onEnded` разводит порог/флик/возврат, пороги — именованными константами в конфиге рядом с компонентом.

## 5. Развод с тапом, скроллом и полем ввода

**Со скроллом ленты конфликта нет вообще, и решать его не надо.** `BottomChrome` висит в `.overlay(alignment: .bottom)` на корневом ZStack `AppRootView` — это слой-сосед поверх `ScrollView`, а не потомок. `UIPanGestureRecognizer` скролла получает только те касания, чей hit-test view лежит в его поддереве; касание по капсуле туда не попадает. Ни `simultaneousGesture` со скроллом, ни `scrollDismissesKeyboard` тут не нужны.

**Системный свайп «домой»** тоже не мешает: нижняя кромка капсулы стоит на `safeArea.bottom(34) + tabsRow(66) + gap(4)` ≈ 104pt от низа экрана, вне зоны home-жеста.

**Развод с тапом — `minimumDistance: 8` + `.simultaneousGesture`:**
- 8pt меньше слопа UIScrollView (~10pt), поэтому отклик читается как мгновенный, но `TapGesture` (у которого слоп ~10pt и он не переживает 44pt хода) при свайпе гарантированно проваливается — тап и драг взаимоисключаются сами.
- `.simultaneousGesture`, а не `.gesture`: у `SwiftUI` приоритет по умолчанию у **потомков**, а внутри капсулы есть невидимый `TextField` (он `.opacity(0)`, но hit-testable) и, в фокусе, `Button` креста. Обычный `.gesture` на родителе они могли бы перебить. `simultaneousGesture` получает касания параллельно, никого не отменяя.
- **Не `highPriorityGesture`**: он выиграл бы у `TextField` и убил выделение текста в фокусе.
- В фокусе оба обработчика делают ранний `return` — жест остаётся в дереве (идентичность вью не меняется), но инертен.

**Дополнительно (маленькая, но важная правка, строка 282):** добавить `.allowsHitTesting(isSearchFocused)` в `input` — сейчас невидимый `TextField` занимает бóльшую часть капсулы и остаётся кликабельным (`.opacity(0)` в SwiftUI hit-testing не выключает). Без этого касание может уходить в поле мимо нашего жеста. Модификатор параметрический, ветвления дерева нет → фокус не теряется.

## 6. Пружина: почему 0.32 / bounce 0.42

`.spring(duration: 0.32, bounce: 0.42)` ≡ `.spring(response: 0.32, dampingFraction: 0.58)` (для bounce ≥ 0: `dampingRatio = 1 − bounce`).

- **duration 0.32** — ровно темп `ActionBarMotion.morph` (`.smooth(duration: 0.32)`). Возврат резины и морф бара идут в одном темпе, бар не звучит двумя разными «скоростями».
- **bounce 0.42 (ζ = 0.58)** — перелёт `exp(−πζ/√(1−ζ²))` = **10.7%**. От порогового Δh=6.64 это **0.71pt**, от Δw=10.63 — **1.14pt**. То есть при отпускании капсула на один кадр становится на 0.7pt **ниже** и на 1.1pt **шире** покоя — физически правильная отдача сжатой резины, и это ровно «едва заметная пружинка». Второй перелёт 0.08pt — невидим.
- **Прогресс `pull` на возврате НЕ клампить в ≥ 0** — именно уход в минус даёт эту отдачу.
- Вилка для подстройки: bounce 0.30 → 4.6% (0.31pt — не видно вообще), 0.45 → 12.6% (0.84pt), 0.50 → 16.3% (1.08pt — уже «пружинит», перебор для этого сценария).
- **На срабатывании пружинки нет** — там `ActionBarMotion.morph` (`.smooth`, bounce 0). Разные анимации на двух исходах — читаемая обратная связь: «отскочило» = не сработало, «растворилось» = сработало. Плюс красивая непрерывность: сжатая ширина отпускается прямо в расширение поля 354 → 370 (поля бара 24 → 16).
- **`.interactiveSpring` для фазы под пальцем не нужен** — сама резинная функция уже сглаживает, а любая анимация на `onChanged` добавит отставание от пальца и лишние кадры.

Новых токенов в `ActionBarMotion` не заводим — «токен ради единственного вызова не заводим»; пружина возврата живёт в `SearchPullConfig.release`, а на срабатывании переиспользуется существующий `ActionBarMotion.morph`.

## 7. Производительность (обязательные сопутствующие правки)

`onChanged` летит на 120 Гц, и каждый вызов инвалидирует `SearchPill.body`. Три места, которые сейчас это не переживут:

1. **`pull` держать в `SearchPill`, не в `ActionBarState`.** `ActionBarState` — `@Observable` и читается `BottomChrome`, `TabBarView`, `TrailingSlot`, `MiniPlayerPill`. Запись туда на каждый кадр перерисовывала бы весь хром. В `SearchPill` инвалидация локальна: `ActionBarView.body`, `TrailingSlot` и мини-плеер не пересчитываются вообще.
2. **`glyphSize(of:box:)` вызывает `UIImage(named:)` на каждом вычислении body** (строки 288 и 306, хелпер — 608). Сейчас незаметно, при 120 Гц станет per-frame лукапом в кеш картинок. Вынести в `static let`:
   ```swift
   private enum SearchGlyph {
       static let search = glyphSize(of: "iconSearch", box: ActionBarGeometry.searchIconBox)
       static let close  = glyphSize(of: "iconClose",  box: ActionBarGeometry.searchIconBox)
   }
   ```
3. **`BackdropBlurView.applyRadius` пишет `inputRadius` через KVC на каждом `updateUIView`** (`DesignSystem/GlassSurface.swift:99-117`). Радиус константный — добавить ранний выход по сравнению значения:
   ```swift
   if let installed = backdrop.filters?.first as? NSObject,
      let current = installed.value(forKey: "inputRadius") as? CGFloat {
       if current != radius { installed.setValue(radius, forKey: "inputRadius") }
       return
   }
   ```

`GeometryReader` в решении не используется нигде: и 354, и 16pt — константы из макета, а не измерения. Правило «ширины зон не вычисляются из измеренной ширины» не нарушается.

## 8. Проверка

Свайп из шелла симулятора не воспроизвести, а скриншот статики резину не покажет. Предлагаю по образцу существующих `-debugMorphCycle` / `-debugSearchFocus` добавить `-debugSearchPull`: в `#if DEBUG .task` гонять `pull` 0 → 0.664 → (release spring) 0 по кругу, снимать `xcrun simctl io booted recordVideo` и разбирать покадрово. Ощущение под пальцем и хаптик — только на устройстве.


## ЗНАЧЕНИЯ
- Файл правки: /Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/Chrome/ActionBarView.swift, структура SearchPill (строки 236–322), цепочка модификаторов 262–270, input 274–283, glyphSize 608–614
- Формула: f(x) = (x·d·c)/(d + c·x); нормированная p(x) = x/(x + d/c), x = max(0, travel − activation)
- c (rate) = 0.55 — начальная скорость отклика, f'(0) = c
- heightLimit (d по высоте) = 10pt — асимптота прироста, капсула 60 → максимум 70
- widthLimit (d по ширине) = 16pt суммарно (по 8 с каждой стороны) = 4.5% от 354pt
- halfway = heightLimit / rate = 10 / 0.55 = 18.1818
- activation (minimumDistance) = 8pt
- triggerDistance = 44pt пути пальца вверх → p = 0.664, Δh = 6.64pt (высота 66.64), Δw = 10.63pt (ширина 343.37)
- flickVelocity = 500 pt/s вверх (value.velocity.height, iOS 17+), flickMinDistance = 16pt, условие travel > abs(translation.width)
- triggerHysteresis = 8pt, tickHapticIntensity = 0.45 при UIImpactFeedbackGenerator(style: .medium)
- Пружина возврата без срабатывания: .spring(duration: 0.32, bounce: 0.42) ≡ .spring(response: 0.32, dampingFraction: 0.58) → перелёт 10.7% = 0.71pt по высоте, 1.14pt по ширине
- Пружина при срабатывании: существующий ActionBarMotion.morph = .smooth(duration: 0.32), без bounce
- Смещение: .offset(y: -stretch/2) — нижняя кромка прилипает, верхняя уходит вверх на полный Δh
- Сжатие ширины: .padding(.horizontal, squeeze/2) снаружи clipShape, только при layout.searchWidth == nil
- Жест: .simultaneousGesture(DragGesture(minimumDistance: 8, coordinateSpace: .local)), .onTapGesture остаётся без изменений
- Новое состояние в SearchPill: @State private var pull: CGFloat = 0, @State private var tickArmed = false
- Новый конфиг: private enum SearchPullConfig рядом с ActionBarGeometry (строки 24–46)
- Ширины капсулы по режимам: 354 (search без музыки, 402−2·24), 284 (search с музыкой), 60 (music, круг), 370 (фокус, 402−2·16)
- Сопутствующая правка: .allowsHitTesting(isSearchFocused) на input (строка 282)
- Сопутствующая правка: glyphSize вынести в static let (enum SearchGlyph)
- Сопутствующая правка: /Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/DesignSystem/GlassSurface.swift:99-117 — ранний выход в applyRadius при неизменном радиусе

## РИСКИ
- ГЛАВНЫЙ: UIVisualEffectView внутри glassPill() пересчитывает gaussian-блюр на новом размере каждый кадр драга (60→67pt). Замерить Instruments/GPU; если не влезает в 8.3ms — снизить heightLimit до 6 и widthLimit до 10, либо оставить только растяжение высоты. Смягчающее обстоятельство: backdrop-блюр над скроллящейся лентой и так перерисовывается каждый кадр.
- glyphSize(of:box:) дёргает UIImage(named:) при каждом вычислении SearchPill.body — при 120 Гц это per-frame лукап. Обязательно вынести в static let, иначе жест сам себе создаст просадку.
- BackdropBlurView.applyRadius пишет inputRadius через KVC на каждом updateUIView — может инвалидировать блюр каждый кадр. Добавить сравнение значения.
- pull ни в коем случае не класть в ActionBarState (@Observable): его читают BottomChrome, TabBarView, TrailingSlot, MiniPlayerPill — 120 записей в секунду перерисуют весь хром.
- onEnded может не прийти при отмене жеста (звонок, снятие вью) — капсула останется растянутой. Страховка: .onChange(of: isSearchFocused) сбрасывает pull; при желании продублировать в .onDisappear.
- .animation(ActionBarMotion.morph, value: layout.animationKey) на родительском HStack теоретически может подхватить наши покадровые изменения — тогда резина будет отставать от пальца. Проверить на устройстве; если проявится — писать pull через withTransaction { $0.disablesAnimations = true } или вынести драйверы геометрии за область действия этого модификатора.
- Невидимый TextField (.opacity(0)) остаётся hit-testable и может перехватывать касания у жеста. Лечится .allowsHitTesting(isSearchFocused) — но НЕЛЬЗЯ оборачивать поле в if: пересоздание теряет фокус и каретку (уже обожглись, DECISIONS 2026-08-23).
- Ветвление вью по layout.searchWidth == nil должно быть только по значению (в вычисляемом свойстве squeeze), а не через .if во вью-дереве — иначе меняется идентичность и слетает фокус.
- Сжатие ширины через .frame(width:) вместо .padding в режиме music (searchWidth = 60, trailing гибкий) потащило бы мини-плеер каждый кадр — отсюда гейт на layout.searchWidth == nil.
- На отдаче pull уходит в минус (−0.107) → padding становится отрицательным на ~0.57pt с каждой стороны и съедает часть 8pt зазора до мини-плеера. Визуально безвредно, но если мешает — клампить squeeze снизу −1.
- Фокус нельзя ставить мид-драгом: BottomChrome.focusedOffset поднимет бар на ~347pt из-под пальца. Только на onEnded.
- VoiceOver и Reduce Motion: жест недоступен ассистивным технологиям — тап должен остаться единственным гарантированным путём (он и остаётся). Опционально уважать accessibilityReduceMotion, отключая растяжение, но не сам жест.
- Верификация: скриншотом резину не поймать, симулятор не отдаёт хаптик и не даёт свайп из шелла. Нужен либо девайс, либо debug-флаг -debugSearchPull + recordVideo с покадровым разбором.