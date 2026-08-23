import SwiftUI
import UIKit

// MARK: - Motion

/// Тайминги морфа action bar. Подбираются записью simctl + покадровый разбор.
enum ActionBarMotion {
    /// Морф ширин и opacity между четырьмя режимами.
    static let morph: Animation = .smooth(duration: 0.32)
    /// Кросс-смена плейсхолдера поиска (шаг 42pt = lh 26 + gap 16).
    static let placeholderStep: Animation = .smooth(duration: 0.45)
    /// Дискретная смена троеточия 1→2→3.
    static let ellipsisStep: Animation = .smooth(duration: 0.2)
    /// Интервал ротации плейсхолдера (открытый вопрос — стартовое значение 4s).
    static let placeholderInterval: Duration = .seconds(4)
    static let ellipsisInterval: Duration = .milliseconds(500)
    /// Установившаяся скорость вращения обложки, °/с.
    static let coverDegreesPerSecond: Double = 18
    /// Инерция диска: постоянная времени разгона и торможения (см. `CoverSpin`).
    /// Асимметрия намеренная — подхватывает быстро, докатывается долго, так читается
    /// маховик. Недобор угла на старте ω·τ = 6.3°, выбег после паузы ω·τ = 21.6°.
    static let coverSpinUp: Double = 0.35
    static let coverSpinDown: Double = 1.2
    /// Ниже этой остаточной скорости движение неразличимо — диск считается вставшим.
    static let coverSpinEpsilon: Double = 1.0

    /// Смена типа плеера (музыка ↔ книга ↔ кино) — кроссфейд с блюром.
    /// Числа взяты из нативного `BlurReplaceTransition(.downUp)`: opacity 0, blur 7,
    /// scale 0.9, anchor .center. Сам `.transition(.blurReplace)` здесь не годится —
    /// он удаляет вью из дерева, а уходящий плеер обязан продолжать сжиматься
    /// вместе с зоной, иначе замирает на своей ширине и наезжает на поле поиска.
    static let swapBlurRadius: CGFloat = 7
    static let swapScale: CGFloat = 0.9

    /// Кросс-поп смены play↔pause — идея `AnimatedIconButton` из MusicPlayer:
    /// обе иконки в дереве, уходящая утапливается, приходящая выныривает.
    static let iconSwap: Animation = .spring(response: 0.3, dampingFraction: 0.6)
    static let iconSwapScale: CGFloat = 0.4
    /// Хаптика транспорта — impact light, как на play/pause в MusicPlayer.
    static let transportHapticIntensity: CGFloat = 1.0
}

/// Состояние «бар поднят над клавиатурой». Обе величины считаются в BottomChrome
/// из ОДНОГО предиката и приезжают в бар одним значением — поэтому подъём и
/// раскладка зон физически не могут поменяться в разных апдейтах, а значит
/// и в разных транзакциях. Это и есть гарантия, что бар едет целиком.
struct ActionBarRaise: Equatable {
    var isRaised = false
    var lift: CGFloat = 0
    static let none = ActionBarRaise()
}

// MARK: - Geometry

/// Числа из figma-actionbar §4, которых нет в Tokens.swift.
/// Не `private`: внутреннюю раскладку мини-плеера читает `FullScreenPlayer` —
/// морф стартует ровно из кадра его обложки.
enum ActionBarGeometry {
    static let searchExpandedWidth: CGFloat = 284
    static let searchPaddingH: CGFloat = 18
    static let searchIconBox: CGFloat = 24
    static let placeholderRowStep: CGFloat = 42
    static let miniPlayerPaddingLeading: CGFloat = 6
    static let miniPlayerPaddingTrailing: CGFloat = 18
    /// Зазор тексты ↔ кнопки
    static let miniPlayerContentGap: CGFloat = 12
    /// Зазор обложка ↔ тексты. В макете он меньше, чем до кнопок.
    static let miniPlayerCoverGap: CGFloat = 8
    static let miniPlayerActionsGap: CGFloat = 18
    static let bookChipSize = CGSize(width: 44, height: 60)
    static let bookCoverSize = CGSize(width: 36, height: 52)
    /// AABB повёрнутого чипа книги — ширина для раскладки HStack.
    static let bookChipAABBWidth: CGFloat = 48.078
    static let movieChipSize = CGSize(width: 88, height: 54)
    static let movieChipPadding: CGFloat = 4
    static let movieFrameSize = CGSize(width: 80, height: 46)
    static let movieChipAABBWidth: CGFloat = 91.552
    static let chipRotation: Double = 4
    /// Поля бара в фокусе — поле поиска расширяется на 8pt с каждой стороны
    static let focusedScreenMargin: CGFloat = 16
    /// На сколько плеер уезжает вправо, скрываясь за кромкой экрана
    static let trailingEscape: CGFloat = 120
}

/// Резина свайпа по полю поиска. Формула из UIScrollView: f(x) = (x·d·c)/(d + c·x),
/// где d — асимптота отклика, c — начальная скорость. В нормированном виде это
/// p(x) = x/(x + d/c) ∈ [0,1): один прогресс на кадр, высота и ширина считаются от него,
/// поэтому синхронны по построению.
private enum SearchPullConfig {
    /// Слоп распознавания: до него живёт тап, резина ещё не тянется.
    static let activation: CGFloat = 8
    /// c из UIScrollView — доля хода пальца, которую капсула отдаёт на старте.
    static let rate: CGFloat = 0.55
    /// d по высоте: капсула 60 тянется максимум до 70.
    static let heightLimit: CGFloat = 10
    /// d по ширине: 16pt — около 4.5% ширины поля. Честное сохранение объёма дало бы
    /// 50pt сжатия при той же высоте, это карикатура.
    static let widthLimit: CGFloat = 16
    /// Путь пальца, на котором резина натянута наполовину.
    static let halfway: CGFloat = heightLimit / rate

    /// Порог фокуса по пути пальца вверх.
    static let triggerDistance: CGFloat = 44
    /// Короткий резкий рывок открывает поиск, не дотягивая до порога.
    static let flickVelocity: CGFloat = 500
    static let flickMinDistance: CGFloat = 16
    /// Гистерезис, чтобы хаптика не дребезжала на границе порога.
    static let triggerHysteresis: CGFloat = 8
    static let tickHapticIntensity: CGFloat = 0.45

    /// Отпустили, не дотянув: возврат с едва заметной отдачей ~11%.
    static let release: Animation = .spring(duration: 0.32, bounce: 0.42)

    /// Нормированное натяжение 0…1.
    static func progress(travel: CGFloat) -> CGFloat {
        let x = max(0, travel - activation)
        return x / (x + halfway)
    }
}

// MARK: - Root

/// Action bar: высота 60, поля 24, две зоны с зазором 8 во всю ширину бара
/// (figma-actionbar §4). Один persistent HStack — ширины и opacity анимируются
/// на живых вью, скрытые слои остаются в дереве с opacity 0.
struct ActionBarView: View {
    /// Подъём над клавиатурой. Дефолт нужен для превью.
    var raise: ActionBarRaise = .none
    @Environment(ActionBarState.self) private var actionBar
    @FocusState private var searchFocused: Bool
    @State private var query = ""

    var body: some View {
        let layout = ActionBarLayout(
            mode: actionBar.mode,
            hasMusic: actionBar.music != nil,
            raise: raise
        )

        // Зазор переехал в padding правой зоны: `spacing` не интерполируется и прыгал
        // 8→0 в нулевом кадре фокуса, дёргая правую кромку поля.
        //
        // Поля экрана принадлежат зонам, а не бару: сам бар — во всю ширину экрана.
        // Общий `padding(.horizontal)` на баре загонял уезжающий плеер в чужую
        // систему координат, и он скрывался в чёрной полосе отступа вместо кромки
        // экрана. Значения полей не изменились: 24 в покое, 16 в фокусе (`2021:11283` —
        // search лежит на x=16 шириной 370 при ширине бара 402).
        HStack(spacing: 0) {
            SearchPill(
                layout: layout,
                searchFocused: $searchFocused,
                query: $query
            )
            .padding(.leading, layout.screenMargin)

            TrailingSlot(layout: layout)
        }
        .frame(height: PlusMetrics.actionBarHeight)
        .offset(y: layout.lift)
        // ЕДИНСТВЕННАЯ анимация бара. Порядок обязателен: она оборачивает и HStack,
        // и падинг, и offset — поэтому ширины зон, уезд плеера, поля 24→16 и подъём
        // меняются одним апдейтом, одной кривой, с одной точкой старта.
        // Ключ — сам `layout` (синтезированный ==), а не строка: нельзя «забыть поле»,
        // и на каждом проходе body больше не строится String.
        .animation(ActionBarMotion.morph, value: layout)
        .onChange(of: searchFocused) { _, focused in
            actionBar.isSearchFocused = focused
        }
        .onChange(of: actionBar.isSearchFocused) { _, focused in
            if searchFocused != focused { searchFocused = focused }
        }
        #if DEBUG
        .onAppear {
            if UserDefaults.standard.bool(forKey: "debugSearchFocus") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    searchFocused = true
                }
            }
        }
        .task {
            // `-debugMorphCycle` — прогон всех четырёх режимов по кругу, чтобы снять
            // морф на видео: тапнуть по бару из шелла симулятора нельзя.
            guard UserDefaults.standard.bool(forKey: "debugMorphCycle") else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1600))
                actionBar.cycleDebugMode()
            }
        }
        .task {
            // `-debugFullPlayer` — раскрыть и свернуть полноэкранный плеер:
            // морф иначе не снять на видео, тапнуть по пилюле из шелла нечем.
            guard UserDefaults.standard.bool(forKey: "debugFullPlayer") else { return }
            try? await Task.sleep(for: .seconds(2))
            actionBar.isFullPlayerOpen = true
            try? await Task.sleep(for: .seconds(6))
            actionBar.isFullPlayerOpen = false
        }
        .task {
            // `-debugPlayCycle` — play/pause по кругу: инерцию вращения обложки
            // иначе не снять, кнопку из шелла не нажать.
            guard UserDefaults.standard.bool(forKey: "debugPlayCycle") else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                actionBar.toggleMusicPlayback()
            }
        }
        #endif
    }
}

// MARK: - Layout

/// Раскладка бара. Ключевое правило: **ровно одна зона гибкая, вторая фиксированная**.
/// Ширины не вычисляются из измеренной ширины бара — измерение анимируемого размера
/// через GeometryReader замыкает цикл «измерил → пересчитал → анимировал → измерил»
/// и вешает рендер на 100% CPU (поймано в режиме music 2026-08-22).
///
/// Структура — ключ единственной анимации бара, поэтому в неё **не должно попадать
/// ни одной величины, меняющейся чаще, чем раз в переход** (`musicProgress`, `pull`,
/// угол обложки): иначе каждый тик получит пружину 0.32.
private struct ActionBarLayout: Equatable {
    /// nil — зона занимает остаток (гибкая).
    let searchWidth: CGFloat?
    /// nil — зона занимает остаток (гибкая).
    let trailingWidth: CGFloat?
    let showMiniPlayer: Bool
    let showBookChip: Bool
    let showMovieChip: Bool
    let placeholderOpacity: Double
    let searchIconOnly: Bool
    let trackInfoOpacity: Double
    let progressOpacity: Double
    /// Фокусная раскладка: поле занимает бар целиком, плеер уезжает за кромку.
    let isRaised: Bool
    /// Подъём над клавиатурой — свойство ОБЩЕГО предка обеих зон, а не зоны.
    let lift: CGFloat
    let screenMargin: CGFloat
    /// Зазор между зонами (бывший HStack spacing).
    let gap: CGFloat

    init(mode: ActionBarMode, hasMusic: Bool, raise: ActionBarRaise) {
        let compact = PlusMetrics.actionBarCompact
        isRaised = raise.isRaised
        lift = raise.lift
        screenMargin = raise.isRaised ? ActionBarGeometry.focusedScreenMargin : PlusMetrics.screenMargin

        // Фокус поиска перекрывает режим: поле занимает бар целиком, плейсхолдер гаснет,
        // а плеер уезжает вправо за кромку экрана (`2021:11248` — в баре остаётся
        // только поле 370pt при полях 16).
        if raise.isRaised {
            searchWidth = nil
            trailingWidth = 0
            gap = 0
            // Слои остаются в дереве, чтобы уехать, а не мигнуть исчезновением.
            // Мини-плеер только в своих режимах: иначе в .book/.movie он оказывался
            // активным одновременно с чипом и проявлялся из блюра прямо во время уезда.
            showMiniPlayer = hasMusic && (mode == .music || mode == .search)
            showBookChip = mode == .book
            showMovieChip = mode == .movie
            placeholderOpacity = 0
            searchIconOnly = false
            trackInfoOpacity = 0
            progressOpacity = 0
            return
        }

        switch mode {
        case .search:
            showMiniPlayer = hasMusic
            showBookChip = false
            showMovieChip = false
            placeholderOpacity = 1
            trackInfoOpacity = 0
            progressOpacity = 0
            searchIconOnly = false
            // Поиск гибкий, свёрнутый плеер — фиксированный круг. В макете это 284 + 60
            // при контенте 352; гибкая зона даёт ту же картинку и переживает любую ширину экрана.
            searchWidth = nil
            // Без музыки правой зоны нет вовсе: обе гибкие поделили бы бар пополам
            // и обрезали плейсхолдер.
            trailingWidth = hasMusic ? compact : 0
            gap = hasMusic ? PlusMetrics.actionBarGap : 0

        case .music:
            showMiniPlayer = hasMusic
            showBookChip = false
            showMovieChip = false
            // Фокус перехвачен ранним return выше — сюда попадаем только вне фокуса.
            trackInfoOpacity = 1
            progressOpacity = 1

            if !hasMusic {
                searchIconOnly = false
                placeholderOpacity = 1
                searchWidth = nil
                trailingWidth = 0
                gap = 0
            } else {
                // Зеркало режима search: теперь фиксирован поиск, а плеер занимает остаток.
                searchIconOnly = true
                placeholderOpacity = 0
                searchWidth = compact
                trailingWidth = nil
                gap = PlusMetrics.actionBarGap
            }

        case .book:
            showMiniPlayer = false
            showBookChip = true
            showMovieChip = false
            placeholderOpacity = 1
            searchIconOnly = false
            trackInfoOpacity = 0
            progressOpacity = 0
            searchWidth = nil
            trailingWidth = ActionBarGeometry.bookChipAABBWidth
            gap = PlusMetrics.actionBarGap

        case .movie:
            showMiniPlayer = false
            showBookChip = false
            showMovieChip = true
            placeholderOpacity = 1
            searchIconOnly = false
            trackInfoOpacity = 0
            progressOpacity = 0
            searchWidth = nil
            trailingWidth = ActionBarGeometry.movieChipAABBWidth
            gap = PlusMetrics.actionBarGap
        }
    }
}

// MARK: - Search pill

private struct SearchPill: View {
    let layout: ActionBarLayout
    @FocusState.Binding var searchFocused: Bool
    @Binding var query: String

    /// Натяжение резины 0…1. Живёт здесь, а не в `ActionBarState`: запись 120 раз
    /// в секунду в `@Observable` инвалидировала бы весь хром — плеер, таббар, подложку.
    @State private var pull: CGFloat = 0
    /// Хаптика порога уже отдана.
    @State private var tickArmed = false

    private var stretch: CGFloat { pull * SearchPullConfig.heightLimit }

    /// Сжимается только гибкая капсула: у круга 60pt те же 16pt — это 27% ширины,
    /// и HStack тащил бы за собой мини-плеер каждый кадр.
    private var squeeze: CGFloat {
        layout.searchWidth == nil ? pull * SearchPullConfig.widthLimit : 0
    }

    var body: some View {
        // Зазоры навешены на элементы, а не заданы общим `spacing`: в компактном круге
        // контент — это 60 − 18 − 18 = 24pt, ровно бокс иконки. Общий spacing 8 не
        // схлопывался вместе с полем, HStack переполнялся на 8 и центрировал содержимое —
        // лупа уезжала на 4pt влево (замер: 15.67 вместо 20.0).
        HStack(spacing: 0) {
            searchIcon
                .padding(.trailing, layout.searchIconOnly ? 0 : 8)

            ZStack(alignment: .leading) {
                if !layout.searchIconOnly {
                    placeholderStack
                        .opacity(layout.placeholderOpacity)
                }
                // Поле ввода живёт всегда, но до фокуса невидимо: пересоздавать его
                // по условию — значит терять фокус и каретку на первом же кадре.
                // Гейт по сырому фокусу, а не по раскладке: каретка и набранный текст
                // видны сразу, даже если клавиатура ещё не пришла.
                input
                    .opacity(searchFocused ? 1 : 0)
            }

            // Крест влияет на раскладку — обязан ехать общей транзакцией, значит
            // гейт по геометрии, а не по сырому фокусу.
            if layout.isRaised {
                clearButton
                    .padding(.leading, 8)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, ActionBarGeometry.searchPaddingH)
        .frame(maxWidth: layout.searchWidth == nil ? .infinity : nil)
        .frame(width: layout.searchWidth)
        .frame(height: PlusMetrics.actionBarHeight + stretch)
        .glassPill()
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        // Фрейм растёт вокруг центра — сдвиг на половину прижимает низ к бару,
        // вверх уходит только верхняя кромка. Чистый transform, раскладку не трогает.
        .offset(y: -stretch / 2)
        // simultaneousGesture, а не gesture: внутри капсулы живут TextField и крест,
        // у потомков приоритет выше, и обычный жест на родителе они бы перебили.
        .simultaneousGesture(pullGesture)
        .onTapGesture { searchFocused = true }
        // Сжатие ширины — внешним отступом, а не frame: HStack всё равно отдаёт
        // гибкому ребёнку весь остаток, поэтому правая зона не едет.
        .padding(.horizontal, squeeze / 2)
        .onChange(of: searchFocused) { _, focused in
            if focused, pull != 0 {
                withAnimation(ActionBarMotion.morph) { pull = 0 }
            }
        }
    }

    /// Свайп вверх по полю: капсула тянется как резина, на пороге открывается поиск.
    /// Фокус ставится только на отпускании — иначе бар прыгнет вверх из-под пальца.
    private var pullGesture: some Gesture {
        DragGesture(minimumDistance: SearchPullConfig.activation, coordinateSpace: .local)
            .onChanged { value in
                guard !searchFocused else { return }
                let travel = -value.translation.height
                // Без withAnimation: резина идёт за пальцем один в один.
                pull = SearchPullConfig.progress(travel: travel)
                updateTick(travel: travel)
            }
            .onEnded { value in
                tickArmed = false
                guard !searchFocused else { pull = 0; return }
                let travel = -value.translation.height
                let flick = -value.velocity.height >= SearchPullConfig.flickVelocity
                    && travel >= SearchPullConfig.flickMinDistance
                    && travel > abs(value.translation.width)

                if travel >= SearchPullConfig.triggerDistance || flick {
                    searchFocused = true
                    // Резина расходится тем же морфом, каким бар переезжает в фокус.
                    withAnimation(ActionBarMotion.morph) { pull = 0 }
                } else {
                    withAnimation(SearchPullConfig.release) { pull = 0 }
                }
            }
    }

    /// Тик на пересечении порога: палец ещё внизу, но уже «взведено».
    private func updateTick(travel: CGFloat) {
        if travel >= SearchPullConfig.triggerDistance, !tickArmed {
            tickArmed = true
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: SearchPullConfig.tickHapticIntensity)
        } else if travel < SearchPullConfig.triggerDistance - SearchPullConfig.triggerHysteresis {
            tickArmed = false
        }
    }

    /// Настоящее поле ввода: даёт системную каретку, которой в макете отмечено
    /// место сразу за лупой (`2021:11248`, каретка на x=50).
    private var input: some View {
        TextField("", text: $query)
            .focused($searchFocused)
            .textFieldStyle(.plain)
            .tint(Color.fillOne)
            .foregroundStyle(Color.fillOne)
            .plusTitleL()
            .submitLabel(.search)
            // opacity 0 в SwiftUI не выключает хит-тест: без этого невидимое поле
            // перехватывало бы касания мимо жеста резины. Гейт тот же, что и у opacity.
            .allowsHitTesting(searchFocused)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Крест справа: снимает фокус и опускает клавиатуру. В макете 24×24 с полем 18
    /// от правого края поля — то есть на месте общего внутреннего отступа пилюли.
    private var clearButton: some View {
        let glyph = glyphSize(of: "iconClose", box: ActionBarGeometry.searchIconBox)
        return Button {
            query = ""
            searchFocused = false
        } label: {
            Image("iconClose")
                .renderingMode(.template)
                .resizable()
                .frame(width: glyph.width, height: glyph.height)
                .foregroundStyle(Color.searchIcon)
                .frame(width: ActionBarGeometry.searchIconBox, height: ActionBarGeometry.searchIconBox)
                .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Очистить поиск")
    }

    private var searchIcon: some View {
        let glyph = glyphSize(of: "iconSearch", box: ActionBarGeometry.searchIconBox)
        return Image("iconSearch")
            .renderingMode(.template)
            .resizable()
            .frame(width: glyph.width, height: glyph.height)
            .foregroundStyle(Color.searchIcon)
            .frame(width: ActionBarGeometry.searchIconBox, height: ActionBarGeometry.searchIconBox)
    }

    private var placeholderStack: some View {
        ZStack(alignment: .leading) {
            // Пауза совпадает с гашением плейсхолдера — значит по раскладке.
            SearchPlaceholderTicker(isPaused: layout.isRaised)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

/// Три плейсхолдера с вертикальной ротацией и отдельным анимированным троеточием.
private struct SearchPlaceholderTicker: View {
    var isPaused: Bool

    private static let phrases = [
        "Хочу послушать",
        "Хочу почитать",
        "Хочу посмотреть",
    ]

    @State private var activeIndex = 0
    @State private var dotCount = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                ForEach(Array(Self.phrases.enumerated()), id: \.offset) { index, phrase in
                    HStack(spacing: 0) {
                        Text(phrase)
                        Text(index == activeIndex ? String(repeating: ".", count: dotCount) : "...")
                            .frame(width: 24, alignment: .leading)
                            .opacity(index == activeIndex ? 1 : 0)
                    }
                    .plusTitleL()
                    .foregroundStyle(Color.searchPlaceholder)
                    .opacity(index == activeIndex ? 1 : 0)
                }
            }
            .offset(y: -CGFloat(activeIndex) * ActionBarGeometry.placeholderRowStep)
            .animation(ActionBarMotion.placeholderStep, value: activeIndex)
        }
        .frame(height: 26, alignment: .top)
        .clipped()
        .task(id: isPaused) {
            guard !isPaused else { return }
            await runPlaceholderLoop()
        }
        .task(id: isPaused) {
            guard !isPaused else { return }
            await runEllipsisLoop()
        }
    }

    private func runPlaceholderLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: ActionBarMotion.placeholderInterval)
            activeIndex = (activeIndex + 1) % Self.phrases.count
        }
    }

    private func runEllipsisLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: ActionBarMotion.ellipsisInterval)
            withAnimation(ActionBarMotion.ellipsisStep) {
                dotCount = dotCount % 3 + 1
            }
        }
    }
}

// MARK: - Trailing slot

/// Клип правой зоны: режем **только по левой кромке**, вправо и по вертикали — никогда.
/// Одно правило на все режимы и все состояния, без параметров и без ветвлений.
///
/// Почему именно так:
/// - по левой кромке резать надо: уходящий чип кино (AABB 91.552) в сжатой зоне
///   вылезал бы на поле поиска;
/// - вправо резать нельзя: при фокусе плеер уезжает за кромку экрана, и клип
///   по зоне обрезал бы его задолго до неё;
/// - по вертикали резать нельзя: AABB повёрнутого чипа книги 62.9pt выше зоны 60pt.
///
/// Здесь был параметр `relief` — и это был баг. `Shape` с `EmptyAnimatableData`
/// не интерполируется, и SwiftUI держал **старое** значение фигуры всю анимацию.
/// В `.book` клип в покое распущен, поэтому уезд работал; в `.music` и `.movie`
/// он в покое тугой — и всю анимацию фокуса резал уезжающий плеер по кромке зоны.
/// Отсюда жалоба «правый паддинг обрезает киноплеер, а с книгой всё хорошо».
private struct TrailingClipShape: Shape {
    /// Запас, на который клип уходит вправо и по вертикали. Заведомо больше
    /// и высоты бара, и уезда 120 + поля 16, и любого чипа.
    private static let overshoot: CGFloat = 2000

    func path(in rect: CGRect) -> Path {
        Path(CGRect(
            x: rect.minX,
            y: rect.minY - Self.overshoot,
            width: rect.width + Self.overshoot,
            height: rect.height + Self.overshoot * 2
        ))
    }
}

private struct TrailingSlot: View {
    @Environment(ActionBarState.self) private var actionBar
    let layout: ActionBarLayout

    var body: some View {
        ZStack {
            if let music = actionBar.music {
                MiniPlayerPill(
                    item: music,
                    trackInfoOpacity: layout.trackInfoOpacity,
                    progressOpacity: layout.progressOpacity,
                    progress: actionBar.musicProgress,
                    isPlaying: actionBar.isMusicPlaying,
                    isLiked: actionBar.isMusicLiked,
                    onTogglePlay: { actionBar.toggleMusicPlayback() },
                    onExpand: { actionBar.isFullPlayerOpen = true }
                )
                .blurReplaceLayer(layout.showMiniPlayer)
            }

            if let book = actionBar.book {
                BookChip(cover: book.cover)
                    .blurReplaceLayer(layout.showBookChip)
            }

            if let movie = actionBar.movie {
                MovieChip(still: movie.still)
                    .blurReplaceLayer(layout.showMovieChip)
            }
        }
        .frame(maxWidth: layout.trailingWidth == nil ? .infinity : nil)
        .frame(width: layout.trailingWidth)
        .frame(height: PlusMetrics.actionBarHeight)
        // Уезд вправо за кромку экрана при фокусе поиска — плеер не исчезает рывком,
        // а уходит из бара. Без `opacity`: гашение по пути превращало уезд в
        // растворение над правым полем, до кромки экрана плеер не доезжал.
        // Режет его теперь сама кромка, а поле экрана он проходит насквозь —
        // поэтому в escape входит и оно.
        .offset(x: layout.isRaised ? ActionBarGeometry.trailingEscape + layout.screenMargin : 0)
        // Уехавший плеер остаётся живым в дереве — гасим хит-тест явно.
        .allowsHitTesting(!layout.isRaised)
        // Клип без ветвления. `.if(...)` переключал ветку `_ConditionalContent`:
        // SwiftUI удалял ВСЮ правую зону (она переставала участвовать в раскладке,
        // замирала в последней геометрии и гасла) и вставлял новую, рождённую уже
        // с offset(x: 120) и opacity 0. Поэтому плеер не ехал ни вверх, ни вправо.
        .clipShape(TrailingClipShape())
        // Бывший HStack(spacing:): как padding зазор интерполируется, а spacing прыгал.
        .padding(.leading, layout.gap)
        // Правое поле экрана — часть правой зоны, а не бара: см. комментарий в `ActionBarView`.
        .padding(.trailing, layout.screenMargin)
    }
}

// MARK: - Mini player

/// Вращение обложки с инерцией: диск подхватывает не мгновенно и после паузы
/// докатывается, как маховик.
///
/// Скорость релаксирует к цели с постоянной времени τ, и у этого дифура есть
/// аналитический интеграл — поэтому **угол остаётся чистой функцией от времени**:
/// ```
/// ω(t) = ω_T + (ω₀ − ω_T)·e^(−t/τ)
/// θ(t) = θ₀ + ω_T·t + (ω₀ − ω_T)·τ·(1 − e^(−t/τ))
/// ```
/// Это принципиально. В MusicPlayer инерция сделана покадровым lerp скорости
/// с записью трёх `@State` на каждом кадре — такой приём здесь замыкает цикл
/// перерисовки и вешает рендер (зафиксировано в DECISIONS). Плюс покадровый lerp
/// зависит от частоты кадров: коэффициент 0.04 даёт τ 0.41с на 60Гц и 0.20с
/// на 120Гц, то есть на ProMotion инерция вдвое резче — это баг, а не тюнинг.
///
/// На смене фазы снимается снапшот **и угла, и скорости**, поэтому стык гладкий
/// по производной: play/pause можно дёргать посреди разгона, ветвлений
/// «разгон/торможение» в формуле нет вообще.
private struct CoverSpin {
    /// θ₀ — угол на старте текущей фазы
    var base: Double = 0
    /// ω₀ — скорость на старте текущей фазы, °/с
    var speed: Double = 0
    /// ω_T — к какой скорости фаза стремится
    var target: Double = 0
    /// τ текущей фазы
    var tau: Double = ActionBarMotion.coverSpinDown
    var anchor: Date = .distantPast

    private func elapsed(_ date: Date) -> Double {
        max(0, date.timeIntervalSince(anchor))
    }

    func degrees(at date: Date) -> Double {
        let t = elapsed(date)
        let decay = exp(-t / tau)
        return (base + target * t + (speed - target) * tau * (1 - decay))
            .truncatingRemainder(dividingBy: 360)
    }

    func velocity(at date: Date) -> Double {
        target + (speed - target) * exp(-elapsed(date) / tau)
    }

    /// Движение ещё видно: либо фаза разгонная, либо диск не докатился.
    func isMoving(at date: Date) -> Bool {
        target > 0 || abs(velocity(at: date)) > ActionBarMotion.coverSpinEpsilon
    }

    /// Угол, на котором диск встанет: предел θ при t → ∞ на нулевой цели.
    /// Известен аналитически, поэтому выбег не нужно доигрывать кадрами.
    var restingDegrees: Double {
        (base + (speed - target) * tau).truncatingRemainder(dividingBy: 360)
    }

    /// Когда остаточная скорость упадёт ниже порога. Считается заранее — по ней
    /// `TimelineView` выключается ровно один раз, а не опрашивается каждый кадр.
    var settleDate: Date? {
        guard target == 0, speed > ActionBarMotion.coverSpinEpsilon else { return nil }
        return anchor.addingTimeInterval(tau * log(speed / ActionBarMotion.coverSpinEpsilon))
    }

    /// Идемпотентно: повторный вызов с той же целью фазу не перезапускает.
    mutating func set(spinning: Bool, at date: Date = .now) {
        let next = spinning ? ActionBarMotion.coverDegreesPerSecond : 0
        guard next != target else { return }
        // Снимаем обе величины ДО смены параметров — иначе снапшот возьмётся
        // уже из новой фазы и угол прыгнет.
        base = degrees(at: date)
        speed = velocity(at: date)
        target = next
        tau = spinning ? ActionBarMotion.coverSpinUp : ActionBarMotion.coverSpinDown
        anchor = date
    }

    /// Диск докатился: фиксируем финальный угол и уходим в статику.
    mutating func settle() {
        base = restingDegrees
        speed = 0
        target = 0
    }
}

private struct MiniPlayerPill: View {
    let item: MusicNowPlaying
    let trackInfoOpacity: Double
    let progressOpacity: Double
    let progress: Double
    let isPlaying: Bool
    let isLiked: Bool
    let onTogglePlay: () -> Void
    let onExpand: () -> Void

    /// Вращение обложки — см. `CoverSpin`.
    @State private var spin = CoverSpin()
    /// Крутится ли диск прямо сейчас (включая выбег). Отдельный флаг, а не
    /// производная от `isPlaying`: после паузы диск ещё докатывается.
    @State private var isSpinning = false

    var body: some View {
        // Ширину пилюли задаёт родитель. Контент лежит в overlay, а не внутри —
        // иначе при сжатии до круга 60pt он распирал бы пилюлю изнутри
        // (обложка + подписи + кнопки требуют ~150pt), и клип резал бы её прямоугольником.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: PlusMetrics.actionBarHeight)
            .glassPill()
            .overlay(alignment: .leading) {
                MiniPlayerProgressFill(progress: progress, opacity: progressOpacity)
            }
            .overlay(alignment: .leading) { content }
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
            // Тап по пилюле раскрывает полноэкранный плеер. Кнопки сердца и play
            // лежат выше по дереву и перехватывают касание сами.
            .onTapGesture(perform: onExpand)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.title), \(item.artist)")
    }

    /// Два вложенных стека, а не один плоский: в макете зазор обложка↔тексты 8,
    /// а тексты↔кнопки 12. Плоский `HStack` держал 12 на обоих и уводил левый край
    /// подписей на 4pt вправо (замер: 66.3 от кромки пилюли против 62 в макете).
    private func startSpinPhase(_ playing: Bool) {
        spin.set(spinning: playing)
        if spin.isMoving(at: .now) { isSpinning = true }
    }

    private var content: some View {
        HStack(spacing: ActionBarGeometry.miniPlayerContentGap) {
            HStack(spacing: ActionBarGeometry.miniPlayerCoverGap) {
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
    }

    private var cover: some View {
        Group {
            if isSpinning {
                TimelineView(.animation) { timeline in
                    coverImage
                        .rotationEffect(.degrees(spin.degrees(at: timeline.date)))
                }
            } else {
                coverImage
                    .rotationEffect(.degrees(spin.base))
            }
        }
        // Флаг меняют и кнопка, и карточка витрины, и debug-прогон — слушаем сам флаг.
        .onChange(of: isPlaying) { _, playing in startSpinPhase(playing) }
        // Холодный старт: бар может подняться уже играющим.
        .task { startSpinPhase(isPlaying) }
        // Выбег после паузы доигрывается ровно до расчётной даты успокоения, после
        // чего `TimelineView` уходит из дерева и в покое не стоит ни одного тика.
        .task(id: spin.anchor) {
            guard let settle = spin.settleDate else { return }
            let wait = settle.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            spin.settle()
            isSpinning = false
        }
        .frame(width: PlusMetrics.miniPlayerCover, height: PlusMetrics.miniPlayerCover)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline)
        }
    }

    private var coverImage: some View {
        ArtworkImage(source: item.cover)
            .scaledToFill()
    }

    /// Без зазора: в макете это два бокса по 16 подряд в контейнере ровно 32
    /// (`spacing: 2` разводил базовые линии на 18 вместо 16).
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title)
                .plusTextS()
                .foregroundStyle(Color.fillOne)
                .lineLimit(1)
            Text(item.artist)
                .plusTextS()
                .foregroundStyle(Color.fillSubtitle)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        HStack(spacing: ActionBarGeometry.miniPlayerActionsGap) {
            actionIcon("iconHeart", liked: isLiked)
            playPauseButton
        }
        // В book/movie плеер остаётся в дереве прозрачным, а прозрачные вью всё равно
        // ловят тап — гасим хит-тест вместе с подписями.
        .allowsHitTesting(trackInfoOpacity == 1)
    }

    private var playPauseButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light)
                .impactOccurred(intensity: ActionBarMotion.transportHapticIntensity)
            // Угол фиксируем в том же апдейте, что и смену флага, иначе кадр успеет
            // отрисоваться со старой базой. Сеттер идемпотентен — onChange отработает вхолостую.
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
            // Хит-зона крупнее глифа, но раскладка не едет: отрицательный отступ
            // возвращает кадру исходные 24×24, увеличенной остаётся только contentShape.
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .contentShape(.rect)
            .padding(.horizontal, -8)
            .padding(.vertical, -10)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(isPlaying ? "Пауза" : "Играть")
    }

    private func actionIcon(_ name: String, liked: Bool = false) -> some View {
        let box: CGFloat = 24
        let glyph = glyphSize(of: name, box: box)
        return Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: glyph.width, height: glyph.height)
            .foregroundStyle(liked ? Color.plusAccent : Color.fillOne)
            .frame(width: box, height: box)
    }
}

// MARK: - Progress

/// Заливка прогресса воспроизведения — отдельный слой под контентом (figma-actionbar §4.2).
/// Ширина задаётся масштабом, а не измерением: пилюль сам по себе анимирует ширину,
/// и любое чтение его размера замкнуло бы цикл раскладки. Форму даёт клип родителя.
private struct MiniPlayerProgressFill: View {
    let progress: Double
    let opacity: Double

    var body: some View {
        Rectangle()
            .fill(Color.fillTen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(x: max(0, min(1, progress)), anchor: .leading)
            .opacity(opacity)
            .animation(.easeOut(duration: 0.12), value: progress)
    }
}

// MARK: - Chips

private struct BookChip: View {
    let cover: ArtworkSource

    var body: some View {
        ZStack {
            ArtworkImage(source: cover)
                .scaledToFill()
                .frame(width: ActionBarGeometry.bookCoverSize.width, height: ActionBarGeometry.bookCoverSize.height)
                .clipShape(RoundedRectangle(cornerRadius: PlusRadius.bookChip, style: .continuous))
        }
        .frame(width: ActionBarGeometry.bookChipSize.width, height: ActionBarGeometry.bookChipSize.height)
        .glassSurface(
            RoundedRectangle(cornerRadius: PlusRadius.bookChip, style: .continuous),
            blur: PlusMetrics.glassBlur
        )
        .rotationEffect(.degrees(ActionBarGeometry.chipRotation))
        .frame(width: ActionBarGeometry.bookChipAABBWidth, height: PlusMetrics.actionBarHeight)
    }
}

private struct MovieChip: View {
    let still: ArtworkSource

    var body: some View {
        ZStack {
            ArtworkImage(source: still)
                .scaledToFill()
                .frame(width: ActionBarGeometry.movieFrameSize.width, height: ActionBarGeometry.movieFrameSize.height)
                .clipShape(RoundedRectangle(cornerRadius: PlusRadius.bookChip, style: .continuous))
                .padding(ActionBarGeometry.movieChipPadding)
        }
        .frame(width: ActionBarGeometry.movieChipSize.width, height: ActionBarGeometry.movieChipSize.height)
        .glassSurface(
            RoundedRectangle(cornerRadius: PlusRadius.movieChip, style: .continuous),
            blur: PlusMetrics.glassBlur
        )
        .rotationEffect(.degrees(ActionBarGeometry.chipRotation))
        .frame(width: ActionBarGeometry.movieChipAABBWidth, height: PlusMetrics.actionBarHeight)
    }
}

// MARK: - Смена типа плеера

/// Слой одного из плееров: активный виден, остальные размыты и утоплены.
/// Повторяет нативный `BlurReplaceTransition`, но не удаляет вью из дерева —
/// ширина зоны продолжает морфиться на живом слое.
/// Порядок модификаторов взят из нативной реализации и переставлять его нельзя.
private struct BlurReplaceLayer: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .blur(radius: isActive ? 0 : ActionBarMotion.swapBlurRadius, opaque: false)
            .scaleEffect(isActive ? 1 : ActionBarMotion.swapScale, anchor: .center)
            // Слой с нулевой прозрачностью всё ещё ловит тапы — гасим явно.
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }
}

private extension View {
    func blurReplaceLayer(_ isActive: Bool) -> some View {
        modifier(BlurReplaceLayer(isActive: isActive))
    }
}

// MARK: - Helpers

private func glyphSize(of name: String, box: CGFloat) -> CGSize {
    guard let natural = UIImage(named: name)?.size, natural.width > 0, natural.height > 0 else {
        return CGSize(width: box, height: box)
    }
    let fit = min(1, min(box / natural.width, box / natural.height))
    return CGSize(width: natural.width * fit, height: natural.height * fit)
}
