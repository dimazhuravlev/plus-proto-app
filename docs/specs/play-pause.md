# Спецификация: рабочая кнопка play/pause в мини-плеере action bar

Файлы: `/Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/Chrome/ActionBarView.swift` (правки), `/Users/dimazhuravlev/Repos/plus-proto-app/PlusProtoApp/State/ActionBarState.swift` (одна константа), новый ассет `PlusProtoApp/Assets.xcassets/iconPlay.imageset/`.

---

## 1. Что берём из MusicPlayer и что сознательно НЕ берём

Изучены: `MiniPlayerV2.swift` (визуал, таппы — no-op), `MiniPlayer.swift` (единственное место, где вращение реально связано с `isPlaying`), `RotatingCoverDemo.swift` (инерция), `PlayPauseButton.swift`, `AnimatedIconButton.swift`, `NowPlayingState.swift`.

**Берём (идею, не код):**
- Кросс-поп смены иконки из `AnimatedIconButton`: обе иконки всегда в дереве, уходящая уезжает в `scale 0.4 + opacity 0`, приходящая приезжает из `0.4 → 1`. Пружина `.spring(response: 0.3, dampingFraction: 0.6)`.
- Хаптика `UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 1.0)` — ровно то, что стоит на play/pause в `AnimatedIconButton.swift:54-55` и `PlayPauseButton.swift:48-49`.
- Опционально: выбег обложки после паузы (`MiniPlayer.swift:51-64`, `RotatingCoverDemo.swift:41-46`) — но переписанный в замкнутую форму, см. §6.

**НЕ берём (и почему):**
- ❌ Накопление угла в `@State` из `onChange(of: timeline.date)` (`MiniPlayerV2.swift:43-48`, `MiniPlayer.swift:47-56`) — это тот самый паттерн, который в нашем проекте вешал рендер на 100% CPU. Остаётся якорь.
- ❌ `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { onTap() }` из `AnimatedIconButton.swift:63-67` — откладывает смену модели на 100 мс после тапа: обложка ещё 100 мс крутилась бы после нажатия «пауза». Модель меняем синхронно, анимируем только визуал.
- ❌ `@State iconOpacity` / `@State iconScale` — дублируют то, что уже выражает `isPlaying`. Один драйвер вместо трёх.
- ❌ `blendDuration: 0.5` в пружине — на opacity/scale не работает, шум.
- ❌ `backgroundScale` + круг-подложка из `PlayPauseButton.swift` — в макете за иконкой нет круга; пресс-стейт даёт `PressScaleButtonStyle` (уже есть в проекте, и он корректно снимается при скролле — см. комментарий `GlassIconButton.swift:69-70`).
- ❌ `CHHapticEngine` + `stoppedHandler` + континуальный 0.5 с рамбл на старте (`MiniPlayer.swift:105-151`) — много машинерии ради одного эффекта, конфликтует с impact-картой таббара.
- ❌ Лерп скорости `currentSpeed += (target - currentSpeed) * 0.04` — зависит от частоты кадров (на 120 Гц тормозит вдвое быстрее, чем на 60) и требует @State-накопления. Если делаем выбег — только замкнутой формой, §6.
- ❌ `NowPlayingState` целиком — там `ObservableObject` + `AudioPlayerManager` + `UserDefaults`-персист. У нас `@Observable ActionBarState` с уже готовыми `isMusicPlaying` / `musicProgress` / `isMusicLiked`, живого аудио нет.

---

## 2. Ассет иконки play

**В Figma-файле `0HzFEKtm9oYdkksrDg7U14` иконки play нет вообще.** Проверено: снят полный metadata секции `2004:10700` и мини-плеера `2001:111011`. Фрейм `actions` (`I2001:111011;741:53214`, w=66) содержит ровно четыре инстанса: `icon / love` (`I2001:111011;2127:128`, x=0), `icon / pause` (`I2001:111011;742:44123`, x=42), плюс скрытые `icon / casting-music` (`I2001:111011;742:44129`) и `icon / cross` (`I2001:111011;742:44058`). Мастер мини-плеера `4353:2068` лежит в подключённой библиотеке и в этом файле не резолвится.

Правильный путь (нужен доступ к библиотеке или дизайнер): положить `icon / play` из того же набора рядом с action bar в файле и выгрузить по node ID. Найденные кандидаты (`search_design_system`):
- «🦄 Ядро / Иконки» → `icon / play`, componentKey `0cbf90aca8c163bbdb6f19960924f76af36dfa26` (там же `icon / pause` = `06ee586e8de5a4ca75153527af857fe963a3e04a`)
- «🦄 Графика» → `icon / play`, componentKey `0587183369b068080afb0fa9cc28a37e588033ed` (там же `icon / pause` = `2cb7617874c71b896067bdb22cf58716e9de2287`)

**Фолбэк, пригодный прямо сейчас** (обоснован метрикой соседа по строке, а не на глаз): в 24-боксе `icon / pause` = 13.5 × 16.5 (инсеты V 15.63 % / H 21.88 % — подтверждено `get_design_context`). Play в этом семействе — острый равносторонний треугольник вершиной вправо (у MusicPlayer `play.imageset/icon.svg` лист 20 × 23, w/h = 0.8696 ≈ √3/2 = 0.8660). Берём **ту же высоту, что у pause** и равносторонний обвод:

- высота 16.5, ширина 16.5 × √3/2 = **14.2894**
- в боксе 24: инсеты V 3.75 (15.63 %, как у pause), H 4.8553 (20.23 %)

Файл `PlusProtoApp/Assets.xcassets/iconPlay.imageset/iconPlay.svg` (экспорт по границам листа — конвенция проекта, `glyphSize(of:box:)` сам подхватит натуральный размер, в коде числа не нужны):
```svg
<svg xmlns="http://www.w3.org/2000/svg" width="14.2894" height="16.5" viewBox="0 0 14.2894 16.5" fill="none">
<path d="M14.2894 8.25L0 16.5V0L14.2894 8.25Z" fill="#FFFFFF"/>
</svg>
```
`Contents.json` — копия `iconPause.imageset/Contents.json`: `"preserves-vector-representation": true`, `"template-rendering-intent": "template"`, одна запись `{"filename": "iconPlay.svg", "idiom": "universal"}`.

Ассет не выгружаю в каталог проекта — как договорено.

---

## 3. Константы (в `enum ActionBarMotion`, ActionBarView.swift:7-19)

```swift
/// Кросс-поп смены play/pause — идея AnimatedIconButton MusicPlayer,
/// но без DispatchQueue: обе иконки в дереве, драйвер один — isPlaying.
static let iconSwap: Animation = .spring(response: 0.3, dampingFraction: 0.6)
/// Масштаб уходящей иконки (AnimatedIconButton: 0.4)
static let iconSwapScale: CGFloat = 0.4
/// Хаптика транспорта — impact light, как play/pause в MusicPlayer
static let transportHapticIntensity: CGFloat = 1.0
/// Шаг тика прогресса; им же меряется линейная интерполяция заливки
static let progressTick: Double = 0.5
```

В `ActionBarState`:
```swift
/// Мок-длительность трека: живого аудио в прототипе нет, прогресс тикает от неё.
static let mockTrackDuration: TimeInterval = 210
```

---

## 4. Кнопка — точный псевдокод

`MiniPlayerPill` получает колбэк (остаётся «глупой» и превьюшной, `ActionBarState` в неё не тащим):

```swift
private struct MiniPlayerPill: View {
    let item: MusicNowPlaying
    let trackInfoOpacity: Double
    let progressOpacity: Double
    let progress: Double
    let isPlaying: Bool
    let isLiked: Bool
    let onTogglePlay: () -> Void          // ← новое
    @State private var spin = CoverSpin()  // ← вместо spinAnchor/spinBaseDegrees
```

`TrailingSlot` (ActionBarView.swift:393-400):
```swift
MiniPlayerPill(
    item: music,
    trackInfoOpacity: layout.trackInfoOpacity,
    progressOpacity: layout.progressOpacity,
    progress: actionBar.musicProgress,
    isPlaying: actionBar.isMusicPlaying,
    isLiked: actionBar.isMusicLiked,
    onTogglePlay: { actionBar.isMusicPlaying.toggle() }
)
```

Строка действий (заменяет ActionBarView.swift:525-530):
```swift
private var actions: some View {
    HStack(spacing: ActionBarGeometry.miniPlayerActionsGap) {
        actionIcon("iconHeart", liked: isLiked)
        playPauseButton
    }
    // В book/movie плеер остаётся в дереве с opacity 0, а прозрачные вью в SwiftUI
    // всё равно ловят тап — гасим хит-тест вместе с подписями.
    .allowsHitTesting(trackInfoOpacity == 1)
}

private var playPauseButton: some View {
    Button {
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred(intensity: ActionBarMotion.transportHapticIntensity)
        // Угол фиксируем/возобновляем в том же апдейте, что и смену состояния,
        // чтобы кадр не отрисовался со старым базовым углом. Сеттер идемпотентен,
        // поэтому onChange ниже отработает вхолостую.
        spin.set(spinning: !isPlaying)
        onTogglePlay()
    } label: {
        ZStack {
            actionIcon("iconPlay")
                .opacity(isPlaying ? 0 : 1)
                .scaleEffect(isPlaying ? ActionBarMotion.iconSwapScale : 1)
            actionIcon("iconPause")
                .opacity(isPlaying ? 1 : 0)
                .scaleEffect(isPlaying ? 1 : ActionBarMotion.iconSwapScale)
        }
        .animation(ActionBarMotion.iconSwap, value: isPlaying)
        // Хит-зона 40×44 при неизменной раскладке 24×24: отрицательный padding
        // возвращает кадру исходный размер, contentShape остаётся большим.
        .padding(.horizontal, 8).padding(.vertical, 10)
        .contentShape(.rect)
        .padding(.horizontal, -8).padding(.vertical, -10)
    }
    .buttonStyle(PressScaleButtonStyle())
    .accessibilityLabel(isPlaying ? "Пауза" : "Играть")
}
```

Почему хит-зона именно 40 × 44: центры боксов ♥ и ⏸ разнесены на 24 + 18 = 42 pt, две зоны по 40 оставляют между собой 2 pt — сердце, когда его тоже сделают кнопкой, не будет конфликтовать. По вертикали фрейм `actions` центрирован в пилюле 60 pt, 44 pt укладываются в [8; 52].

Корень пилюли (ActionBarView.swift:457): `.accessibilityElement(children: .combine)` → **`.contain`**, иначе VoiceOver проглотит кнопку.

---

## 5. Связь с вращением — что менять и почему

Текущая логика через якорь **корректна по существу**: `onChange(of: isPlaying)` срабатывает независимо от того, кто поменял флаг, так что кнопка её не сломает. Но она не идемпотентна, и при добавлении второго источника изменений (тап) это становится опасно. Замена `spinAnchor`/`spinBaseDegrees` на одну структуру:

```swift
/// Угол обложки — чистая функция от времени, а не накапливаемое состояние.
/// Запись @State из onChange(of: timeline.date) (MusicPlayer MiniPlayerV2/MiniPlayer)
/// даёт бесконечный цикл перерисовки и вешает экран — не переносим.
private struct CoverSpin {
    /// Угол на момент старта текущей фазы
    var base: Double = 0
    /// Начало фазы; nil — обложка стоит
    var anchor: Date?

    var isSpinning: Bool { anchor != nil }

    func degrees(at date: Date) -> Double {
        guard let anchor else { return base }
        let elapsed = date.timeIntervalSince(anchor)
        return (base + elapsed * ActionBarMotion.coverDegreesPerSecond)
            .truncatingRemainder(dividingBy: 360)
    }

    /// Идемпотентно: повторный вызов с тем же состоянием угол не двигает.
    mutating func set(spinning: Bool, at date: Date = .now) {
        guard spinning != isSpinning else { return }
        if spinning { anchor = date } else { base = degrees(at: date); anchor = nil }
    }
}
```

```swift
private var cover: some View {
    Group {
        if spin.isSpinning {
            TimelineView(.animation) { timeline in
                coverImage.rotationEffect(.degrees(spin.degrees(at: timeline.date)))
            }
        } else {
            coverImage.rotationEffect(.degrees(spin.base))
        }
    }
    // Внешние источники: карточка витрины (ActionBarState.open) и -debugMorphCycle.
    .onChange(of: isPlaying) { _, playing in spin.set(spinning: playing) }
    // Холодный старт: -debugActionBar search поднимает бар уже с isMusicPlaying = true.
    .task { spin.set(spinning: isPlaying) }
    .frame(width: PlusMetrics.miniPlayerCover, height: PlusMetrics.miniPlayerCover)
    .clipShape(Circle())
    .overlay { Circle().strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }
}
```
`spinDegrees(at:)` (ActionBarView.swift:505-509) удаляется — переехал в `CoverSpin.degrees`.

Важно: `.task { spin.set(spinning: isPlaying) }` обязателен. Сейчас `spinAnchor` инициализируется `.now` в объявлении, и ветка TimelineView выбирается по `isPlaying`; в новой схеме `anchor` стартует как `nil`, и без этой строки пилюля, появившаяся уже играющей, стояла бы.

---

## 6. Опционально: выбег обложки (то самое «инерционное» ощущение из MusicPlayer)

Требование задачи — «останавливается на текущем угле» — выполняется без этого. Но именно выбег делает кавер похожим на замедляющуюся пластинку. Замкнутая форма вместо покадрового лерпа:

- ω = 18 °/с (`ActionBarMotion.coverDegreesPerSecond`)
- τ = 0.42 с — эквивалент лерпа MusicPlayer `k = 0.04` на 60 Гц: τ = Δt/k = (1/60)/0.04 = 0.4167 с (константа MusicPlayer зависит от fps, τ — нет)
- φ(t) = base + ω·τ·(1 − e^(−t/τ)), полный выбег ω·τ = **7.5°**, оседание 5τ = **2.1 с**

Реализация: в `CoverSpin` добавить фазу `coasting` (anchor ≠ nil при spinning == false), а окончание выбега снять одним `.task(id:)` со `sleep(for: .seconds(2.1))`, который выставляет `base = (base + 7.5) % 360; anchor = nil` — точное конечное значение, снапа нет. Один таймер на паузу, не на кадр. Разгона нет: MusicPlayer на старте прыгает на полную скорость (`MiniPlayer.swift:60-63`), что ровно равно текущему поведению — на play менять нечего.

---

## 7. Прогресс — да, тикать стоит

Замерший прогресс рядом с крутящейся обложкой читается как поломка, и он же — второй визуальный маркер паузы. Дёшево по кадрам это делается **не таймером на кадр, а редким тиком + линейной интерполяцией**: 2 обновления состояния в секунду, промежуточные кадры дорисовывает анимация трансформа, `body` не пересчитывается.

В `ActionBarView.body`, рядом с существующим DEBUG `.task` (идиома уже в файле — `SearchPlaceholderTicker`, ActionBarView.swift:357-380):
```swift
.task(id: actionBar.isMusicPlaying) {
    guard actionBar.isMusicPlaying else { return }
    let step = ActionBarMotion.progressTick / ActionBarState.mockTrackDuration  // 1/420
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(ActionBarMotion.progressTick))
        guard !Task.isCancelled else { return }
        let next = actionBar.musicProgress + step
        if next >= 1 {
            actionBar.musicProgress = 1
            actionBar.isMusicPlaying = false   // трек кончился — обложка встаёт, иконка становится ▶
            return
        }
        actionBar.musicProgress = next
    }
}
```

В `MiniPlayerProgressFill` (ActionBarView.swift:559) заменить `.easeOut(duration: 0.12)`: за 0.12 с шаг не успевает размазаться по интервалу и заливка идёт ступеньками.
```swift
// Линейная интерполяция ровно на шаг тика — между обновлениями кадры дорисовывает
// анимация трансформа, body не пересчитывается. nil на сбросе: startMusic обнуляет
// прогресс, и не хватало только 0,5 с обратного пробега заливки.
.animation(progress > 0 ? .linear(duration: ActionBarMotion.progressTick) : nil, value: progress)
```

Масштаб движения: в режиме music пилюля ≈ 284 pt, трек 210 с → 1.35 pt/с. После паузы уже выданная анимация докатывает ≤ 0.7 pt — ниже порога заметности.

Отдельно: комментарий `ActionBarState.swift:66-68` обещает, что тик прогресса не инвалидирует обложку и подписи, но `TrailingSlot.body` читает `actionBar.musicProgress` и передаёт вниз как `let`, поэтому перерисовывается вся пилюля. Чтобы обещание выполнялось, `MiniPlayerProgressFill` должен читать состояние сам через `@Environment(ActionBarState.self)`, а `progress` из инициализатора `MiniPlayerPill` убрать. При 2 тиках/с это не горит, но это ровно то, ради чего свойства разносили.

## ЗНАЧЕНИЯ
- Новый ассет: PlusProtoApp/Assets.xcassets/iconPlay.imageset/iconPlay.svg — лист 14.2894 × 16.5, path "M14.2894 8.25L0 16.5V0L14.2894 8.25Z", fill #FFFFFF
- Contents.json для iconPlay: preserves-vector-representation: true, template-rendering-intent: template
- Геометрия play в боксе 24: инсеты V 3.75 (15.63%), H 4.8553 (20.23%); высота равна pause (16.5), ширина = 16.5·√3/2
- Figma: icon/pause = I2001:111011;742:44123, вектор ;19:2276, 24×24, инсеты 15.63% V / 21.88% H → 13.5×16.5
- Figma: icon/love = I2001:111011;2127:128, 24×24 → глиф 20.0 × 17.78
- Figma: фрейм actions = I2001:111011;741:53214, w=66 = 24 + 18 + 24; love x=0, pause x=42
- Иконки play в файле 0HzFEKtm9oYdkksrDg7U14 НЕТ — проверен полный metadata секции 2004:10700 и мини-плеера 2001:111011
- Кандидаты из библиотек: «🦄 Ядро / Иконки» icon/play componentKey 0cbf90aca8c163bbdb6f19960924f76af36dfa26; «🦄 Графика» icon/play componentKey 0587183369b068080afb0fa9cc28a37e588033ed
- Мастер мини-плеера 4353:2068 в файле не резолвится (лежит в подключённой библиотеке)
- ActionBarMotion.iconSwap = .spring(response: 0.3, dampingFraction: 0.6)
- ActionBarMotion.iconSwapScale = 0.4
- ActionBarMotion.transportHapticIntensity = 1.0, стиль .light (UIImpactFeedbackGenerator)
- ActionBarMotion.progressTick = 0.5 (сек)
- ActionBarState.mockTrackDuration = 210 (сек), шаг прогресса = 0.5/210 = 1/420
- MiniPlayerProgressFill: .easeOut(duration: 0.12) → progress > 0 ? .linear(duration: 0.5) : nil
- Хит-зона кнопки: .padding(.horizontal, 8).padding(.vertical, 10).contentShape(.rect).padding(.horizontal, -8).padding(.vertical, -10) → 40×44 при раскладке 24×24
- Зазор между хит-зонами ♥ и ⏸ при ширине 40: 2 pt (центры разнесены на 42)
- Выбег обложки (опция): ω = 18 °/с, τ = 0.42 с, полный выбег 7.5°, оседание 5τ = 2.1 с, φ(t) = base + ω·τ·(1 − e^(−t/τ))
- τ = 0.42 выведено из лерпа MusicPlayer k = 0.04 на 60 Гц: τ = (1/60)/0.04 = 0.4167
- MiniPlayerPill: + let onTogglePlay: () -> Void; @State spinAnchor/spinBaseDegrees → @State spin = CoverSpin()
- ActionBarView.swift:457 .accessibilityElement(children: .combine) → .contain
- ActionBarView.swift:505-509 spinDegrees(at:) удаляется, переезжает в CoverSpin.degrees(at:)
- actions: + .allowsHitTesting(trackInfoOpacity == 1)
- accessibilityLabel кнопки: isPlaying ? "Пауза" : "Играть"
- Скорость движения заливки в music: ≈284 pt / 210 с = 1.35 pt/с; докат после паузы ≤ 0.7 pt

## РИСКИ
- Иконки play нет в Figma-файле прототипа. Предложенный SVG — обоснованная реконструкция (та же высота, что у pause, равносторонний обвод как у play в MusicPlayer), а не замер макета. Для строгого пиксель-в-пиксель нужно, чтобы дизайнер положил icon / play из библиотеки рядом с action bar, после чего ассет переэкспортировать по node ID.
- Идемпотентность CoverSpin.set(spinning:) — обязательное условие. Тап вызывает set() до смены состояния, а onChange(of: isPlaying) вызовет его же после. Без guard угол на паузе применится дважды и обложка прыгнет вперёд на величину elapsed.
- Без .task { spin.set(spinning: isPlaying) } пилюля, появившаяся уже играющей (-debugActionBar search выставляет isMusicPlaying = true), стоять будет намертво: anchor стартует как nil. В текущем коде это работало за счёт инициализации spinAnchor = .now прямо в объявлении.
- Прозрачные вью в SwiftUI продолжают ловить тапы (это не UIKit alpha=0). В режимах book/movie мини-плеер остаётся в дереве с opacity 0, а при mode == .book у TrailingSlot ещё и clipTrailing == false — невидимая кнопка перекрыла бы область чипа книги. Отсюда .allowsHitTesting(trackInfoOpacity == 1); проверить на симуляторе тапом по чипу книги.
- Порядок onChange относительно body: если SwiftUI успевает закоммитить кадр между пересчётом body и срабатыванием onChange, на паузе мелькнёт кадр со старым базовым углом. Перенос фиксации угла в обработчик тапа снимает риск для кнопки, но для внешнего пути (карточка витрины) он остаётся — проверить покадрово записью simctl.
- Отрицательный padding для расширения хит-зоны: убедиться, что 40×44 не срезается clipShape(Capsule) пилюли и .clipped() у TrailingSlot при clipTrailing == true. По вертикали 44 укладывается в 60, по горизонтали кнопка отстоит от правого края на padding 18 — запас есть, но проверить тапом у самой кромки.
- Тик прогресса пишет в actionBar из .task — это MainActor через наследование от вью, но при переносе задачи в другое место (например, в TrailingSlot) изоляцию надо перепроверить.
- При обнулении musicProgress в startMusic() анимация должна быть nil, иначе заливка 0.5 с едет назад. Условие progress > 0 ? ... : nil опирается на новое значение — проверить, что сброс действительно мгновенный.
- Соседний по строке дефект (вынесен отдельной задачей, не входит в эту правку): iconHeart в мини-плеере рендерится 16.67×14.81 вместо макетных 20.0×17.78 — ассет экспортирован под бокс 20 круглой кнопки, отношение ровно 20/24.
- Выбег обложки (§6) — единственная часть спеки, требующая новой фазы состояния и .task(id:) на 2.1 с. Если приоритет — минимальный диф, его можно не делать: требование «останавливается на текущем угле» выполняется и без него.