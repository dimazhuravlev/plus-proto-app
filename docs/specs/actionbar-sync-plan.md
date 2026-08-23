Все номера строк — по **текущему** состоянию файлов (`ActionBarView.swift` 762 строки, `BottomChrome.swift` 194). Номера в брифе и во всех трёх предложениях устарели.

═══════════════════════════════════════════
ШАГ 1. /Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/Chrome/BottomChrome.swift
═══════════════════════════════════════════

**1a. `KeyboardObserver` (:153–194) — добавить флаг `isUp` и взять duration из userInfo в willHide.**

```swift
 @Observable
 final class KeyboardObserver {
     private(set) var overlap: CGFloat = 0
+    /// Клавиатура на экране. Отдельный флаг, а не `overlap > 0`: с аппаратной
+    /// клавиатурой (⌘K в симуляторе) overlap равен нулю или высоте панели шорткатов,
+    /// а раскладка бара обязана раскрыться — иначе не появится крест и фокус нечем снять.
+    /// Меняется в том же `withAnimation`, что и `overlap`: обе величины приходят во вью
+    /// одним апдейтом.
+    private(set) var isUp = false
     private var observers: [NSObjectProtocol] = []
```
в `keyboardWillChangeFrame` (:172–174):
```swift
                 withAnimation(.smooth(duration: duration)) {
                     self?.overlap = next
+                    self?.isUp = true
                 }
```
в `keyboardWillHide` (:182–185):
```swift
-            ) { [weak self] _ in
-                withAnimation(.smooth(duration: 0.25)) {
-                    self?.overlap = 0
-                }
+            ) { [weak self] note in
+                // Длительность — из самой клавиатуры, а не константой: обратный переход
+                // обязан совпасть с её кривой так же, как прямой.
+                let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
+                withAnimation(.smooth(duration: duration)) {
+                    self?.overlap = 0
+                    self?.isUp = false
+                }
```

**1b. `BottomChrome.body` (:93–118) — снять оба перехватчика, отдать подъём внутрь бара.**

```swift
     var body: some View {
         VStack(spacing: PlusChromeMetrics.actionBarToTabsGap) {
             // Поднимается только бар. Таббар остаётся на своём месте и уходит
             // под клавиатуру — гасить его не нужно (решение пользователя 2026-08-23).
-            ActionBarView()
-                .offset(y: focusedOffset)
-                .animation(.smooth(duration: 0.25), value: focusedOffset)
+            // Подъём уехал ВНУТРЬ бара: он обязан висеть на общем предке обеих зон
+            // под той же единственной анимацией, что и ширины зон и уезд плеера.
+            ActionBarView(raise: raise)
 
             TabBarView()
                 .allowsHitTesting(!actionBar.isSearchFocused)
         }
-        .animation(ActionBarMotion.morph, value: actionBar.isSearchFocused)
         .ignoresSafeArea(.keyboard)
     }
 
-    private var focusedOffset: CGFloat {
-        guard actionBar.isSearchFocused, keyboard.overlap > 0 else { return 0 }
-        ...
-        return -(keyboard.overlap + PlusChromeMetrics.focusKeyboardGap - barBottomFromScreenBottom)
-    }
+    /// Единственный источник фокусной геометрии бара: и подъём, и ширины зон, и уезд
+    /// плеера считаются отсюда, из ОДНОГО предиката. Драйвер — состояние клавиатуры,
+    /// а не флаг фокуса: так оба края перехода (подъём и опускание) начинаются ровно
+    /// тогда, когда трогается клавиатура, и всё меняется одним апдейтом.
+    /// В приложении одно текстовое поле — поиск; если появится второе, добавить
+    /// `&& actionBar.isSearchFocused` (зафиксировать в DECISIONS).
+    private var raise: ActionBarRaise {
+        guard keyboard.isUp else { return .none }
+        let barBottomFromScreenBottom = PlusChromeMetrics.bottomSafeArea
+            + PlusChromeMetrics.tabsRowHeight
+            + PlusChromeMetrics.actionBarToTabsGap
+        // Формула зазора 12pt не тронута. min(0,) обязателен: с аппаратной клавиатурой
+        // overlap == 0 (или 55pt панели шорткатов) — бар не должен уезжать ВНИЗ.
+        let lift = min(0, -(keyboard.overlap + PlusChromeMetrics.focusKeyboardGap - barBottomFromScreenBottom))
+        return ActionBarRaise(isRaised: true, lift: lift)
+    }
```
Удаление `:104` обязательно вместе с `:99`: `.animation(_:value:)` — предок бара, он обнуляет транзакцию поддерева в тех апдейтах, где его `value` не менялся. Для `TabBarView` он бесполезен — `allowsHitTesting` не анимируется, а собственные анимации таббара живут в TabBarView.

═══════════════════════════════════════════
ШАГ 2. /Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/Chrome/ActionBarView.swift
═══════════════════════════════════════════

**2a. Новый тип-контракт — рядом с `ActionBarMotion`, после :34 (internal, его читает BottomChrome).**

```swift
/// Состояние «бар поднят над клавиатурой». Обе величины считаются в BottomChrome
/// из ОДНОГО предиката и приезжают в бар одним значением — поэтому подъём и
/// раскладка зон физически не могут поменяться в разных апдейтах, а значит
/// и в разных транзакциях. Это и есть гарантия, что бар едет целиком.
struct ActionBarRaise: Equatable {
    var isRaised = false
    var lift: CGFloat = 0
    static let none = ActionBarRaise()
}
```

**2b. `ActionBarGeometry` — после :60 добавить рельеф клипа.**

```swift
    /// На сколько плеер уезжает вправо, скрываясь за кромкой экрана
    static let trailingEscape: CGFloat = 120
+    /// Насколько «распускается» клип правой зоны там, где резать нельзя.
+    /// 120 уезда + половина самого широкого чипа (кино 91.552) + запас.
+    static let trailingClipRelief: CGFloat = 240
```

**2c. `ActionBarView` (:104–160) — принять подъём, свести всё к одной анимации.**

```swift
 struct ActionBarView: View {
+    /// Подъём над клавиатурой. Дефолт нужен для превью.
+    var raise: ActionBarRaise = .none
     @Environment(ActionBarState.self) private var actionBar
     @FocusState private var searchFocused: Bool
     @State private var query = ""
 
     var body: some View {
         let layout = ActionBarLayout(
             mode: actionBar.mode,
             hasMusic: actionBar.music != nil,
-            isSearchFocused: actionBar.isSearchFocused
+            raise: raise
         )
 
-        HStack(spacing: layout.trailingWidth == 0 ? 0 : PlusMetrics.actionBarGap) {
+        // Зазор переехал в padding правой зоны: `spacing` не интерполируется и прыгал
+        // 8→0 в нулевом кадре фокуса, дёргая правую кромку поля.
+        HStack(spacing: 0) {
             SearchPill(
                 layout: layout,
-                isSearchFocused: actionBar.isSearchFocused,
                 searchFocused: $searchFocused,
                 query: $query
             )
 
             TrailingSlot(layout: layout)
         }
-        .animation(ActionBarMotion.morph, value: layout.animationKey)
         .frame(height: PlusMetrics.actionBarHeight)
-        .padding(.horizontal, actionBar.isSearchFocused
-                 ? ActionBarGeometry.focusedScreenMargin
-                 : PlusMetrics.screenMargin)
+        // При фокусе поле расширяется — поля экрана ужимаются с 24 до 16 (`2021:11283`).
+        .padding(.horizontal, layout.screenMargin)
+        .offset(y: layout.lift)
+        // ЕДИНСТВЕННАЯ анимация бара. Порядок обязателен: она оборачивает и HStack,
+        // и падинг, и offset — поэтому ширины зон, уезд плеера, поля 24→16 и подъём
+        // меняются одним апдейтом, одной кривой, с одной точкой старта.
+        // Ключ — сам `layout` (синтезированный ==), а не строка: нельзя «забыть поле»,
+        // и на каждом проходе body больше не строится String.
+        .animation(ActionBarMotion.morph, value: layout)
         .onChange(of: searchFocused) { _, focused in
             actionBar.isSearchFocused = focused
         }
         ... // остальное (:138–158) без изменений
```

**2d. `ActionBarLayout` (:168–285).**

Поля:
```swift
-    let miniPlayerExpanded: Bool           // :178 — мёртвое, читалось только в animationKey
-    let clipTrailing: Bool                 // :181
-    let trailingEscaped: Bool              // :183
-    var animationKey: String { ... }       // :185–187 — удалить целиком
+    /// Фокусная раскладка: поле занимает бар целиком, плеер уезжает за кромку.
+    let isRaised: Bool
+    /// Подъём над клавиатурой — свойство ОБЩЕГО предка обеих зон, а не зоны.
+    let lift: CGFloat
+    let screenMargin: CGFloat
+    /// Зазор между зонами (бывший HStack spacing).
+    let gap: CGFloat
+    /// 0 — клип по границе зоны (эквивалент `.clipped()`); большой — клипа нет.
+    let trailingClipRelief: CGFloat
```

Инициализатор:
```swift
-    init(mode: ActionBarMode, hasMusic: Bool, isSearchFocused: Bool) {
+    init(mode: ActionBarMode, hasMusic: Bool, raise: ActionBarRaise) {
         let compact = PlusMetrics.actionBarCompact
+        isRaised = raise.isRaised
+        lift = raise.lift
+        screenMargin = raise.isRaised ? ActionBarGeometry.focusedScreenMargin : PlusMetrics.screenMargin
 
-        if isSearchFocused {
+        if raise.isRaised {
             searchWidth = nil
             trailingWidth = 0
-            trailingEscaped = true
+            gap = 0
             showMiniPlayer = hasMusic && (mode == .music || mode == .search)
             showBookChip = mode == .book
             showMovieChip = mode == .movie
             placeholderOpacity = 0
             searchIconOnly = false
-            miniPlayerExpanded = false
             trackInfoOpacity = 0
             progressOpacity = 0
-            clipTrailing = false
+            // Клип распущен: нулевая зона срезала бы уезжающий плеер на первом же кадре.
+            trailingClipRelief = ActionBarGeometry.trailingClipRelief
             return
         }
-        trailingEscaped = false
 
         switch mode {
         case .search:
             ...
-            clipTrailing = true
+            trailingClipRelief = 0
             trailingWidth = hasMusic ? compact : 0
+            gap = hasMusic ? PlusMetrics.actionBarGap : 0
 
         case .music:
-            clipTrailing = true
-            trackInfoOpacity = isSearchFocused ? 0 : 1     // :240 — недостижимо
-            progressOpacity  = isSearchFocused ? 0 : 1     // :241
-            if isSearchFocused || !hasMusic {              // :243
+            trailingClipRelief = 0
+            // Фокус перехвачен ранним return выше — здесь isSearchFocused недостижим.
+            trackInfoOpacity = 1
+            progressOpacity = 1
+            if !hasMusic {
                 searchIconOnly = false
                 placeholderOpacity = 1
                 searchWidth = nil
-                trailingWidth = hasMusic ? compact : 0
+                trailingWidth = 0
+                gap = 0
             } else {
                 searchIconOnly = true
                 placeholderOpacity = 0
                 searchWidth = compact
                 trailingWidth = nil
+                gap = PlusMetrics.actionBarGap
             }
 
         case .book:
             ...
             trailingWidth = ActionBarGeometry.bookChipAABBWidth
-            clipTrailing = false
+            gap = PlusMetrics.actionBarGap
+            // AABB повёрнутого чипа книги 62.9pt в зоне 60pt — вертикальный клип его срежет.
+            trailingClipRelief = ActionBarGeometry.trailingClipRelief
 
         case .movie:
             ...
             trailingWidth = ActionBarGeometry.movieChipAABBWidth
-            clipTrailing = true
+            gap = PlusMetrics.actionBarGap
+            trailingClipRelief = 0
         }
     }
```
`trailingClipRelief == 0` побитово эквивалентен нынешнему `.clipped()`, большой рельеф — нынешнему «клипа нет». Поведение по режимам не меняется ни на пиксель.

**2e. Новая фигура клипа — рядом с `TrailingSlot` (перед :445).**

```swift
/// Клип правой зоны без ветвления. `relief == 0` — эквивалент `.clipped()`,
/// большой рельеф = клипа фактически нет.
/// Рельеф НЕ анимируется (`EmptyAnimatableData`): иначе на первых кадрах фокуса
/// клип ещё тугой и срезает уезжающий плеер.
private struct TrailingClipShape: Shape {
    var relief: CGFloat
    var animatableData: EmptyAnimatableData {
        get { EmptyAnimatableData() }
        set {}
    }
    func path(in rect: CGRect) -> Path { Path(rect.insetBy(dx: -relief, dy: -relief)) }
}
```

**2f. `TrailingSlot` (:474–483) — снять `_ConditionalContent`. Это и есть исправление дефекта.**

```swift
         .frame(maxWidth: layout.trailingWidth == nil ? .infinity : nil)
         .frame(width: layout.trailingWidth)
         .frame(height: PlusMetrics.actionBarHeight)
-        .offset(x: layout.trailingEscaped ? ActionBarGeometry.trailingEscape : 0)
-        .opacity(layout.trailingEscaped ? 0 : 1)
-        .if(layout.clipTrailing) { view in
-            view.clipped()
-        }
+        .offset(x: layout.isRaised ? ActionBarGeometry.trailingEscape : 0)
+        .opacity(layout.isRaised ? 0 : 1)
+        // Уехавший плеер остаётся живым в дереве — гасим хит-тест явно.
+        .allowsHitTesting(!layout.isRaised)
+        // Клип без ветвления. `.if(...)` переключал ветку `_ConditionalContent`:
+        // SwiftUI удалял ВСЮ правую зону (она переставала участвовать в раскладке,
+        // замирала в последней геометрии и гасла) и вставлял новую, рождённую уже
+        // с offset(x: 120) и opacity 0. Поэтому плеер не ехал ни вверх, ни вправо.
+        .clipShape(TrailingClipShape(relief: layout.trailingClipRelief))
+        // Бывший HStack(spacing:): как padding зазор интерполируется, а spacing прыгал.
+        .padding(.leading, layout.gap)
```
Позиция клипа сохранена (после `offset`/`opacity`), поэтому при `relief == 0` картинка идентична нынешней.

**2g. `SearchPill` (:289–397) — развести «геометрию» и «сырой фокус ввода».**

```swift
 private struct SearchPill: View {
     let layout: ActionBarLayout
-    let isSearchFocused: Bool
     @FocusState.Binding var searchFocused: Bool
```
- :326 `input.opacity(isSearchFocused ? 1 : 0)` → `.opacity(searchFocused ? 1 : 0)` — каретка и набранный текст видны сразу, даже если клавиатура не пришла;
- :329 `if isSearchFocused { clearButton ... }` → `if layout.isRaised { ... }` — крест влияет на раскладку, обязан ехать общей транзакцией;
- в `placeholderStack`: `SearchPlaceholderTicker(isPaused: isSearchFocused)` → `isPaused: layout.isRaised` — пауза совпадает с гашением плейсхолдера;
- :352 `.onChange(of: isSearchFocused)` → `.onChange(of: searchFocused)`;
- :364 и :372 `guard !isSearchFocused` → `guard !searchFocused` (жест должен реагировать на сырой фокус мгновенно).

**2h. Удалить хелпер `View.if(_:transform:)` (:824–833) целиком.** Единственный вызов был на :481. Пока хелпер лежит в файле, ветвление вернётся. Зафиксировать в DECISIONS: «`.if(...)` вокруг анимируемого поддерева запрещён — меняет идентичность».

═══════════════════════════════════════════
ШАГ 3 (опциональный, ТОЛЬКО по замеру). Кривая фокуса = кривая клавиатуры
═══════════════════════════════════════════
После шага 1–2 фокусный переход едет `.smooth(0.32)` (единая с морфом режимов) и стартует ровно в кадре клавиатуры. Ожидаемый остаточный «нырок» под клавиатуру — единицы pt вместо нынешних 54.6. Если замер (метрика 5) даст > 4pt, добавить в `KeyboardObserver`:

```swift
    /// Кривая текущего перехода клавиатуры. nil — клавиатура не в движении,
    /// бар едет своим морфом режимов.
    private(set) var motion: Animation?
    private var settle: Task<Void, Never>?

    @MainActor private func drive(overlap next: CGFloat, up: Bool, duration: Double) {
        let curve = Animation.smooth(duration: duration)
        motion = curve                       // ДО withAnimation: body увидит новую кривую
        withAnimation(curve) { overlap = next; isUp = up }
        settle?.cancel()
        settle = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            self?.motion = nil
        }
    }
```
`ActionBarRaise` получает поле `var motion: Animation? = nil` (Animation Equatable), BottomChrome кладёт туда `keyboard.motion`, а в баре:
```swift
.animation(raise.motion ?? ActionBarMotion.morph, value: layout)
```
Так морф режимов остаётся на выверенных 0.32, а фокусный переход берёт длительность клавиатуры в **обе** стороны. Второго аниматора при этом не появляется — модификатор по-прежнему один.