import SwiftUI
import UIKit
import VariableBlur

/// Горизонтальная карточка ПП — начатый фильм: кадр с полосой просмотренного. Один
/// компонент на все типоразмеры (правка пользователя 2026-10-20):
/// - `large` — «Смотреть дальше» витрины Кинопоиска и серии «Сезонов и Эпизодов» экрана
///   тайтла (`2052:10621`): одна целая и половина следующей (`CinemaLayout.historyFit`);
/// - `medium` — «Смотреть дальше» и «Скачанное кино» коллекции (`2859:75998`): две
///   целые и край 24 (`CollectionLayout.historyFit`), скругление 8.
///
/// Низ кадра один (`PPMovieStripFooter`): полоса блюра, время серым и тонкий таймлайн
/// внутри кадра — витрина переведена на него с прежнего затемнения и полосы во всю
/// ширину (правка пользователя 2026-10-20). Под кадром — название и серым вторая
/// строка: у сериала сезон и серия («2 сезон, 4 серия»), в «Скачанном» — размер; год
/// с жанром не пишем. Только вид: нажатие — у вызывающего.
struct PPMovieCard: View {
    enum Size {
        case large, medium
    }

    let still: ArtworkSource?
    let title: String
    /// Серая вторая строка подписи
    var subtitle: String?
    let size: Size
    /// Доля просмотренного; `nil` — не начинали, полосы нет
    var progress: Double?
    /// Сколько осталось (или хронометраж нетронутого); `nil` — времени нет
    var remaining: TimeInterval?

    /// Начатый фильм — кадр и название из записи, серым — сезон и серия сериала.
    init(movie: MovieInProgress, size: Size, progress: Double? = nil, remaining: TimeInterval? = nil) {
        self.init(still: movie.still, title: movie.title, subtitle: movie.episodeText, size: size, progress: progress, remaining: remaining)
    }

    init(
        still: ArtworkSource?,
        title: String,
        subtitle: String? = nil,
        size: Size,
        progress: Double? = nil,
        remaining: TimeInterval? = nil
    ) {
        self.still = still
        self.title = title
        self.subtitle = subtitle
        self.size = size
        self.progress = progress
        self.remaining = remaining
    }

    var body: some View {
        captioned
    }

    // MARK: Ширины и высоты

    /// Ширина кадра — от ширины экрана (правило 4 CLAUDE.md).
    @MainActor
    static func width(_ size: Size) -> CGFloat {
        switch size {
        case .large: CinemaLayout.historyWidth
        case .medium: CollectionLayout.historyFit.cardWidth
        }
    }

    /// Кадр 16:9, как у карточки макета 252 × 141.75.
    static func stillHeight(width: CGFloat) -> CGFloat {
        width * 270 / 480
    }

    /// Скругление кадра: 12 у карточек 252, 8 у карточки коллекции (`2859:75998`).
    static func radius(_ size: Size) -> CGFloat {
        size == .medium ? Layout.compactRadius : CinemaLayout.cardRadius
    }

    /// Высота ленты: кадр и подпись — название строкой, вторая строка — если она есть
    /// хоть у одной карточки ленты.
    @MainActor
    static func rowHeight(_ size: Size, lines: Int) -> CGFloat {
        stillHeight(width: width(size)) + Layout.captionGap + CGFloat(lines) * CinemaLayout.captionLine
    }

    @MainActor
    static func rowHeight(_ size: Size, movies: [MovieInProgress]) -> CGFloat {
        rowHeight(size, lines: movies.contains { $0.episodeText != nil } ? 2 : 1)
    }

    /// Числа карточки — `2052:10621` и `2859:75998`.
    enum Layout {
        static let compactRadius: CGFloat = 8
        static let captionGap: CGFloat = 6
        /// Полоса под временем: прогрессивный блюр от 0 у верха полосы до 8 Фигмы у низа
        /// (в коде вдвое меньше, как все блюры) и поверх — градиент от чёрного 0 %
        /// к чёрному 10 % (правка пользователя 2026-10-20: ровный блюр макета давал
        /// видимую границу сверху)
        static let stripHeight: CGFloat = 40
        static let stripShade: Double = 0.1
        static let stripBlur: CGFloat = 4
        static let stripInset: CGFloat = 8
        static let timeToTrack: CGFloat = 4
        static let trackHeight: CGFloat = 3
        /// Подложка таймлайна — Fill/Eight на блюре 4 Фигмы
        static let trackBlur: CGFloat = 2
    }

    // MARK: Большая и средняя

    private var captioned: some View {
        let width = Self.width(size)
        return VStack(alignment: .leading, spacing: Layout.captionGap) {
            still(width: width)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .padding(.trailing, CinemaLayout.captionTrailing)
        }
        .frame(width: width, alignment: .leading)
        .contentShape(.rect)
    }

    private func still(width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius(size), style: .continuous)
        return PlusSkeleton.fill
            .overlay { if let still { SkeletonArtwork(source: still) } }
            .overlay(alignment: .bottom) {
                PPMovieStripFooter(width: width, progress: progress, remaining: remaining)
            }
            .frame(width: width, height: Self.stillHeight(width: width))
            .clipShape(shape)
            .coverArtworkMissing(still == nil)
            .coverBorder(shape)
    }

    /// «41 мин», «1 ч 5 мин», «2 ч» — с округлением вверх: последняя неполная
    /// минута тоже осталась.
    static func remainingText(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(minutes) мин" }
        if rest == 0 { return "\(hours) ч" }
        return "\(hours) ч \(rest) мин"
    }

}

/// Карточка ПП кнопкой — «Смотреть дальше»: тап **сразу открывает киноплеер** с места,
/// где остановились (правка пользователя 2026-10-04) — исключение из правила «карточка
/// ведёт на экран тайтла»: продолжить просмотр и есть смысл этой карусели.
struct PPMovieResumeCard: View {
    let entry: WatchHistory.Entry
    let size: PPMovieCard.Size

    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        Button(action: resume) {
            PPMovieCard(movie: entry.movie, size: size, progress: entry.progress, remaining: entry.remaining)
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        .accessibilityLabel(entry.movie.title)
    }

    /// Тот же вход в плеер, что у «Смотреть», — позиция приезжает с записью истории.
    private func resume() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.movie(entry.movie))
    }
}

/// Низ кадра (`2052:10621`, `2859:75998`): полоса блюра 40 от прозрачного к чёрному
/// 10 %, над ней по 8 от кромок — время серым справа и под ним таймлайн 3 на блюре.
/// Не начинали — только время. Общий у карточек ПП и строк серий (`SeriesEpisodeRow`).
struct PPMovieStripFooter: View {
    /// Ширина кадра — таймлайн короче её на поля
    let width: CGFloat
    var progress: Double?
    var remaining: TimeInterval?

    private typealias L = PPMovieCard.Layout

    var body: some View {
        VStack(alignment: .trailing, spacing: L.timeToTrack) {
            if let remaining {
                Text(PPMovieCard.remainingText(remaining))
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .lineLimit(1)
            }
            if let progress {
                Capsule()
                    .fill(Color.fillEight)
                    .background {
                        BackdropBlurView(radius: L.trackBlur)
                            .clipShape(Capsule())
                    }
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.plusSolidOne)
                            .frame(width: (width - 2 * L.stripInset) * min(max(progress, 0), 1))
                    }
                    .frame(width: width - 2 * L.stripInset, height: L.trackHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(L.stripInset)
        .background(alignment: .bottom) {
            if remaining != nil || progress != nil {
                ZStack {
                    VariableBlurView(maxBlurRadius: L.stripBlur, direction: .blurredBottomClearTop)
                    LinearGradient(colors: [.black.opacity(0), .black.opacity(L.stripShade)], startPoint: .top, endPoint: .bottom)
                }
                .frame(height: L.stripHeight)
            }
        }
        .allowsHitTesting(false)
    }
}
