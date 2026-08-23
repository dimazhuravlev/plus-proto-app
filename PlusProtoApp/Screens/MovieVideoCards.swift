import AVFoundation
import SwiftUI

// MARK: - Секция

/// Секция видеокарточек — `figma-moviecard.md` §4.2 «originals content».
///
/// Четыре карточки 361×451.25 с шагом 467.25 и текстовый блок в шахматном порядке
/// между второй и третьей.
///
/// **Про контент.** Настоящих трейлеров взять негде: Кинопоиск на бесплатном тарифе
/// отдаёт `videos: null`, а на платном — страницу своего плеера, чей поток закрыт для
/// сторонних клиентов; TMDB отдаёт ролики ключами YouTube, а это не поток для `AVPlayer`.
/// Поэтому картинка и название у карточки настоящие, а движение — забандленный клип.
/// Тот же компромисс уже принят в блоке «продолжить смотреть» витрины.
struct MovieVideoSection: View {
    let titles: [MovieSimilarTitle]
    let paragraphs: [String]

    /// Какие карточки сейчас в поле зрения — по порядковому номеру в секции.
    ///
    /// Играет **верхняя из видимых**, и ровно одна. Без арбитра карточки решали бы
    /// каждая за себя, а при высоте 451pt на экране 874pt две соседние спокойно видны
    /// одновременно: 451·0.9·2 + 16 = 828, обе проходят даже строгий порог. Два живых
    /// `AVPlayer` на скролле — лишние декодеры ровно тогда, когда экран должен ехать гладко.
    ///
    /// Именно «верхняя», а не «самая видимая»: `onScrollVisibilityChange` отдаёт булево,
    /// а не долю, поэтому у «самой видимой» победитель при двух видимых выбирался бы
    /// произвольно и переключение мигало бы. Верхняя — устойчивый признак: пока она
    /// не ушла, играет она, и переключение случается ровно один раз.
    ///
    /// Обычный `@State`, а не отдельный `@Observable`-арбитр: тот обновлялся прямо
    /// в обход раскладки того же поддерева, и SwiftUI ругался `AttributeGraph: cycle detected`.
    @State private var visibleCards: Set<Int> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private enum Layout {
        static let cardWidth: CGFloat = 361
        static let cardHeight: CGFloat = 451.25
        static let cardRadius: CGFloat = 20
        static let gap: CGFloat = 16
        /// Текстовый блок между второй и третьей карточкой
        static let textAfter = 2
        static let paragraphLeading: CGFloat = 16
        /// Второй абзац сдвинут вправо — «ступенька» этого макета
        static let paragraphStagger: CGFloat = 48
        static let paragraphTrailing: CGFloat = 48
        static let paragraphGap: CGFloat = 8
        static let paragraphBottom: CGFloat = 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, title in
                MovieVideoCard(
                    title: title,
                    clip: Self.clip(for: index),
                    isActive: activeCard == index,
                    size: CGSize(width: Layout.cardWidth, height: Layout.cardHeight),
                    radius: Layout.cardRadius
                )
                // Порог — половина карточки: ниже него на быстром скролле успевали бы
                // стартовать ролики, которых пользователь даже не увидит.
                .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                    if isVisible {
                        visibleCards.insert(index)
                    } else {
                        visibleCards.remove(index)
                    }
                }
                .onDisappear { visibleCards.remove(index) }

                if index + 1 == Layout.textAfter, !paragraphs.isEmpty {
                    textBlock
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Движение выключено пользователем — ролики не стартуют вовсе, карточки
        // остаются постерами. Это ровно тот случай, ради которого настройка есть:
        // четыре зацикленных ролика, встающих по скроллу, — это фоновое движение.
        // Энергосбережение: система просит не тратить батарею на автовоспроизведение.
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    /// Кто играет прямо сейчас. `nil` — никто: движение выключено пользователем,
    /// включено энергосбережение, приложение в фоне или ни одна карточка не видна.
    private var activeCard: Int? {
        guard !reduceMotion, !isLowPower, scenePhase == .active else { return nil }
        return visibleCards.min()
    }

    /// Карточек в макете четыре. Меньше — показываем сколько есть, больше не берём:
    /// остальные похожие тайтлы уходят в сетку «Похожее» ниже.
    private var cards: [MovieSimilarTitle] {
        Array(titles.prefix(4))
    }

    /// Клипов в бандле меньше, чем карточек, — раздаём по кругу.
    private static func clip(for index: Int) -> String {
        ShowcaseSeeds.videoCardClips[index % ShowcaseSeeds.videoCardClips.count]
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: Layout.paragraphGap) {
            ForEach(Array(paragraphs.prefix(2).enumerated()), id: \.offset) { index, text in
                Text(text)
                    .plusMovieParagraph()
                    .foregroundStyle(Color.fillOne)
                    .padding(.leading, index == 0 ? Layout.paragraphLeading : Layout.paragraphStagger)
                    .padding(.trailing, Layout.paragraphTrailing)
            }
        }
        .padding(.bottom, Layout.paragraphBottom)
    }
}

// MARK: - Карточка

/// Одна видеокарточка: свечение по краям, кадр со скруглением, скрим и подписи.
///
/// Плеер живёт всё время, пока карточка в дереве, и только ставится на паузу:
/// пересобирать `AVQueuePlayer` на каждый заход в поле зрения дороже, чем держать его,
/// а на скролле это ещё и лишний рывок на первом кадре. Карточек максимум четыре,
/// ролики беззвучные и локальные — держать их дёшево.
private struct MovieVideoCard: View {
    let title: MovieSimilarTitle
    let clip: String
    let isActive: Bool
    let size: CGSize
    let radius: CGFloat

    @State private var playback = LoopingVideoPlayback()
    @State private var isVideoReady = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(alignment: .bottom) { caption }
            .background(alignment: .center) { ambilight }
            .padding(.leading, MovieLayout.sectionSide)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title.title)
            // Пауза, а не остановка: ролик зациклен, и вернувшаяся в кадр карточка
            // должна продолжить, а не дёрнуться в начало.
            .onChange(of: isActive, initial: true) { _, active in
                active ? playback.start(bundled: clip) : playback.pause()
            }
            .onDisappear { playback.pause() }
    }

    private var content: some View {
        ZStack {
            // Постер держит кадр, пока видео не готово, и остаётся насовсем,
            // если движение выключено.
            if let poster = title.poster {
                ArtworkImage(source: .remote(poster))
                    .scaledToFill()
            } else {
                Color.fillTen
            }

            if !reduceMotion {
                LoopingVideoLayer(player: playback.queue) { isVideoReady = true }
                    // Видео проявляется поверх постера: жёсткая подмена читается щелчком.
                    .opacity(isVideoReady ? 1 : 0)
                    .animation(.easeInOut(duration: MovieCoverMotion.videoFadeIn), value: isVideoReady)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Свечение вокруг карточки — копия кадра, размытая и вылезающая за края.
    /// Радиус 80 против 28 у витрины: карточка крупнее, и мягкость должна расти с ней.
    private var ambilight: some View {
        Group {
            if let poster = title.poster {
                ArtworkImage(source: .remote(poster))
                    .scaledToFill()
            }
        }
        .frame(width: size.width * Self.ambilightScale, height: size.height * Self.ambilightScale)
        .blur(radius: Self.ambilightBlur)
        .opacity(Self.ambilightOpacity)
        .allowsHitTesting(false)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: Self.captionGap) {
            Text(title.title.prefixWords(maxCharacters: 50))
                .plusMovieCardTitle()
                .foregroundStyle(Color.fillOne)
            if let year = title.year {
                Text(year)
                    .plusMovieCardSubtitle()
                    .foregroundStyle(Color.fillOne.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.captionPadding)
        .background(alignment: .bottom) {
            MovieScrim.gradient(peak: Self.captionScrimPeak, from: .top, to: .bottom)
                .frame(height: Self.captionScrimHeight)
                .allowsHitTesting(false)
        }
    }

    // Макетные числа §4.2
    private static let captionGap: CGFloat = 4
    private static let captionPadding: CGFloat = 24
    private static let captionScrimHeight: CGFloat = 256
    private static let captionScrimPeak: Double = 0.9
    /// `ambilight` 425×520.6 против кадра 361×451.25 — это 1.177 и 1.154; берём среднее.
    private static let ambilightScale: CGFloat = 1.165
    private static let ambilightBlur: CGFloat = 80
    private static let ambilightOpacity: Double = 0.7
}

private extension String {
    /// Обрезает по границе слова: лимиты макета — 50 символов на заголовок карточки.
    func prefixWords(maxCharacters: Int) -> String {
        guard count > maxCharacters else { return self }
        let clipped = String(prefix(maxCharacters))
        guard let space = clipped.lastIndex(of: " ") else { return clipped }
        return String(clipped[..<space]) + "…"
    }
}
