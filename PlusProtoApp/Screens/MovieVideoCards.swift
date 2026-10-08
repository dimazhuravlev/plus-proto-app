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
/// До четырёх карточек 361×451.25 с шагом 467.25 и текстовый блок в шахматном
/// порядке между второй и третьей. Карточек ровно столько, сколько кадров дал API:
/// нет кадра — нет карточки (правка пользователя 2026-08-25, раньше безкадровая
/// карточка стояла на первом кадре забандленного ролика). Кадров нет вовсе —
/// от секции остаётся только описание.
///
/// **Про контент.** Тексты карточек замокированы (`MovieVideoCardMock`), движение —
/// забандленный клип: настоящих роликов взять негде, Кинопоиск на бесплатном тарифе
/// отдаёт `videos: null`, а на платном — страницу своего плеера, чей поток закрыт для
/// сторонних клиентов; TMDB отдаёт ролики ключами YouTube, а это не поток для `AVPlayer`.
/// Живым в секции остаётся только описание тайтла между карточками.
struct MovieVideoSection: View {
    let paragraphs: [String]

    /// Кадры тайтла под карточки — те же сцены, что и в шапке экрана, но другие.
    /// Число кадров и задаёт число карточек: без своего кадра карточки нет.
    let stillURLs: [URL]

    /// Детали тайтла ещё едут — число карточек неизвестно. Болванки стоят с первого
    /// кадра экрана полным каркасом (правка пользователя 2026-08-25); детали доехали —
    /// каркас режется по числу кадров, лишние болванки растворяются тем же фейдом.
    let isLoading: Bool

    /// Какая карточка включена тапом. Ровно одна: тап по другой переключает,
    /// повторный тап по той же — выключает.
    ///
    /// Одна, а не сколько угодно, не из вредности: карточка высотой 451pt на экране
    /// 874pt соседствует со следующей (451·0.9·2 + 16 = 828), и два живых `AVPlayer`
    /// на скролле — лишние декодеры ровно тогда, когда экран должен ехать гладко.
    @State private var playingCard: Int?

    /// Какие карточки сейчас в поле зрения — по порядковому номеру в секции.
    /// Включённая, но уехавшая из кадра карточка встаёт на паузу: крутить ролик,
    /// которого не видно, незачем. Вернулась — продолжает с того же места.
    ///
    /// Обычный `@State`, а не отдельный `@Observable`-арбитр: тот обновлялся прямо
    /// в обход раскладки того же поддерева, и SwiftUI ругался `AttributeGraph: cycle detected`.
    @State private var visibleCards: Set<Int> = []
    /// Неподвижные кадры карточек. Живут в секции, а не в карточках: их показывают
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
        .task(id: stillURLs) { await loadStills() }
        #if DEBUG
        // `-debugTapCard` — тап по первой карточке и повторный тап: снять оба
        // состояния из шелла иначе нечем.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugTapCard") else { return }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            playingCard = 0
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            playingCard = nil
        }
        #endif
        // Энергосбережение: система просит не тратить батарею на автовоспроизведение.
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    /// Раскладка секции. Одна на оба слоя, чтобы они не разъехались: текстовый блок
    /// в слое свечений тот же самый, только скрытый — `hidden` сохраняет кадр,
    /// поэтому высоты совпадают сами и повторять их числом не приходится.
    /// Карточки, которым хватило кадров: мок-каркас режется по числу кадров API.
    private var shownCards: [MovieVideoCardMock] {
        isLoading ? MovieVideoCardMock.all : Array(MovieVideoCardMock.all.prefix(stillURLs.count))
    }

    /// После какой карточки стоит описание. Макетное место — после второй, но карточек
    /// может быть меньше (вплоть до нуля): тогда описание встаёт после последней
    /// имеющейся либо остаётся единственным содержимым секции.
    private var synopsisAfter: Int {
        min(Layout.textAfter, shownCards.count)
    }

    @ViewBuilder
    private func rows<Row: View>(
        isGlowLayer: Bool = false,
        @ViewBuilder row: @escaping (Int, MovieVideoCardMock) -> Row
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            if shownCards.isEmpty {
                if !paragraphs.isEmpty {
                    synopsis(isGlowLayer: isGlowLayer)
                }
            } else {
                ForEach(Array(shownCards.enumerated()), id: \.offset) { index, card in
                    row(index, card)
                        .padding(.horizontal, Layout.side)

                    if index + 1 == synopsisAfter, !paragraphs.isEmpty {
                        synopsis(isGlowLayer: isGlowLayer)
                    }
                }
            }
        }
        // Каркас режется, когда детали доехали: лишние болванки растворяются
        // тем же фейдом, каким карточки оживают.
        .animation(
            reduceMotion ? nil : .easeOut(duration: MovieVideoMotion.cardAppear),
            value: shownCards.count
        )
    }

    private func synopsis(isGlowLayer: Bool) -> some View {
        MovieSynopsisSection(paragraphs: paragraphs)
            .padding(.vertical, Layout.textBlockVertical)
            // В слое свечений это распорка, а не текст: `hidden` сохраняет
            // кадр, поэтому слои не разъезжаются, а описание рисуется
            // и нажимается ровно один раз.
            .opacity(isGlowLayer ? 0 : 1)
            .allowsHitTesting(!isGlowLayer)
    }

    /// Пока кадр карточки едет — болванка того же размера; приехал — карточка
    /// целиком, кроссфейдом за `MovieVideoMotion.cardAppear` (правка пользователя
    /// 2026-08-25). Обе ветки — дефолтный `.opacity`.
    @ViewBuilder
    private func cardView(_ index: Int, _ card: MovieVideoCardMock) -> some View {
        Group {
            if stills[index] != nil {
                MovieVideoCard(
                    card: card,
                    clip: Self.clip(for: index),
                    still: stills[index],
                    isActive: activeCard == index,
                    aspect: Layout.cardAspect,
                    radius: Layout.cardRadius
                ) {
                    playingCard = playingCard == index ? nil : index
                }
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
            } else {
                MovieVideoCardSkeleton(aspect: Layout.cardAspect, radius: Layout.cardRadius)
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: MovieVideoMotion.cardAppear),
            value: stills[index] != nil
        )
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

    /// Кадр каждой карточки — сцена тайтла из API. Фолбэка больше нет: карточка
    /// без кадра не показывается вовсе (см. `shownCards`).
    ///
    /// По порядку, а не пачкой: верхние карточки нужны раньше нижних, и очередь
    /// загрузок, выстроенная сверху вниз, доставляет их в том же порядке.
    private func loadStills() async {
        // Именно по кадрам, а не по карточкам: во время загрузки деталей каркас
        // болванок длиннее списка кадров (он вообще пуст), и индекс по карточкам
        // выходил за его границы — экран падал на первом же открытии.
        for index in stillURLs.prefix(MovieVideoCardMock.all.count).indices {
            guard let loaded = await ArtworkLoader.shared.image(for: stillURLs[index]) else { continue }
            stills[index] = Image(uiImage: loaded)
        }
    }

    /// Кто играет прямо сейчас. `nil` — никто: не тапали, движение выключено
    /// пользователем, включено энергосбережение, приложение в фоне или включённая
    /// карточка ушла из кадра.
    private var activeCard: Int? {
        guard !reduceMotion, !isLowPower, scenePhase == .active else { return nil }
        guard let playingCard, visibleCards.contains(playingCard) else { return nil }
        return playingCard
    }

    /// Клипов в бандле меньше, чем карточек, — раздаём по кругу.
    private static func clip(for index: Int) -> String {
        ShowcaseSeeds.videoCardClips[index % ShowcaseSeeds.videoCardClips.count]
    }
}

// MARK: - Карточка

enum MovieVideoMotion {
    /// Кроссфейд «болванка → карточка», когда кадр приехал, — 300мс по просьбе
    /// пользователя (2026-08-25)
    static let cardAppear: Double = 0.3
}

/// Болванка карточки, пока её кадр едет: тот же скруглённый прямоугольник тех же
/// пропорций с плейсхолдером цвета кавера — без текстов, контент приходит целиком
/// одним кроссфейдом. Приём инфо-блока (`MovieInfoSkeleton`), цвет — кавера.
private struct MovieVideoCardSkeleton: View {
    let aspect: CGFloat
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(MovieCoverPlaceholder.color)
            .aspectRatio(aspect, contentMode: .fit)
            .accessibilityLabel("Загрузка")
    }
}

/// Одна видеокарточка: свечение по краям, кадр со скруглением, скрим и подписи.
///
/// Фон карточки — **сам ролик**: пока очередь играть не дошла, на карточке стоит его
/// же неподвижный кадр, а как дойдёт — тот же кадр оживает. Постера тайтла под ним
/// больше нет: карточка рассказывает про фильм, а не показывает соседний.
///
/// Кадр берётся картинкой (сцена тайтла из API), а не «паузой на плеере».
/// `AVPlayerLayer`, которому ни разу не давали играть, ничего не рисует — карточка
/// оставалась бы чёрной, пока до неё не доскроллят и не тапнут. Показывать пустоту
/// нельзя: одновременно играет одна карточка, остальные были бы дырами.
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
    /// Тап по карточке: включить её ролик или выключить, если он уже играет.
    let onTap: () -> Void

    @State private var playback = LoopingVideoPlayback()
    @State private var isVideoReady = false

    var body: some View {
        // Кадр задаёт распорка, а видео его заполняет: `aspectRatio` на самом слое
        // считает высоту от идеального размера, а не от пропорции макета,
        // и карточка расползалась на всю ширину экрана. Та же идиома, что у кавера.
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { frame }
            .overlay(alignment: .bottom) { caption }
            .clipShape(shape)
            // Рамка поверх клипа, иначе её съедает скругление. Общая у всех обложек
            // (в макете `2052:10643` — 1 pt; правка пользователя 2026-10-05 — 0.67).
            .coverBorder(shape)
            // Карточка целиком — кнопка. `contentShape` обязателен: и кадр, и подписи
            // сняты с хит-теста, а без формы тап ловят только непрозрачные пиксели.
            .contentShape(shape)
            .pressScale(PressMotion.cardScale)
            .onTapGesture { onTap() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(card.title)
            .accessibilityValue(isActive ? "Играет" : "Остановлен")
            // Ролик заряжается сразу, но не запускается: играть он начнёт по тапу.
            .task(id: clip) { playback.prepare(bundled: clip) }
            // Пауза, а не остановка: ролик зациклен, и вернувшаяся карточка
            // должна продолжить, а не дёрнуться в начало.
            .onChange(of: isActive, initial: true) { _, active in
                active ? playback.start(bundled: clip) : playback.pause()
            }
            .onDisappear { playback.pause() }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    /// Кадр карточки: неподвижная сцена, поверх которой по тапу проявляется видео
    /// и по повторному тапу уходит обратно. Одновременно они бывают только те 0.4с,
    /// пока идёт кроссфейд — ровно как на кавере экрана.
    private var frame: some View {
        ZStack {
            if let still {
                still
                    .resizable()
                    .scaledToFill()
            }

            // Гасим по `isActive`, а не по «хоть раз играл»: `AVPlayerLayer` без единого
            // `play` кадра не рисует, и без этой привязки выключенная карточка показывала
            // бы чёрный прямоугольник вместо своей сцены.
            LoopingVideoLayer(player: playback.queue) { isVideoReady = true }
                .opacity(isActive && isVideoReady ? 1 : 0)
                .animation(.easeInOut(duration: MovieCoverMotion.videoFadeIn), value: isActive)
        }
        .allowsHitTesting(false)
    }

    /// Подписи прижаты к низу стека 256pt с полем 24 — так они стоят в макете
    /// (`justify=MAX`), а не просто «в 24 от нижней кромки карточки».
    private var caption: some View {
        VStack(alignment: .leading, spacing: Self.captionGap) {
            Text(card.title.prefixWords(maxCharacters: Self.titleLimit))
                .plusHeadline(.m)
                .foregroundStyle(Color.fillOne)
            Text(card.subtitle)
                .plusHeadline(.m)
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
private extension String {
    /// Обрезает по границе слова: лимит макета — 50 символов на заголовок карточки.
    func prefixWords(maxCharacters: Int) -> String {
        guard count > maxCharacters else { return self }
        let clipped = String(prefix(maxCharacters))
        guard let space = clipped.lastIndex(of: " ") else { return clipped }
        return String(clipped[..<space]) + "…"
    }
}
