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
    /// Вращение обложки при воспроизведении — как MiniPlayerV2 MusicPlayer.
    static let coverDegreesPerSecond: Double = 18

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

// MARK: - Geometry

/// Числа из figma-actionbar §4, которых нет в Tokens.swift.
private enum ActionBarGeometry {
    static let searchExpandedWidth: CGFloat = 284
    static let searchPaddingH: CGFloat = 18
    static let searchIconBox: CGFloat = 24
    static let placeholderRowStep: CGFloat = 42
    static let miniPlayerPaddingLeading: CGFloat = 6
    static let miniPlayerPaddingTrailing: CGFloat = 18
    static let miniPlayerContentGap: CGFloat = 12
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

// MARK: - Root

/// Action bar: высота 60, поля 24, две зоны с зазором 8 во всю ширину бара
/// (figma-actionbar §4). Один persistent HStack — ширины и opacity анимируются
/// на живых вью, скрытые слои остаются в дереве с opacity 0.
struct ActionBarView: View {
    @Environment(ActionBarState.self) private var actionBar
    @FocusState private var searchFocused: Bool
    @State private var query = ""

    var body: some View {
        let layout = ActionBarLayout(
            mode: actionBar.mode,
            hasMusic: actionBar.music != nil,
            isSearchFocused: actionBar.isSearchFocused
        )

        // Зазор нужен, только когда справа что-то есть: в пустом состоянии поиск
        // занимает бар целиком.
        HStack(spacing: layout.trailingWidth == 0 ? 0 : PlusMetrics.actionBarGap) {
            SearchPill(
                layout: layout,
                isSearchFocused: actionBar.isSearchFocused,
                searchFocused: $searchFocused,
                query: $query
            )

            TrailingSlot(layout: layout)
        }
        .animation(ActionBarMotion.morph, value: layout.animationKey)
        .frame(height: PlusMetrics.actionBarHeight)
        // При фокусе поле расширяется — поля экрана ужимаются с 24 до 16 (`2021:11283`:
        // search лежит на x=16 шириной 370 при ширине бара 402).
        .padding(.horizontal, actionBar.isSearchFocused
                 ? ActionBarGeometry.focusedScreenMargin
                 : PlusMetrics.screenMargin)
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
        #endif
    }
}

// MARK: - Layout

/// Раскладка бара. Ключевое правило: **ровно одна зона гибкая, вторая фиксированная**.
/// Ширины не вычисляются из измеренной ширины бара — измерение анимируемого размера
/// через GeometryReader замыкает цикл «измерил → пересчитал → анимировал → измерил»
/// и вешает рендер на 100% CPU (поймано в режиме music 2026-08-22).
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
    let miniPlayerExpanded: Bool
    let trackInfoOpacity: Double
    let progressOpacity: Double
    let clipTrailing: Bool
    /// Плеер уезжает за правый край экрана — так фокус поиска освобождает бар целиком.
    let trailingEscaped: Bool

    var animationKey: String {
        "\(searchWidth ?? -1)-\(trailingWidth ?? -1)-\(showMiniPlayer)-\(showBookChip)-\(showMovieChip)-\(searchIconOnly)-\(miniPlayerExpanded)-\(placeholderOpacity)-\(trackInfoOpacity)-\(clipTrailing)-\(trailingEscaped)"
    }

    init(mode: ActionBarMode, hasMusic: Bool, isSearchFocused: Bool) {
        let compact = PlusMetrics.actionBarCompact

        // Фокус поиска перекрывает режим: поле занимает бар целиком, плейсхолдер гаснет,
        // а плеер уезжает вправо за кромку экрана (`2021:11248` — в баре остаётся
        // только поле 370pt при полях 16).
        if isSearchFocused {
            searchWidth = nil
            trailingWidth = 0
            trailingEscaped = true
            // Слои остаются в дереве, чтобы уехать, а не мигнуть исчезновением.
            // Мини-плеер только в своих режимах: иначе в .book/.movie он оказывался
            // активным одновременно с чипом и проявлялся из блюра прямо во время уезда.
            showMiniPlayer = hasMusic && (mode == .music || mode == .search)
            showBookChip = mode == .book
            showMovieChip = mode == .movie
            placeholderOpacity = 0
            searchIconOnly = false
            miniPlayerExpanded = false
            trackInfoOpacity = 0
            progressOpacity = 0
            // Без клипа: иначе нулевая зона срежет уезжающий плеер на первом же кадре.
            clipTrailing = false
            return
        }

        trailingEscaped = false

        switch mode {
        case .search:
            showMiniPlayer = hasMusic
            showBookChip = false
            showMovieChip = false
            placeholderOpacity = 1
            trackInfoOpacity = 0
            progressOpacity = 0
            clipTrailing = true
            searchIconOnly = false
            miniPlayerExpanded = false
            // Поиск гибкий, свёрнутый плеер — фиксированный круг. В макете это 284 + 60
            // при контенте 352; гибкая зона даёт ту же картинку и переживает любую ширину экрана.
            searchWidth = nil
            // Без музыки правой зоны нет вовсе: обе гибкие поделили бы бар пополам
            // и обрезали плейсхолдер.
            trailingWidth = hasMusic ? compact : 0

        case .music:
            showMiniPlayer = hasMusic
            showBookChip = false
            showMovieChip = false
            clipTrailing = true
            trackInfoOpacity = isSearchFocused ? 0 : 1
            progressOpacity = isSearchFocused ? 0 : 1

            if isSearchFocused || !hasMusic {
                searchIconOnly = false
                miniPlayerExpanded = false
                placeholderOpacity = 1
                searchWidth = nil
                trailingWidth = hasMusic ? compact : 0
            } else {
                // Зеркало режима search: теперь фиксирован поиск, а плеер занимает остаток.
                searchIconOnly = true
                miniPlayerExpanded = true
                placeholderOpacity = 0
                searchWidth = compact
                trailingWidth = nil
            }

        case .book:
            showMiniPlayer = false
            showBookChip = true
            showMovieChip = false
            placeholderOpacity = 1
            searchIconOnly = false
            miniPlayerExpanded = false
            trackInfoOpacity = 0
            progressOpacity = 0
            searchWidth = nil
            trailingWidth = ActionBarGeometry.bookChipAABBWidth
            clipTrailing = false

        case .movie:
            showMiniPlayer = false
            showBookChip = false
            showMovieChip = true
            placeholderOpacity = 1
            searchIconOnly = false
            miniPlayerExpanded = false
            trackInfoOpacity = 0
            progressOpacity = 0
            searchWidth = nil
            trailingWidth = ActionBarGeometry.movieChipAABBWidth
            clipTrailing = true
        }
    }
}

// MARK: - Search pill

private struct SearchPill: View {
    let layout: ActionBarLayout
    let isSearchFocused: Bool
    @FocusState.Binding var searchFocused: Bool
    @Binding var query: String

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
                input
                    .opacity(isSearchFocused ? 1 : 0)
            }

            if isSearchFocused {
                clearButton
                    .padding(.leading, 8)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, ActionBarGeometry.searchPaddingH)
        .frame(maxWidth: layout.searchWidth == nil ? .infinity : nil)
        .frame(width: layout.searchWidth)
        .frame(height: PlusMetrics.actionBarHeight)
        .glassPill()
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .onTapGesture { searchFocused = true }
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
            SearchPlaceholderTicker(isPaused: isSearchFocused)
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
                    onTogglePlay: { actionBar.toggleMusicPlayback() }
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
        // а уходит из бара; opacity добивает хвост, чтобы он не мелькал за краем.
        .offset(x: layout.trailingEscaped ? ActionBarGeometry.trailingEscape : 0)
        .opacity(layout.trailingEscaped ? 0 : 1)
        .if(layout.clipTrailing) { view in
            view.clipped()
        }
    }
}

// MARK: - Mini player

/// Угол обложки — чистая функция от времени, а не накапливаемое состояние.
/// Запись `@State` из `onChange(of: timeline.date)` (так сделано в MusicPlayer)
/// замыкает цикл перерисовки и вешает экран — этот приём сюда не переносим.
private struct CoverSpin {
    /// Угол на момент старта текущей фазы
    var base: Double = 0
    /// Начало фазы вращения; nil — обложка стоит
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
        if spinning {
            anchor = date
        } else {
            base = degrees(at: date)
            anchor = nil
        }
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

    /// Вращение обложки — см. `CoverSpin`.
    @State private var spin = CoverSpin()

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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.title), \(item.artist)")
    }

    private var content: some View {
        HStack(spacing: ActionBarGeometry.miniPlayerContentGap) {
            cover
            trackInfo
                .opacity(trackInfoOpacity)
            actions
                .opacity(trackInfoOpacity)
        }
        .padding(.leading, ActionBarGeometry.miniPlayerPaddingLeading)
        .padding(.trailing, ActionBarGeometry.miniPlayerPaddingTrailing)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cover: some View {
        Group {
            if spin.isSpinning {
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
        .onChange(of: isPlaying) { _, playing in spin.set(spinning: playing) }
        // Холодный старт: бар может подняться уже играющим.
        .task { spin.set(spinning: isPlaying) }
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

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
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

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
