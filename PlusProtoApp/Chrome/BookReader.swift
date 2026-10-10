import SwiftUI
import VariableBlur

// MARK: - Геометрия

/// Числа макета `2311:27488`. Координаты — от физического верха экрана, как у всех
/// экранов проекта: шапка и затемнение лежат поверх текста, текст уезжает под них.
private enum BookReaderLayout {
    /// Поля колонки текста: 354 из 402.
    static let textInset: CGFloat = 24
    /// Строка текста — Text L・18 / Medium из UI kit (в макете 16/25: кегля 16 в UI kit
    /// нет, а для длинного чтения из пяти кеглей подходит 18 — и его строка 24 ближе
    /// всего к макетным 25, ритм колонки почти не меняется).
    static let lineHeight: CGFloat = PlusTextSize.textL.lineHeight
    /// Абзацы разделены пустой строкой — в макете это пустой абзац высотой в строку.
    static let paragraphGap: CGFloat = lineHeight

    /// Верхнее затемнение — `overlay bg` макетов: от верхней кромки (с выносом на 1pt)
    /// чёрный держится до 12.981 % высоты и сходит в ноль к низу. Высота 80 в скрытой
    /// обвязке (`2311:27488`, `2565:25233`) и 153 в показанной (`2565:25464`, 402×153).
    static let scrimTop: CGFloat = -1
    static let scrimSolid: CGFloat = 0.12981
    static let scrimHiddenHeight: CGFloat = 80
    /// Прогрессивный блюр под затемнением (просьба пользователя 2026-10-03): текст,
    /// уходящий под шапку, не только темнеет, но и расплывается. Полоса блюра короче
    /// затемнения — правило проекта: иначе там, где блюр кончается, резкость
    /// обрывалась бы на ровном месте посреди ещё видимого текста.
    static let scrimBlurRadius: CGFloat = 12
    /// Блюр сходит на нет у нижней кромки строки шапки — как подложка навбара
    /// экранов сущностей. Было 140: текст начинал расплываться ещё на подходе
    /// к шапке (правка пользователя 2026-10-03 — «начинается слишком низко»).
    static var scrimBlurHeight: CGFloat { topBarTop + coverSize.height }

    // MARK: Обвязка — «расширенный плеер + обвязка» `2565:25462`

    /// Верхняя панель `2565:25547` (x 16, y 53, 370×40): кнопка 40, обложка 28×40,
    /// подписи 155 — в одном ряду с зазором 8; справа две кнопки 40 с зазором 8
    /// (`2565:25528`, 88×40).
    static let topBarTop: CGFloat = 53
    static let topBarSide: CGFloat = 16
    static let barGap: CGFloat = 8
    static let topBarButton: CGFloat = PlusMetrics.circleButton
    static let titleWidth: CGFloat = 155
    /// Затемнение сверху при показанной обвязке `2565:25464`: 402×153, y −1.
    static let chromeTopGradientHeight: CGFloat = 153
    /// Доля высоты скрытого затемнения от показанного: линейный градиент при сжатии
    /// по вертикали остаётся тем же градиентом, поэтому 80 ↔ 153 — просто transform.
    static var scrimHiddenScale: CGFloat { scrimHiddenHeight / chromeTopGradientHeight }
    /// Размер пилюли мини-плеера в читалке `2565:25233`: 354 (поля 24 с обеих сторон,
    /// рядом нет круга поиска, как в баре, где она 286).
    static var musicExpandedWidth: CGFloat { PlusMetrics.designWidth - textInset * 2 }
    /// Затемнение и блюр снизу: от низа экрана до верхней кромки мини-плеера в показанной
    /// обвязке — 40 + 132 + 60 = 232 (правка пользователя 2026-10-10; в макете
    /// `2565:25526` было 331, градиент начинался выше плеера). Стопы те же, что сверху,
    /// сжаты по высоте.
    static var bottomChromeHeight: CGFloat { musicBottom + musicRaise + PlusMetrics.actionBarCompact }
    /// Без мини-плеера (музыки не было или круг выбросили) затемнение и блюр ниже на 60 —
    /// ровно на высоту плеера: 232 − 60 = 172 (правка пользователя 2026-10-10).
    static var bottomChromeHeightNoMusic: CGFloat { bottomChromeHeight - PlusMetrics.actionBarCompact }
    /// Ход нижнего блока при показе и скрытии: не меньше его собственного выступа над
    /// кромкой (124 + 32 = 156), чтобы блок уезжал за кромку целиком при любой высоте
    /// затемнения. Не зависит от плеера — блок движется как прежде.
    static var bottomBlockTravel: CGFloat { bottomChromeHeight }

    /// Нижний блок `2565:25814`: x 24, 354×124, низ на 32 от кромки; стек с зазором 12.
    static let bottomBlockSide: CGFloat = 24
    static let bottomBlockBottom: CGFloat = 32
    static let bottomBlockSpacing: CGFloat = 12
    /// Строка главы `2565:25824`: текст Text L・18 Medium (24) + иконка 16 с зазором 2.
    static let chapterIconGap: CGFloat = 2
    static let chapterIconSize: CGFloat = 16
    /// Таймлайн `2565:25570` (354×28): подписи Text S・13 в верхних 16, полоса
    /// 354×8 ниже на 4 (y 20), подписи в ряд с зазором 3.
    static let timelineHeight: CGFloat = 28
    static let timelineBarTop: CGFloat = 20
    static let timelineBarHeight: CGFloat = 8
    static let timelineLabelGap: CGFloat = 3
    /// Подложка полосы: backdrop-blur 6 из панели Figma → 3 в коде (см. `GlassSurface`),
    /// бордер 0.67 × белый 8 % (`2565:25571`).
    static let timelineTrackBlur: CGFloat = 3
    /// Ряд из четырёх кнопок `2565:25813`: кнопки 48 без подложки, глиф 24, поля
    /// ряда 32, между кнопками — поровну (x 32 / 112.67 / 193.33 / 274).
    static let controlSize: CGFloat = 48
    static let controlsSide: CGFloat = 32
    static let controlIconSize: CGFloat = 24
    /// Ширина колонки обвязки: 402 − 2 × 24 = 354.
    static var barWidth: CGFloat { PlusMetrics.designWidth - bottomBlockSide * 2 }

    /// Темп чтения для подписи «осталось ~N мин».
    static let wordsPerMinute: Double = 200
    /// Трещотка таймлайна — числа перемотки в плеере музыки (`MusicPlayerMotion`):
    /// одинаковое — одинаково.
    static let scrubTickStep = MusicPlayerMotion.scrubTickStep
    static let scrubTickInterval = MusicPlayerMotion.scrubTickInterval
    static let scrubTickIntensity = MusicPlayerMotion.scrubTickIntensity
    /// Доля прокрутки в `@State` — шагом 0.5 %: полоса не перерисовывается на каждый пиксель.
    static let progressStep: Double = 200

    static let coverSize = CGSize(width: 28, height: 40)
    static let coverCorner: CGFloat = 2
    static let coverToTitle: CGFloat = 8
    /// Подпись автора заходит на строку названия: 24 + 20 − 4 = 40, ровно высота обложки.
    static let titleToAuthor: CGFloat = -4

    /// Первая строка в покое стоит в хвосте затемнения — на последних 25pt градиента,
    /// где он уже почти прозрачен: выше она тонула бы в чёрном, ниже оставляла бы
    /// под шапкой пустую полосу. Макет рисует колонку уже прокрученной, покоя в нём нет.
    /// Константа (было `−1 + 164 − 24` при прежнем затемнении 164): положение текста
    /// не выводится из высоты затемнения, которая теперь 80/153 по макету.
    static let textTop: CGFloat = 139

    /// Мини-плеер музыки — `action bar` 402×60 с полями 24: круг 60 прижат вправо
    /// (`2565:25332` в `2311:27488`), низ на 40 от кромки (y 774).
    static let musicTrailing: CGFloat = 24
    static let musicBottom: CGFloat = 40
    /// При показанной обвязке `action bar` стоит на y 642 (`2565:25471` в `2565:25462`):
    /// на 132 выше, над нижним блоком.
    static let musicRaise: CGFloat = 132
    /// Воздух под последней строкой, когда текст докручен до конца.
    static let textTail: CGFloat = 24
    /// Без мини-плеера последняя строка выходит из-под home indicator.
    static let homeIndicatorClearance: CGFloat = 34
}

enum BookReaderMotion {
    /// Показ и скрытие обвязки: верхняя панель, нижний блок, оба затемнения, сдвиг
    /// мини-плеера и его разворот в пилюлю — одной анимацией (правка пользователя
    /// 2026-10-10: `.smooth`, неспешно).
    static let chrome: Animation = .smooth(duration: 0.4)
    /// Reduce Motion: обвязка только проявляется и гаснет на месте.
    static let chromeReduced: Animation = .easeInOut(duration: 0.2)

    /// Текст проявляется целиком, когда готов, — одним фейдом, без движения:
    /// колонка не должна набираться на глазах абзац за абзацем.
    static let textAppear: Animation = .easeOut(duration: 0.2)

    // MARK: Бросок мини-плеера
    /// Круг цепляется жестом после 10 pt: меньший сдвиг — это ещё тап.
    static let throwActivation: CGFloat = 10
    /// «Закрыть легче, чем открыть»: хватает проекции остановки на 40 pt (две трети круга).
    static let throwDistance: CGFloat = 40
    static let throwFlickVelocity: CGFloat = 500
    /// Улёт за кромку продолжает движение пальца, поэтому ease-out, а не ease-in-out.
    static let throwOut: Animation = .easeOut(duration: 0.25)
    /// Не дотянул — возврат пружиной (значение `SearchPullConfig.release` в баре: тот enum
    /// приватный, а возврат должен ощущаться одинаково).
    static let throwReturn: Animation = .spring(duration: 0.32, bounce: 0.42)
    /// Reduce Motion: круг не летит, а гаснет на месте.
    static let throwReducedFade: Animation = .easeOut(duration: 0.2)
}

// MARK: - Читалка

/// Читалка — три макета: «компактный плеер, скрытая обвязка» `2311:27488`, «расширенный
/// плеер, скрытая обвязка» `2565:25233`, «расширенный плеер + обвязка» `2565:25462`.
/// Текст книги во всю колонку, вертикальная прокрутка; тап по тексту показывает и
/// скрывает обвязку (верхняя панель и нижний блок с затемнениями), а мини-плеер
/// музыки при этом переезжает между y 774 и y 642 — одной анимацией с ней.
///
/// Мини-плеер музыки в углу есть, только если музыка играла в момент запуска
/// (`ContentPlayer.reader(_, showsMusic:)`, правило пользователя 2026-10-03):
/// читать под музыку — штатный сценарий, и управлять ею надо не выходя из книги.
struct BookReaderView: View {
    let book: BookInProgress
    let showsMusic: Bool
    @Environment(ActionBarState.self) private var actionBar
    @State private var text = BookTextStore()
    @State private var isMusicExpanded = false
    /// Круг выкинули свайпом вправо — до конца этого сеанса читалки он не возвращается.
    /// Состояние живёт здесь, а не в `ActionBarState`: следующая читалка стартует с кругом,
    /// а музыка бросок не затрагивает вовсе.
    @State private var isMusicThrown = false
    /// Обвязка (верхняя панель, нижний блок, затемнения) — при открытии скрыта, как в
    /// макетах «скрытая обвязка» `2311:27488` / `2565:25233`; тап по тексту её переключает.
    @State private var isChromeShown = false
    /// Доля прокрутки текста 0…1, шагом 0.5 % (`progressStep`): в `@State` только она.
    @State private var scrollProgress: Double = 0
    /// Слов в тексте — для «осталось ~N мин»; считается один раз, когда текст готов.
    @State private var totalWords = 0
    /// Палец на таймлайне: пока он там, прокрутка текста долю не перезаписывает.
    /// После отпускания доля остаётся где была до следующей прокрутки текста.
    @State private var isScrubbing = false
    @Environment(CollectionStore.self) private var collection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
            pages
            scrim
            chromeTop
            chromeBottomBackdrop
            if showsMusic {
                ReaderMusicPlayer(isExpanded: $isMusicExpanded, isThrown: $isMusicThrown)
                    .padding(.trailing, BookReaderLayout.musicTrailing)
                    .padding(.bottom, BookReaderLayout.musicBottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    // Плеер переезжает между y 774 и y 642 одной анимацией с обвязкой.
                    // Сдвиг нужен и при Reduce Motion — иначе круг лёг бы на нижний
                    // блок, — но там он без анимации: обвязка при этом только проявляется.
                    .offset(y: isChromeShown ? -BookReaderLayout.musicRaise : 0)
                    .animation(reduceMotion ? nil : BookReaderMotion.chrome, value: isChromeShown)
            }
            chromeBottomBlock
        }
        .ignoresSafeArea()
        .task { await text.load(bookID: book.id) }
        .onChange(of: text.isReady, initial: true) { _, isReady in
            guard isReady else { return }
            totalWords = text.pages.reduce(0) { $0 + $1.split(whereSeparator: \.isWhitespace).count }
        }
        #if DEBUG
        // `-debugReaderChrome 1`: через 2с показать обвязку, через 5с скрыть — тот же
        // код, что у тапа по тексту.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugReaderChrome") else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            toggleChrome()
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            toggleChrome()
        }
        #endif
    }

    /// Тап по тексту. Без хаптики: тихий жест, «одна хаптика на действие» — про кнопки.
    private func toggleChrome() {
        setChrome(!isChromeShown)
    }

    /// Показ и скрытие обвязки одной анимацией с мини-плеером: пока обвязка видна,
    /// пилюля развёрнута (правка пользователя 2026-10-10), спрятали — сворачивается
    /// обратно в круг, как раньше при прокрутке. Выброшенного круга это не касается.
    private func setChrome(_ shown: Bool) {
        guard shown != isChromeShown else { return }
        withAnimation(chromeAnimation) {
            isChromeShown = shown
            if showsMusic, !isMusicThrown { isMusicExpanded = shown }
        }
    }

    /// Книга читалки в коллекции «Моё». Пропорций обложки у читалки нет — карточка
    /// встанет в карусель стандартной; id общий с экраном книги.
    private var collectionItem: CollectionItem {
        .book(
            EntityRef(
                id: book.id,
                title: book.title,
                subtitle: book.author ?? text.author ?? "",
                artwork: book.cover
            ),
            aspect: nil
        )
    }

    private var pages: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BookReaderLayout.paragraphGap) {
                ForEach(Array(text.pages.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .plusText(.textL, .medium)
                        // Fill 4 — цвет UI kit для текстовых блоков длиннее двух строк.
                        .foregroundStyle(Color.fillFour)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, BookReaderLayout.textInset)
            .padding(.top, BookReaderLayout.textTop)
            .padding(.bottom, textBottom)
            .opacity(text.isReady ? 1 : 0)
            .animation(BookReaderMotion.textAppear, value: text.isReady)
        }
        .scrollIndicators(.hidden)
        // Отступы колонки отмеряются от физических кромок, как в макете, —
        // системные поля безопасной зоны поверх них не нужны.
        .ignoresSafeArea()
        // Тап по тексту показывает и скрывает обвязку. Тап на самом ScrollView, а не на
        // колонке: ловит всю область, в том числе поля, и не мешает прокрутке; кнопки
        // обвязки и плеер лежат выше и забирают свои касания сами.
        .onTapGesture { toggleChrome() }
        // Доля прокрутки считается и округляется в самом замере: `scrollProgress`
        // пишется, только когда значение сменилось на шаг, а не на каждый кадр прокрутки.
        .onScrollGeometryChange(for: Double.self) { geometry in
            let range = geometry.contentSize.height - geometry.containerSize.height
            guard range > 0 else { return 1 }
            let raw = (geometry.contentOffset.y + geometry.contentInsets.top) / range
            let step = BookReaderLayout.progressStep
            return (min(max(raw, 0), 1) * step).rounded() / step
        } action: { _, progress in
            guard !isScrubbing else { return }
            scrollProgress = progress
        }
        .onScrollPhaseChange { _, phase in
            // Начало жеста пальцем — обвязка уезжает (правка пользователя 2026-10-10).
            // Инерция и программная прокрутка без касания её не трогают.
            if phase == .interacting { setChrome(false) }
            // Вернулся к чтению — плеер сворачивается обратно в круг:
            // развёрнутый, он закрывает низ колонки.
            guard phase.isScrolling, isMusicExpanded else { return }
            withAnimation(ActionBarMotion.morph) { isMusicExpanded = false }
        }
    }

    private var textBottom: CGFloat {
        let clearance = showsMusic
            ? BookReaderLayout.musicBottom + PlusMetrics.actionBarCompact
            : BookReaderLayout.homeIndicatorClearance
        return clearance + BookReaderLayout.textTail
    }

    /// Верхний слой под шапкой: блюр (всегда) и затемнение `overlay bg` — 80 в скрытой
    /// обвязке, 153 в показанной. Затемнение нарисовано в 153 и в скрытом состоянии
    /// сжато по вертикали от верхней кромки: смена состояния — transform, текст не
    /// перекладывается. Анимация та же, что у обвязки.
    private var scrim: some View {
        ZStack(alignment: .top) {
            VariableBlurView(
                maxBlurRadius: BookReaderLayout.scrimBlurRadius,
                direction: .blurredTopClearBottom
            )
            .frame(height: BookReaderLayout.scrimBlurHeight)
            .offset(y: BookReaderLayout.scrimTop)

            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: BookReaderLayout.scrimSolid),
                    .init(color: .black.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: BookReaderLayout.chromeTopGradientHeight)
            .scaleEffect(y: isChromeShown ? 1 : BookReaderLayout.scrimHiddenScale, anchor: .top)
            .offset(y: BookReaderLayout.scrimTop)
            .animation(chromeAnimation, value: isChromeShown)
        }
        .frame(maxWidth: .infinity, maxHeight: BookReaderLayout.chromeTopGradientHeight, alignment: .top)
        .allowsHitTesting(false)
    }

    // MARK: Обвязка

    /// Куда уезжают части обвязки и откуда приходят: за кромку, а не в прозрачность —
    /// уходящее уезжает, а не гаснет раньше. Reduce Motion: никакого движения, только
    /// прозрачность.
    private func hiddenOffset(_ travel: CGFloat) -> CGFloat {
        isChromeShown || reduceMotion ? 0 : travel
    }

    private var hiddenOpacity: Double {
        reduceMotion && !isChromeShown ? 0 : 1
    }

    private var chromeAnimation: Animation {
        reduceMotion ? BookReaderMotion.chromeReduced : BookReaderMotion.chrome
    }

    /// Верхняя панель — приходит сверху за кромку экрана (затемнение под ней — `scrim`).
    private var chromeTop: some View {
        topBar
            .padding(.top, BookReaderLayout.topBarTop)
            .padding(.horizontal, BookReaderLayout.topBarSide)
            .frame(maxWidth: .infinity)
            .offset(y: hiddenOffset(-(BookReaderLayout.topBarTop + BookReaderLayout.topBarButton)))
            .opacity(hiddenOpacity)
            .animation(chromeAnimation, value: isChromeShown)
            .allowsHitTesting(isChromeShown)
            .accessibilityHidden(!isChromeShown)
    }

    /// Мини-плеер в читалке есть, пока музыка была при открытии и круг не выбросили.
    /// Бросить круг можно только при скрытой обвязке, так что смена высоты затемнения
    /// ниже не видна: оно в этот момент за кромкой.
    private var hasPlayer: Bool { showsMusic && !isMusicThrown }

    /// Высота нижнего затемнения и блюра: 232 с плеером, 172 без него.
    private var bottomChromeHeight: CGFloat {
        hasPlayer ? BookReaderLayout.bottomChromeHeight : BookReaderLayout.bottomChromeHeightNoMusic
    }

    /// Затемнение 232 (172 без плеера) снизу (стопы те же, что сверху, повёрнуто на 180°)
    /// и прогрессивный блюр под ним — текст, заходящий под нижний блок, расплывается,
    /// как в кадре макета (сам блюр в данных ноды не отдаётся: радиус и направление —
    /// как у верхнего).
    private var chromeBottomBackdrop: some View {
        ZStack(alignment: .bottom) {
            VariableBlurView(
                maxBlurRadius: BookReaderLayout.scrimBlurRadius,
                direction: .blurredBottomClearTop
            )
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: BookReaderLayout.scrimSolid),
                    .init(color: .black.opacity(0), location: 1),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .frame(height: bottomChromeHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .offset(y: hiddenOffset(bottomChromeHeight))
        .opacity(hiddenOpacity)
        .animation(chromeAnimation, value: isChromeShown)
        .allowsHitTesting(false)
    }

    /// Нижний блок — приходит снизу, лежит над плеером музыки.
    private var chromeBottomBlock: some View {
        ReaderBottomBlock(
            progress: text.isReady ? scrollProgress : 0,
            remainingWords: text.isReady ? Double(totalWords) * (1 - scrollProgress) : nil,
            onScrub: { fraction in
                isScrubbing = true
                let step = BookReaderLayout.progressStep
                scrollProgress = (fraction * step).rounded() / step
            },
            onScrubEnd: { isScrubbing = false }
        )
        .padding(.bottom, BookReaderLayout.bottomBlockBottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .offset(y: hiddenOffset(BookReaderLayout.bottomBlockTravel))
        .opacity(hiddenOpacity)
        .animation(chromeAnimation, value: isChromeShown)
        .allowsHitTesting(isChromeShown)
        .accessibilityHidden(!isChromeShown)
    }

    /// Верхняя панель `2565:25547`: «назад» (закрыть читалку) · обложка · название и автор —
    /// слева; две кнопки — справа. Иконка «назад» в макете — ✕ (тот же `iconCross`).
    private var topBar: some View {
        HStack(spacing: BookReaderLayout.barGap) {
            HStack(spacing: BookReaderLayout.barGap) {
                ReaderCircleButton(icon: "iconCross", fill: .buttonsPrimary, title: "Закрыть") {
                    actionBar.closeContentPlayer()
                }
                HStack(spacing: BookReaderLayout.coverToTitle) {
                    cover
                    titles
                }
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
            HStack(spacing: BookReaderLayout.barGap) {
                // «+» кладёт книгу в «Моё» и становится галочкой; тост про добавление
                // показывает сам `CollectionStore`.
                ReaderCircleButton(
                    icon: "iconAdd",
                    activeIcon: "iconDone",
                    isActive: collection.isFavorite(collectionItem.id),
                    fill: .buttonsSecondary,
                    title: "Добавить"
                ) {
                    collection.toggleFavorite(collectionItem)
                }
                ReaderCircleButton(icon: "iconMore", fill: .buttonsSecondary, title: "Ещё")
            }
        }
        .contentShape(Rectangle())
    }

    /// Кадр задаёт распорка, картинка его заполняет — идиома проекта: наоборот
    /// `scaledToFill` отдал бы наверх размер картинки, а не обложки.
    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: BookReaderLayout.coverCorner, style: .continuous)
        return Color.clear
            .frame(width: BookReaderLayout.coverSize.width, height: BookReaderLayout.coverSize.height)
            .overlay { ArtworkImage(source: book.cover).scaledToFill() }
            .clipShape(shape)
            .coverBorder(shape)
    }

    /// Подписи прижаты к верху бокса обложки, а не центрированы по ней: автор может
    /// доехать из API позже названия, и центрированное название прыгнуло бы вверх.
    private var titles: some View {
        VStack(alignment: .leading, spacing: BookReaderLayout.titleToAuthor) {
            Text(book.title)
                .plusText(.textL, .semibold)
                .foregroundStyle(Color.fillOne)
            if let author = book.author ?? text.author {
                Text(author)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .transition(.opacity)
            }
        }
        .lineLimit(1)
        .frame(width: BookReaderLayout.titleWidth, height: BookReaderLayout.coverSize.height, alignment: .topLeading)
        .animation(BookReaderMotion.textAppear, value: text.author)
    }
}

// MARK: - Обвязка: кнопки и нижний блок

/// Круглая кнопка верхней панели 40×40 (`2565:25465`, `2565:25528`): глиф 20 в той же
/// стеклянной поверхности, что у всех серых кнопок. Заливка — Buttons/Primary 10 %
/// у «назад» и Buttons/Secondary 8 % у пары справа, как в макете. Действия у пары
/// у «ещё» нет: отклик есть (просадка и хаптика), логики нет. У «+» два глифа —
/// `icon` и `activeIcon`, они сменяются кросс-попом, как `LikeGlyph`.
private struct ReaderCircleButton: View {
    let icon: String
    var activeIcon: String? = nil
    var isActive = false
    let fill: Color
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button {
            PlayerHaptics.tap()
            action()
        } label: {
            ZStack {
                glyph(icon)
                    .opacity(isActive ? 0 : 1)
                    .scaleEffect(isActive ? ActionBarMotion.iconSwapScale : 1)
                if let activeIcon {
                    glyph(activeIcon)
                        .opacity(isActive ? 1 : 0)
                        .scaleEffect(isActive ? 1 : ActionBarMotion.iconSwapScale)
                }
            }
            .animation(ActionBarMotion.iconSwap, value: isActive)
            .frame(width: BookReaderLayout.topBarButton, height: BookReaderLayout.topBarButton)
            .secondaryButtonSurface(Circle(), fill: fill)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func glyph(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: GlassIconButtonConfig.iconBox, height: GlassIconButtonConfig.iconBox)
            .foregroundStyle(Color.fillOne)
    }
}

/// Нижний блок `2565:25814` (354×124): строка главы, таймлайн, четыре кнопки.
/// Текст книги — аннотация, глав и страниц нет, поэтому в строке главы — «Аннотация»,
/// а таймлайн — доля прокрутки текста; палец на нём ведёт заливку и подписи (мок:
/// текст не двигается), с трещоткой, как перемотка в плеере музыки.
private struct ReaderBottomBlock: View {
    /// Доля прокрутки 0…1.
    let progress: Double
    /// Сколько слов осталось дочитать; нет — текст ещё не готов.
    let remainingWords: Double?
    /// Палец ведёт таймлайн: доля 0…1.
    let onScrub: (Double) -> Void
    let onScrubEnd: () -> Void

    @State private var ratchet = ScrubRatchet(
        step: BookReaderLayout.scrubTickStep,
        interval: BookReaderLayout.scrubTickInterval,
        intensity: BookReaderLayout.scrubTickIntensity
    )
    /// `GestureState`, а не флаг из `onEnded`: оборванный жест `onEnded` не зовёт
    /// (как в плеере музыки), и прокрутка так и осталась бы заблокированной.
    @GestureState private var isScrubGestureActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: BookReaderLayout.bottomBlockSpacing) {
            chapter
            timeline
            controls
        }
        .frame(width: BookReaderLayout.barWidth)
        .contentShape(Rectangle())
    }

    /// `2565:25824`: название главы и иконка-`action` справа — без действия.
    private var chapter: some View {
        Button {
            PlayerHaptics.tap()
        } label: {
            HStack(spacing: BookReaderLayout.chapterIconGap) {
                Text("Аннотация")
                    .plusText(.textL, .medium)
                    .foregroundStyle(Color.fillOne)
                Image("iconChevronRight")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: BookReaderLayout.chapterIconSize, height: BookReaderLayout.chapterIconSize)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .lineLimit(1)
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    /// `2565:25570`: подписи (Text S・13 Medium) над полосой 354×8 с заливкой orchid.
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: BookReaderLayout.timelineLabelGap) {
                Text(percentLabel)
                    .foregroundStyle(Color.fillOne)
                Text(remainingLabel)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .plusText(.textS, .medium)
            .lineLimit(1)
            .frame(height: PlusTextSize.textS.lineHeight)

            Color.clear
                .frame(width: BookReaderLayout.barWidth, height: BookReaderLayout.timelineBarHeight)
                .secondaryButtonSurface(Capsule(style: .continuous), blur: BookReaderLayout.timelineTrackBlur)
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.plusAccent)
                        .frame(width: BookReaderLayout.barWidth * progress)
                        // Заливка идёт за прокруткой текста — без собственной анимации.
                        .animation(nil, value: progress)
                }
                .padding(.top, BookReaderLayout.timelineBarTop - PlusTextSize.textS.lineHeight)
        }
        .frame(width: BookReaderLayout.barWidth, height: BookReaderLayout.timelineHeight, alignment: .topLeading)
        .contentShape(.rect)
        .gesture(scrubGesture)
        .onChange(of: isScrubGestureActive) { _, active in
            guard !active else { return }
            ratchet.end()
            onScrubEnd()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Прочитано \(percentLabel), \(remainingLabel)")
    }

    /// Касание сразу ставит долю под палец, протяжка ведёт её; вне полосы доля
    /// упирается в 0 и 1. Меряется по всей зоне 354×28.
    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isScrubGestureActive) { _, active, _ in active = true }
            .onChanged { value in
                let width = BookReaderLayout.barWidth
                let x = min(max(0, value.location.x), width)
                onScrub(Double(x / width))
                ratchet.move(to: x)
            }
    }

    private var percentLabel: String {
        "\(Int((progress * 100).rounded()))\u{00A0}%"
    }

    private var remainingLabel: String {
        guard let remainingWords else { return "" }
        let minutes = remainingWords / BookReaderLayout.wordsPerMinute
        if minutes < 1 { return "меньше минуты" }
        return "осталось ~\(Int(minutes.rounded()))\u{00A0}мин"
    }

    /// `2565:25813`: четыре кнопки 48 без подложки. Что значит иконка — заметки,
    /// закладки, шрифт, поиск по тексту; действий пока нет.
    private var controls: some View {
        HStack(spacing: 0) {
            control("iconPencil", title: "Заметки")
            Spacer(minLength: 0)
            control("iconBookmarkPlain", title: "Закладки")
            Spacer(minLength: 0)
            control("iconFontSize", title: "Шрифт")
            Spacer(minLength: 0)
            control("iconSearch", title: "Поиск по тексту")
        }
        .padding(.horizontal, BookReaderLayout.controlsSide)
    }

    private func control(_ icon: String, title: String) -> some View {
        Button {
            PlayerHaptics.tap()
        } label: {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: BookReaderLayout.controlIconSize, height: BookReaderLayout.controlIconSize)
                .foregroundStyle(Color.fillOne)
                .frame(width: BookReaderLayout.controlSize, height: BookReaderLayout.controlSize)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }
}

// MARK: - Музыка в читалке

/// Мини-плеер музыки — тот же компонент, что в action bar, в компактном варианте
/// (`2338:18126`): круг 60 с обложкой. Тап разворачивает его в пилюлю с подписями
/// и play/pause, как круг в баре (правило 2026-08-29). Тап по развёрнутой пилюле
/// открывает большой плеер музыки поверх читалки (`ActionBarState.isMusicOverReader`):
/// закрыл его — снова читалка на том же месте. Свернуть пилюлю — прокруткой текста.
private struct ReaderMusicPlayer: View {
    @Environment(ActionBarState.self) private var actionBar
    @Binding var isExpanded: Bool
    @Binding var isThrown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Сдвиг круга за пальцем. Пишется только пока палец на экране, и применяется
    /// через `offset` (transform), не раскладкой.
    @State private var dragX: CGFloat = 0
    /// Ось выбрана на первом событии жеста: `true` — горизонтальный, `false` — нет, и тогда
    /// весь жест игнорируется (вертикаль — прокрутка текста, она рядом, но не здесь).
    @State private var isHorizontalDrag: Bool?

    var body: some View {
        if let music = actionBar.music {
            MiniPlayerPill(
                item: music,
                trackInfoOpacity: isExpanded ? 1 : 0,
                progressOpacity: isExpanded ? 1 : 0,
                progress: actionBar.musicClock,
                isPlaying: actionBar.isMusicPlaying,
                isLiked: actionBar.isMusicLiked,
                onTogglePlay: { actionBar.toggleMusicPlayback() },
                onToggleLike: { actionBar.toggleMusicLike() },
                onExpand: handleTap,
                expandedWidth: BookReaderLayout.musicExpandedWidth
            )
            // Ширина и кривая — те же, что у пилюли в баре: правый край стоит,
            // левый уезжает, внутренности только проявляются. Ширина — макетные 354
            // (`2565:25233`): круга поиска рядом нет, левый край пилюли на 24.
            // Анимацию разворота задают места, где `isExpanded` меняется: тап по кругу и
            // прокрутка — `ActionBarMotion.morph`, показ обвязки — её кривая (`BookReaderMotion.chrome`).
            .frame(width: isExpanded ? BookReaderLayout.musicExpandedWidth : PlusMetrics.actionBarCompact)
            // Выкинуть можно только круг: в пилюле под пальцем кнопки like/play и тап,
            // который ведёт в большой плеер. Вью после броска остаётся в дереве (убрать
            // его `if` значило бы поменять раскладку и перемонтировать ряд), поэтому
            // касания гасим явно; нижний отступ текста при этом не меняется — колонка
            // не должна ехать на глазах (`textBottom` от броска не зависит).
            // Жест стоит снаружи `offset` и меряется в глобальных координатах:
            // иначе круг, едущий под пальцем, сам сбивал бы свой `translation`.
            .offset(x: isThrown && !reduceMotion ? ActionBarGeometry.trailingEscape : dragX)
            .opacity(isThrown && reduceMotion ? 0 : 1)
            .allowsHitTesting(!isThrown)
            .accessibilityHidden(isThrown)
            .simultaneousGesture(throwGesture, including: isExpanded || isThrown ? .subviews : .all)
            #if DEBUG
            // `-debugReaderMusicTap 1`: через 1.5с тап по кругу, через 3с — по пилюле.
            // Хук зовёт тот же обработчик, что и настоящий тап.
            .task {
                guard UserDefaults.standard.bool(forKey: "debugReaderMusicTap") else { return }
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                handleTap()
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                handleTap()
            }
            // `-debugReaderMusicThrow 1`: через 2с — тот же бросок, что свайп.
            .task {
                guard UserDefaults.standard.bool(forKey: "debugReaderMusicThrow") else { return }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                throwAway()
            }
            #endif
        }
    }

    private var throwGesture: some Gesture {
        DragGesture(minimumDistance: BookReaderMotion.throwActivation, coordinateSpace: .global)
            .onChanged { value in
                if isHorizontalDrag == nil {
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontalDrag == true else { return }
                // Круг 1:1 за пальцем, без анимации; влево не едет.
                dragX = max(0, value.translation.width)
            }
            .onEnded { value in
                defer { isHorizontalDrag = nil }
                guard isHorizontalDrag == true else { return }
                let isThrow = value.predictedEndTranslation.width >= BookReaderMotion.throwDistance
                    || value.velocity.width >= BookReaderMotion.throwFlickVelocity
                if isThrow {
                    throwAway()
                } else {
                    withAnimation(BookReaderMotion.throwReturn) { dragX = 0 }
                }
            }
    }

    /// Бросок: круг улетает за правую кромку (Reduce Motion — гаснет там, где отпустили),
    /// хаптика одна. Музыка не трогается — играет дальше.
    private func throwAway() {
        guard !isThrown else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if reduceMotion {
            withAnimation(BookReaderMotion.throwReducedFade) { isThrown = true }
        } else {
            withAnimation(BookReaderMotion.throwOut) {
                isThrown = true
                dragX = 0
            }
        }
    }

    /// Круг разворачивается в пилюлю, пилюля открывает большой плеер — как в баре.
    private func handleTap() {
        if isExpanded {
            actionBar.openMusicPlayer()
        } else {
            // Разворот круга — тот же отклик, что в баре (`ActionBarView`, `onExpand`):
            // одинаковое — одинаково.
            PlayerHaptics.tap()
            withAnimation(ActionBarMotion.morph) { isExpanded = true }
        }
    }
}
