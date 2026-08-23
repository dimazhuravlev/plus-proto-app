import AVFoundation
import SwiftUI

// MARK: - Содержимое карточек

/// Временный мок содержимого видеокарточек.
///
/// Секция рассказывает **про сам тайтл** — про его героев и про детали, ради которых
/// его стоит смотреть. Раньше сюда шли похожие фильмы из `similar`, и полка читалась
/// как второе «Похожее», хотя настоящее «Похожее» стоит ниже на том же экране.
///
/// Данных такого рода в API нет ни у Кинопоиска, ни у TMDB: там есть факты о тайтле,
/// но не редакционные врезки. Поэтому до появления источника тексты замокированы —
/// это карточки из макета `2052:10642`, переведённые на русский. Тексты одни и те же
/// для любого тайтла: подставлять их под конкретный фильм было бы враньём о контенте.
struct MovieVideoCardMock {
    let title: String
    let subtitle: String

    static let all: [MovieVideoCardMock] = [
        .init(
            title: "Лейла",
            subtitle: "Она вернулась — и на этот раз её замысел слишком велик, чтобы его не заметить"
        ),
        .init(
            title: "Команда снова в сборе",
            subtitle: "Смогут ли они провернуть ещё одно ограбление?"
        ),
        .init(
            title: "Мустафа",
            subtitle: "Мастер перевоплощений"
        ),
        .init(
            title: "1918 год",
            subtitle: "Когда британцы оккупировали Турцию"
        ),
    ]
}

// MARK: - Секция

/// Секция видеокарточек — `figma-moviecard.md` §4.2 «originals content».
///
/// Четыре карточки 361×451.25 с шагом 467.25 и текстовый блок в шахматном порядке
/// между второй и третьей.
///
/// **Про контент.** Тексты карточек замокированы (`MovieVideoCardMock`), движение —
/// забандленный клип: настоящих роликов взять негде, Кинопоиск на бесплатном тарифе
/// отдаёт `videos: null`, а на платном — страницу своего плеера, чей поток закрыт для
/// сторонних клиентов; TMDB отдаёт ролики ключами YouTube, а это не поток для `AVPlayer`.
/// Живым в секции остаётся только описание тайтла между карточками.
struct MovieVideoSection: View {
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
    /// Неподвижные кадры роликов. Живут в секции, а не в карточках: их показывают
    /// оба слоя — и сами карточки, и слой свечений под ними.
    @State private var stills: [Int: Image] = [:]
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

        /// Свечение. Вынос фиксированный, а не масштабом: у более широкой карточки
        /// прототипа масштаб раздул бы его непропорционально.
        ///
        /// Тише макета: там 425×520.6 против кадра 361×451.25 при прозрачности 0.32,
        /// и на тёмном кинокадре это едва заметно. У нас клип светлее, вынос поджат
        /// вдвое, прозрачность втрое ниже, а радиус, наоборот, больше — пятно шире
        /// и оттого мягче.
        static let glowInsetX: CGFloat = 16
        static let glowInsetY: CGFloat = 18
        static let glowBlur: CGFloat = 64
        static let glowOpacity: Double = 0.11
    }

    var body: some View {
        // Два слоя одинаковой раскладки: свечения все до единого лежат **под** всеми
        // карточками. Одним стеком это недостижимо — свечение вылезает за края
        // карточки, а соседи в `VStack` рисуются по порядку, и ореол следующей
        // карточки ложился поверх предыдущей. Поджать вынос не помогло бы: `blur`
        // размазывает копию далеко за её кадр независимо от отступов.
        ZStack(alignment: .top) {
            rows(isGlowLayer: true) { index, _ in glow(index) }
            rows { index, card in cardView(index, card) }
        }
        .padding(.top, Layout.top)
        .padding(.bottom, Layout.bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            for (index, clip) in MovieVideoCardMock.all.indices.map({ ($0, Self.clip(for: $0)) }) {
                stills[index] = await ClipStill.load(clip)
            }
        }
        // Энергосбережение: система просит не тратить батарею на автовоспроизведение.
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    /// Раскладка секции. Одна на оба слоя, чтобы они не разъехались: текстовый блок
    /// в слое свечений тот же самый, только скрытый — `hidden` сохраняет кадр,
    /// поэтому высоты совпадают сами и повторять их числом не приходится.
    @ViewBuilder
    private func rows<Row: View>(
        isGlowLayer: Bool = false,
        @ViewBuilder row: @escaping (Int, MovieVideoCardMock) -> Row
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            ForEach(Array(MovieVideoCardMock.all.enumerated()), id: \.offset) { index, card in
                row(index, card)
                    .padding(.horizontal, Layout.side)

                if index + 1 == Layout.textAfter, !paragraphs.isEmpty {
                    MovieSynopsisSection(paragraphs: paragraphs)
                        .padding(.vertical, Layout.textBlockVertical)
                        // В слое свечений это распорка, а не текст: `hidden` сохраняет
                        // кадр, поэтому слои не разъезжаются, а описание рисуется
                        // и нажимается ровно один раз.
                        .opacity(isGlowLayer ? 0 : 1)
                        .allowsHitTesting(!isGlowLayer)
                }
            }
        }
    }

    private func cardView(_ index: Int, _ card: MovieVideoCardMock) -> some View {
        MovieVideoCard(
            card: card,
            clip: Self.clip(for: index),
            still: stills[index],
            isActive: activeCard == index,
            aspect: Layout.cardAspect,
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
    }

    /// Свечение карточки — размытая копия её кадра, вылезающая за края.
    private func glow(_ index: Int) -> some View {
        Color.clear
            .aspectRatio(Layout.cardAspect, contentMode: .fit)
            .overlay {
                if let still = stills[index] {
                    still
                        .resizable()
                        .scaledToFill()
                        .padding(.horizontal, -Layout.glowInsetX)
                        .padding(.vertical, -Layout.glowInsetY)
                        .blur(radius: Layout.glowBlur)
                        .opacity(Layout.glowOpacity)
                }
            }
            .allowsHitTesting(false)
    }

    /// Кто играет прямо сейчас. `nil` — никто: движение выключено пользователем,
    /// включено энергосбережение, приложение в фоне или ни одна карточка не видна.
    private var activeCard: Int? {
        guard !reduceMotion, !isLowPower, scenePhase == .active else { return nil }
        return visibleCards.min()
    }

    /// Клипов в бандле меньше, чем карточек, — раздаём по кругу.
    private static func clip(for index: Int) -> String {
        ShowcaseSeeds.videoCardClips[index % ShowcaseSeeds.videoCardClips.count]
    }
}

// MARK: - Карточка

/// Одна видеокарточка: свечение по краям, кадр со скруглением, скрим и подписи.
///
/// Фон карточки — **сам ролик**: пока очередь играть не дошла, на карточке стоит его
/// же неподвижный кадр, а как дойдёт — тот же кадр оживает. Постера тайтла под ним
/// больше нет: карточка рассказывает про фильм, а не показывает соседний.
///
/// Кадр берётся картинкой (`ClipStill`), а не «паузой на плеере». `AVPlayerLayer`,
/// которому ни разу не давали играть, ничего не рисует — карточка оставалась чёрной,
/// пока до неё не доскроллят. Показывать пустоту до первого показа нельзя: карточек
/// четыре, одновременно играет одна, и три из них были бы дырами.
///
/// Плеер живёт всё время, пока карточка в дереве, и только ставится на паузу:
/// пересобирать `AVQueuePlayer` на каждый заход в поле зрения дороже, чем держать его,
/// а на скролле это ещё и лишний рывок на первом кадре. Карточек четыре,
/// ролики беззвучные и локальные — держать их дёшево.
private struct MovieVideoCard: View {
    let card: MovieVideoCardMock
    let clip: String
    /// Неподвижный кадр ролика приходит из секции: его же показывает слой свечений.
    let still: Image?
    let isActive: Bool
    /// Пропорция кадра. Ширину карточка берёт от секции — на холсте макета 393 это
    /// 361, но экран прототипа шире, и фиксировать её значило бы оставить поле справа.
    let aspect: CGFloat
    let radius: CGFloat

    @State private var playback = LoopingVideoPlayback()
    @State private var isVideoReady = false
    /// Карточка хоть раз играла. До этого видеослой прозрачен: он не рисует кадр,
    /// пока ему не дали play, и без этого флага мы бы гасили картинку под пустотой.
    @State private var hasPlayed = false

    var body: some View {
        // Кадр задаёт распорка, а видео его заполняет: `aspectRatio` на самом слое
        // считает высоту от идеального размера, а не от пропорции макета,
        // и карточка расползалась на всю ширину экрана. Та же идиома, что у кавера.
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { frame }
            .overlay(alignment: .bottom) { caption }
            .clipShape(shape)
            // Рамка поверх клипа, иначе её съедает скругление.
            .overlay { shape.strokeBorder(Color.fillNine, lineWidth: Self.border) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(card.title)
            // Ролик заряжается сразу, но не запускается: играть он начнёт, когда
            // карточка станет верхней видимой.
            .task(id: clip) { playback.prepare(bundled: clip) }
            // Пауза, а не остановка: ролик зациклен, и вернувшаяся в кадр карточка
            // должна продолжить, а не дёрнуться в начало.
            .onChange(of: isActive, initial: true) { _, active in
                guard active else { return playback.pause() }
                hasPlayed = true
                playback.start(bundled: clip)
            }
            .onDisappear { playback.pause() }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    /// Кадр карточки: неподвижная картинка, поверх которой встаёт видео, когда
    /// доходит очередь. Подмена мягкая — жёсткая читается щелчком, хотя картинка
    /// и первый кадр ролика это одно и то же изображение.
    private var frame: some View {
        ZStack {
            if let still {
                still
                    .resizable()
                    .scaledToFill()
            }

            LoopingVideoLayer(player: playback.queue) { isVideoReady = true }
                .opacity(hasPlayed && isVideoReady ? 1 : 0)
                .animation(.easeInOut(duration: MovieCoverMotion.videoFadeIn), value: hasPlayed)
        }
        .allowsHitTesting(false)
    }

    /// Подписи прижаты к низу стека 256pt с полем 24 — так они стоят в макете
    /// (`justify=MAX`), а не просто «в 24 от нижней кромки карточки».
    private var caption: some View {
        VStack(alignment: .leading, spacing: Self.captionGap) {
            Text(card.title.prefixWords(maxCharacters: Self.titleLimit))
                .plusMovieCardText()
                .foregroundStyle(Color.fillOne)
            Text(card.subtitle)
                .plusMovieCardText()
                .foregroundStyle(Color.fillSubtitle)
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
    private static let ambilightInsetY: CGFloat = 34.7
    /// В макете CSS `blur(40px)`
    private static let ambilightBlur: CGFloat = 40
    private static let ambilightOpacity: Double = 0.32
}

// MARK: - Первый кадр ролика

/// Первый кадр забандленного клипа, картинкой. Работает и фоном карточки, и источником
/// свечения по её краям.
///
/// Фоном — потому что `AVPlayerLayer` без единого `play` кадр не рисует, и карточка,
/// до которой не доскроллили, оставалась бы чёрной.
///
/// Свечением — потому что в макете это размытая копия того же **видео**, а живьём её
/// взять нечем: `AVPlayer` отдаёт картинку одному слою, второй на тот же плеер
/// останется пустым, а `.blur` радиусом 40 по видеослою — это гауссиан на каждый кадр,
/// ровно та цена, которой на скролле быть не должно. Под блюром 40 и прозрачностью
/// 0.32 застывшее свечение от живого не отличить.
///
/// Разрешение — родное для клипа: карточка портретная, ролики широкие, и `resizeAspectFill`
/// и так растягивает узкую вертикальную полосу источника. Уменьшать её значит проиграть
/// в чёткости самому видео, поверх которого картинка и стоит.
@MainActor
private enum ClipStill {
    private static var cache: [String: Image] = [:]

    static func load(_ name: String) async -> Image? {
        if let hit = cache[name] { return hit }
        guard let url = LoopingVideoPlayback.bundled(name) else { return nil }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? await generator.image(at: .zero).image else { return nil }
        let image = Image(decorative: cgImage, scale: 1)
        cache[name] = image
        return image
    }
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
