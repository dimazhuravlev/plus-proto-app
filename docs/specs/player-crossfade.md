## 1. Что реально есть в iOS 26 SDK (проверено компиляцией, не по памяти)

Проверено на `iPhoneSimulator26.2.sdk`, `swiftc -typecheck -target arm64-apple-ios26.0-simulator -swift-version 5`:

| Код | Результат |
|---|---|
| `.contentTransition(.blurReplace)` | **НЕ КОМПИЛИРУЕТСЯ**: `type 'ContentTransition' has no member 'blurReplace'` |
| `AnyTransition.blurReplace` | **НЕ КОМПИЛИРУЕТСЯ**: `type 'AnyTransition' has no member 'blurReplace'` |
| `.transition(.blurReplace)` | ✅ компилируется |
| `.transition(.blurReplace(.upUp))` | ✅ |
| `.transition(.blurReplace.combined(with: .opacity))` | ✅ |
| `.transition(AnyTransition(BlurReplaceTransition(configuration: .downUp)))` | ✅ |

Полный список членов `ContentTransition` в 26.2 (`SwiftUICore.swiftinterface:16116`): `identity`, `opacity`, `interpolate`, `numericText(countsDown:)`, `numericText(value:)`, `symbolEffect(_:options:)`, `symbolEffect`. **blurReplace там нет и никогда не было** — это `Transition`, а не `ContentTransition`.

Объявление: `SwiftUICore.BlurReplaceTransition`, `@available(iOS 17.0, *)`, `@_originallyDefinedIn(module: "SwiftUI", iOS 18.0)`. Таргет iOS 26 → guard по доступности не нужен. `Configuration`: `.downUp` (дефолт) и `.upUp`.

## 2. Точная формула нативного blurReplace (дизассемблировано из SwiftUICore)

Символ `$s7SwiftUI21BlurReplaceTransitionV4body7content5phaseQrAA22PlaceholderContentViewVyACG_AA0E5PhaseOtF` @ `0xabbd20`, константы вычитаны из `__TEXT`. Тело ровно такое:

```swift
content
    .opacity(phase == .identity ? 1 : 0)
    .blur(radius: phase == .identity ? 0 : 7, opaque: false)
    .scaleEffect(scale, anchor: .center)   // anchor захардкожен (0.5, 0.5)
```
где `scale`: `.identity` → **1.0**; `.willAppear` → **0.9**; `.didDisappear` → **0.9** при `.downUp`, **1.1** при `.upUp`.
Сырые значения enum'ов: `TransitionPhase` willAppear=0/identity=1/didDisappear=2; `Configuration` downUp=0/upUp=1. Радиус блюра **7**, флаг `opaque = false`. (Тот же набор 7.0 / 0.9 лежит и в `_makeContentTransition`, там же дополнительная разбивка тайминга 0.33 / 0.67.)

То есть «нативный эффект» = opacity + blur 7 + scale 0.9. Никакой магии, воспроизводится один в один.

## 3. Почему `.transition(.blurReplace)` в `TrailingSlot` брать НЕЛЬЗЯ

`TrailingSlot` (`ActionBarView.swift:386–425`) держит три слоя в `ZStack` и гасит их `.opacity` (строки 401, 406, 411). Ширину морфит сам контейнер: `.frame(maxWidth:)` / `.frame(width: layout.trailingWidth)` на строках 414–416. Дети ширину НЕ формируют: `BookChip` — фикс 48.078, `MovieChip` — фикс 91.552, `MiniPlayerPill` — `Color.clear.frame(maxWidth: .infinity)`, то есть тянется за контейнером.

`.transition` требует настоящего удаления вью. Удалённое поддерево выпадает из раскладки — его кадр замирает на последнем значении. Последствие для перехода **музыка → книга**: `trailingWidth` идёт с ~286pt на 48.078pt, а уходящая пилюля остаётся замороженной на 286pt и блюрится «в воздухе». Клипа нет (`clipTrailing = false` в режиме `.book`, строка 216), поэтому она наедет на растущее поле поиска. Это прямое нарушение правила DECISIONS «скрытые слои остаются в дереве, никаких if/else-подмен».

## 4. Решение: та же нативная формула на живых слоях

Слои остаются в дереве, `.opacity(...)` заменяется на модификатор с аппловскими числами. Морф ширин не трогается вообще — ноль новых проходов раскладки, ноль смен identity.

**А. `ActionBarMotion` (после строки 13):**
```swift
/// Кроссфейд со сменой типа плеера. Числа — ровно из нативного
/// BlurReplaceTransition(.downUp): opacity 0, blur 7, scale 0.9, anchor .center.
/// Сам `.transition(.blurReplace)` здесь нельзя — он удаляет вью, а уходящий
/// плеер должен продолжать сжиматься вместе с зоной.
static let swapBlurRadius: CGFloat = 7
static let swapScale: CGFloat = 0.9
```

**Б. Модификатор (в секцию Helpers, ~строка 606):**
```swift
private struct BlurReplaceLayer: ViewModifier {
    let isActive: Bool
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .blur(radius: isActive ? 0 : ActionBarMotion.swapBlurRadius, opaque: false)
            .scaleEffect(isActive ? 1 : ActionBarMotion.swapScale, anchor: .center)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }
}

private extension View {
    func blurReplaceLayer(_ isActive: Bool) -> some View {
        modifier(BlurReplaceLayer(isActive: isActive))
    }
}
```
Порядок `opacity → blur → scaleEffect` не переставлять: он взят из layout'а структуры, которую возвращает нативный `body`.

**В. `TrailingSlot`, строки 401 / 406 / 411 — точечная замена:**
```swift
.opacity(layout.showMiniPlayer ? 1 : 0)   →  .blurReplaceLayer(layout.showMiniPlayer)
.opacity(layout.showBookChip   ? 1 : 0)   →  .blurReplaceLayer(layout.showBookChip)
.opacity(layout.showMovieChip  ? 1 : 0)   →  .blurReplaceLayer(layout.showMovieChip)
```

**Г. Анимация — НЕ добавлять новую.** `layout.animationKey` (строка 135) уже содержит `showMiniPlayer`/`showBookChip`/`showMovieChip`, а `.animation(ActionBarMotion.morph, value: layout.animationKey)` на корневом HStack (строка 77) уже гоняет эти флаги. Блюр и скейл поедут по той же кривой 0.32 `.smooth`.

Если крос понадобится короче морфа (обычная апловская связка — `.smooth(duration: 0.3)`), добавить `.animation(ActionBarMotion.typeSwap, value: layout.trailingVariant)` **на сам ZStack, строкой сразу после `}` на 413** — тогда `.frame(width:)` на 414–416 останется снаружи и ширина не переедет на новую кривую. Второй `.animation` — плата за это; по умолчанию не ставить.

## 5. Гейт: эффект срабатывает только на смене типа

Проверка по `ActionBarLayout.init`: `showMiniPlayer` = true в `.search`/`.music`, false в `.book`/`.movie`; `showBookChip`/`showMovieChip` — по режиму. Значит:
- **search ↔ music** — оба слоя `showMiniPlayer = true`, флаг не меняется → блюра нет, идёт чистый морф ширины 60 ↔ 286. Это правильно: тут не смена объекта, а изменение формы того же.
- **music/search → book → movie → search** — флаги переключаются → блюр-кроссфейд. Ровно то, что просил пользователь.
- **обновление payload** (новый трек, `startMusic` с другим `id`) — флаги не трогает, identity вью не меняется (`if let music = actionBar.music`, payload'ы sticky) → блюра нет. **Категорически не заводить `.id(item.id)`** — каждая смена трека начала бы блюрить бар.

## 6. Баг, который надо починить заодно (иначе новый эффект его вытащит наружу)

`ActionBarView.swift:149–151`, ветка фокуса поиска:
```swift
showMiniPlayer = hasMusic
showBookChip = mode == .book
showMovieChip = mode == .movie
```
В режиме `.book`/`.movie` при непустом `music` получается `showMiniPlayer = true` **одновременно** с `showBookChip = true`. Сегодня это маскирует `.opacity(layout.trailingEscaped ? 0 : 1)` на контейнере (строка 420). С blurReplace на фокусе мини-плеер начнёт «проявляться» из блюра прямо в момент уезда. Правка:
```swift
showMiniPlayer = hasMusic && (mode == .music || mode == .search)
```

## 7. Стоимость по кадрам

Считано по iPhone 17 Pro (402pt): контент бара 354, в `.music` trailing ≈ 286×60pt.
- Пиковая площадь блюра — **два слоя одновременно** на переходе: макс. 286×60pt = 858×180px @3x ≈ **154k px**, чипы 91.552×60pt ≈ 49k px. Гауссов блюр r7 на таком объёме на A19 — единицы десятков микросекунд, это на два порядка меньше уже живущего в проекте `VariableBlur` 402×210pt под лентой.
- Длительность: 0.32s ≈ **38 кадров @120fps**, дальше эффект выключен.
- `.scaleEffect` — чистый CATransform, бесплатен. `.opacity` уже был.
- Гейт из §5 сам по себе ограничивает эффект сменой типа — доп. throttling не нужен.
- **`.drawingGroup()` не добавлять ни в каком виде**: внутри чипа живёт `BackdropBlurView` (UIVisualEffectView с приватным `CAFilter gaussianBlur`, `GlassSurface.swift`), растеризация убьёт backdrop-сэмплинг. `contentTransitionAddsDrawingGroup` тут тоже нерелевантен — он только для `.contentTransition`.

## 8. Отвергнутые альтернативы

- **`GlassEffectContainer` + `.glassEffectID(_:in:)`** (в SDK 26.2 есть: `SwiftUICore.swiftinterface:9168` и `:17668`) — нативный морф между стеклянными объектами, ровно «смена объекта» от Apple. Не подходит: тянет системный Liquid Glass вместо фигмовского рецепта (backdrop-blur 35, заливка white 10%, хайрлайн 0.66pt), пиксель-в-пиксель развалится.
- **Общая живая стеклянная поверхность с морфом формы Capsule ↔ RoundedRectangle** — дало бы литеральный `.transition(.blurReplace)` на контенте внутри. Большая перестройка (AnyShape + анимируемый радиус + разный поворот 0°/4°), сейчас не окупается.

## ЗНАЧЕНИЯ
- API: SwiftUICore.BlurReplaceTransition, @available(iOS 17.0, *), @_originallyDefinedIn(SwiftUI, iOS 18.0) — guard не нужен при таргете iOS 26
- Единственный рабочий вызов: .transition(.blurReplace) / .transition(.blurReplace(.upUp)); ContentTransition.blurReplace и AnyTransition.blurReplace НЕ существуют (проверено swiftc -typecheck на iPhoneSimulator26.2.sdk)
- Нативная формула blurReplace: .opacity(identity ? 1 : 0).blur(radius: identity ? 0 : 7, opaque: false).scaleEffect(scale, anchor: .center)
- scale: identity = 1.0; willAppear = 0.9; didDisappear = 0.9 (.downUp) / 1.1 (.upUp)
- Радиус блюра = 7.0, anchor захардкожен (0.5, 0.5), opaque = false
- Сырые значения: TransitionPhase willAppear=0/identity=1/didDisappear=2; Configuration downUp=0/upUp=1
- Источник констант: /Library/Developer/CoreSimulator/Volumes/iOS_23C54/.../iOS 26.2.simruntime/.../SwiftUICore.framework/SwiftUICore, символ $s7SwiftUI21BlurReplaceTransitionV4body7content5phaseQrAA22PlaceholderContentViewVyACG_AA0E5PhaseOtF @ 0xabbd20
- Правки в /Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/Chrome/ActionBarView.swift: константы после строки 13 (ActionBarMotion); замена .opacity на .blurReplaceLayer на строках 401, 406, 411; модификатор BlurReplaceLayer в секцию Helpers ~строка 606; фикс showMiniPlayer на строке 149
- Новые константы: ActionBarMotion.swapBlurRadius: CGFloat = 7, ActionBarMotion.swapScale: CGFloat = 0.9
- Анимация — существующая ActionBarMotion.morph = .smooth(duration: 0.32); animationKey (строка 135) уже содержит showMiniPlayer/showBookChip/showMovieChip, новый .animation не нужен
- Фикс на строке 149: showMiniPlayer = hasMusic && (mode == .music || mode == .search)
- Пиковая площадь блюра: 286×60pt (плеер) и 91.552×60pt (чип кино) = ~154k и ~49k пикселей @3x; 38 кадров @120fps
- iOS 26 Liquid Glass морф доступен (GlassEffectContainer — SwiftUICore.swiftinterface:9168, glassEffectID — :17668), но отвергнут: ломает фигмовское стекло

## РИСКИ
- Главный риск: .blur(radius:) поверх поддерева с BackdropBlurView (UIVisualEffectView + приватный CAFilter, DesignSystem/GlassSurface.swift) может обнулить backdrop-сэмплинг на время перехода — стекло мигнёт пустотой. Проверка: временно поставить ActionBarMotion.morph = .smooth(duration: 3), прогнать -debugMorphCycle и снять xcrun simctl io booted screenshot в середине перехода. Если backdrop ломается — перенести .blur внутрь, только на ArtworkImage, оставив стеклу голый .opacity (визуально почти неотличимо: у поверхности нет деталей, кроме хайрлайна)
- Блюр r7 выходит за границы кадра. В режиме .book clipTrailing = false (строка 216), поэтому ореол уходящей пилюли на 7pt заедет влево на поле поиска и вниз на таббар. Смотреть на скриншоте; если заметно — обрезать зону .padding(-8).clipped() внутри слота, но НЕ включать clipTrailing в .book (там клип выключен ради уезда при фокусе)
- Кривая должна оставаться без отскока. .smooth = spring bounce 0, блюр монотонно идёт 7 → 0. Если кто-то заменит на .bouncy/.snappy, radius уйдёт в минус на овершуте — тогда обязателен max(0, ...)
- Если добавлять отдельный .animation для свапа, ставить его строго на ZStack (после закрывающей скобки на строке 413), а не после .frame(width:) на 414–416 — иначе морф ширин переедет на вторую кривую и разъедется с левой пилюлей
- Категорически не вешать .id(payload.id) на слои: каждая смена трека/фильма запускала бы блюр-кроссфейд вместо тихого обновления обложки
- Не оборачивать в .drawingGroup()/.compositingGroup() ради «оптимизации» — растеризация убивает UIVisualEffectView backdrop у стекла чипа
- Латентная проблема, которую закрывает .allowsHitTesting(isActive) в модификаторе: слои с opacity 0 в SwiftUI продолжают хит-теститься. Сейчас на чипах нет жестов, но как только появится тап по плееру — невидимая капсула мини-плеера начнёт съедать тапы в режимах .book/.movie
- Верификация после правки — обязательный скриншот симулятора и покадровый разбор записи (по конвенции проекта тайминг 0.32 всё ещё помечен ⏳ в DECISIONS.md:45); новое решение зафиксировать в разделе «Техника» docs/DECISIONS.md