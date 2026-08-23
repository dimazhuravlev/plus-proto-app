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

    /// Числа из `2052:10642` основного файла макета. Это **другая** версия секции,
    /// чем в `figma-moviecard.md` §4.2: там карточка фиксированных 361×451.25, заголовок
    /// 32/110 %, пик скрима 0.9. Здесь карточка тянется по ширине, заголовок и подпись
    /// одного кегля (замер нод: 28 и 56 = 2×28), а пик скрима 0.48.
    private enum Layout {
        /// Поля секции: карточка тянется на всю ширину между ними.
        static let side: CGFloat = 16
        /// Пропорция кадра — `aspect-[480/600]`
        static let cardAspect: CGFloat = 480.0 / 600.0
        static let cardRadius: CGFloat = 20
        static let gap: CGFloat = 16
        /// Первая карточка стоит на y 32 от верха секции, последняя — в 16 от низа
        static let top: CGFloat = 32
        static let bottom: CGFloat = 16

        /// Текстовый блок между второй и третьей карточкой
        static let textAfter = 2
        static let textBlockVertical: CGFloat = 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, title in
                MovieVideoCard(
                    title: title,
                    clip: Self.clip(for: index),
                    isActive: activeCard == index,
                    aspect: Layout.cardAspect,
                    radius: Layout.cardRadius
                )
                .padding(.horizontal, Layout.side)
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
                    MovieSynopsisSection(paragraphs: paragraphs)
                        .padding(.vertical, Layout.textBlockVertical)
                }
            }
        }
        .padding(.top, Layout.top)
        .padding(.bottom, Layout.bottom)
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
    /// Пропорция кадра. Ширину карточка берёт от секции — на холсте макета 393 это
    /// 361, но экран прототипа шире, и фиксировать её значило бы оставить поле справа.
    let aspect: CGFloat
    let radius: CGFloat

    @State private var playback = LoopingVideoPlayback()
    @State private var isVideoReady = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Кадр задаёт распорка, а картинка его заполняет: `aspectRatio` на самой
        // картинке считает высоту от её идеального размера, а не от пропорции макета,
        // и карточка расползалась на всю ширину экрана. Та же идиома, что у кавера.
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { content }
            .overlay(alignment: .bottom) { caption }
            .clipShape(shape)
            // Рамка поверх клипа, иначе её съедает скругление.
            .overlay { shape.strokeBorder(Color.fillNine, lineWidth: Self.border) }
            .background { ambilight }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title.title)
            // Пауза, а не остановка: ролик зациклен, и вернувшаяся в кадр карточка
            // должна продолжить, а не дёрнуться в начало.
            .onChange(of: isActive, initial: true) { _, active in
                active ? playback.start(bundled: clip) : playback.pause()
            }
            .onDisappear { playback.pause() }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
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

    /// Свечение вокруг карточки — размытая копия кадра, вылезающая за края.
    /// В макете это 425×520.6 против кадра 361×451.25, то есть **+32 по горизонтали
    /// и +34.7 по вертикали с каждой стороны**, и это фиксированный вынос, а не масштаб:
    /// у более широкой карточки прототипа масштаб раздул бы его непропорционально.
    private var ambilight: some View {
        Group {
            if let poster = title.poster {
                ArtworkImage(source: .remote(poster))
                    .scaledToFill()
            }
        }
        .padding(.horizontal, -Self.ambilightInsetX)
        .padding(.vertical, -Self.ambilightInsetY)
        .blur(radius: Self.ambilightBlur)
        .opacity(Self.ambilightOpacity)
        .allowsHitTesting(false)
    }

    /// Подписи прижаты к низу стека 256pt с полем 24 — так они стоят в макете
    /// (`justify=MAX`), а не просто «в 24 от нижней кромки карточки».
    private var caption: some View {
        VStack(alignment: .leading, spacing: Self.captionGap) {
            Text(title.title.prefixWords(maxCharacters: Self.titleLimit))
                .plusMovieCardText()
                .foregroundStyle(Color.fillOne)
            if let year = title.year {
                Text(year)
                    .plusMovieCardText()
                    .foregroundStyle(Color.fillSubtitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.captionPadding)
        .frame(height: Self.captionHeight, alignment: .bottom)
        .background {
            MovieScrim.gradient(peak: Self.captionScrimPeak, from: .top, to: .bottom)
        }
        .allowsHitTesting(false)
    }

    // Числа из `2052:10643`
    private static let border: CGFloat = 1
    private static let captionGap: CGFloat = 4
    private static let captionPadding: CGFloat = 24
    private static let captionHeight: CGFloat = 256
    /// Пик скрима: у панели действий он 0.92, здесь заметно мягче
    private static let captionScrimPeak: Double = 0.48
    private static let titleLimit = 50
    private static let ambilightInsetX: CGFloat = 32
    private static let ambilightInsetY: CGFloat = 34.67
    /// CSS `blur(40px)` из макета — вдвое меньше значения панели Figma
    private static let ambilightBlur: CGFloat = 40
    private static let ambilightOpacity: Double = 0.32
}

private extension String {
    /// Обрезает по границе слова: лимит макета — 50 символов на заголовок карточки.
    func prefixWords(maxCharacters: Int) -> String {
        guard count > maxCharacters else { return self }
        let clipped = String(prefix(maxCharacters))
        guard let space = clipped.lastIndex(of: " ") else { return clipped }
        return String(clipped[..<space]) + "…"
    }
}
