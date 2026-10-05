import SwiftUI
import UIKit

// MARK: - Motion

/// Тайминги морфа action bar. Подбираются записью simctl + покадровый разбор.
enum ActionBarMotion {
    /// Морф ширин и opacity между четырьмя режимами.
    static let morph: Animation = .smooth(duration: 0.32)
    /// Интервал ротации плейсхолдера (открытый вопрос — стартовое значение 4s).
    static let placeholderInterval: Duration = .seconds(4)
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

    /// Появление и уход внутренностей мини-плеера на морфе круг ↔ пилюля: подписи,
    /// сердце с play и заливка прогресса. Только прозрачность и в обе стороны
    /// одинаково — двигаться им нечем, они разложены по раскрытой ширине
    /// (`ActionBarGeometry.miniPlayerExpandedWidth`).
    ///
    /// Своя кривая, а не общая морфа: 0.32 на прозрачность — это заметно дольше,
    /// чем нужно глазу, и элементы висят полупрозрачными почти весь переход.
    static let miniContentFade: Animation = .easeInOut(duration: 0.2)

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
    /// Фокусная раскладка бара — и над клавиатурой, и в просмотре выдачи без неё
    /// (там бар опущен на место таббара, `lift` положительный).
    var isRaised = false
    var lift: CGFloat = 0
    /// Кривая текущего движения клавиатуры. `nil` — она стоит, и бар едет своим
    /// морфом режимов. Намеренно **не** попадает в `ActionBarLayout`: это не
    /// геометрия, а способ до неё доехать, и ключом анимации быть не должна —
    /// иначе смена самой кривой перезапускала бы переход.
    var motion: Animation?
    static let none = ActionBarRaise()
}

// MARK: - Geometry

/// Числа из figma-actionbar §4, которых нет в Tokens.swift.
/// Не `private`: ширину развёрнутой пилюли читает мини-плеер читалки —
/// он разворачивается в тот же размер, что и в баре.
enum ActionBarGeometry {
    static let searchExpandedWidth: CGFloat = 284
    static let searchPaddingH: CGFloat = 18
    static let searchIconBox: CGFloat = 24
    /// Зазор между полем ввода и крестом очистки.
    static let clearLeadingGap: CGFloat = 8
    /// Во что схлопывается крест в расфокусе. Не ноль: из нуля предмет появляется
    /// «из ниоткуда», а с 0.9 остаётся ощущение, что он просто был сложен.
    static let clearCollapsedScale: CGFloat = 0.9
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
    /// Кнопка «Назад» в поиске — круг 60 слева от поля, зазор 8 (`2385:34087`).
    static let backButtonSize: CGFloat = 60
    static let backButtonGap: CGFloat = 8
    /// На сколько плеер уезжает вправо, скрываясь за кромкой экрана
    static let trailingEscape: CGFloat = 120

    /// Ширина пилюли в раскрытом виде: бар минус поля, круг поиска и зазор между зонами.
    ///
    /// Контент мини-плеера разложен по ней **всегда**, даже когда пилюля сжата в круг:
    /// иначе подписи и кнопки лежат по текущей ширине пилюли и на раскрытии приезжают
    /// слева направо вместе с её кромкой (жалоба пользователя 2026-08-29). С фиксированной
    /// шириной они стоят на своих местах, а морф остаётся чистым: растёт капсула,
    /// внутренности только проявляются.
    ///
    /// Считается от холста прототипа (402), а не замером вью — то же правило, что
    /// у сетки «Похожего»: мерить анимируемую ширину запрещено (CLAUDE.md).
    static var miniPlayerExpandedWidth: CGFloat {
        PlusMetrics.designWidth
            - PlusMetrics.screenMargin * 2
            - PlusMetrics.actionBarCompact
            - PlusMetrics.actionBarGap
    }
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
    /// Порог снятия фокуса по пути пальца вниз. Меньше, чем на открытие: закрывать
    /// всегда должно быть легче, чем открывать, — то же правило, что у шторок.
    static let dismissDistance: CGFloat = 24
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
    /// Текст запроса живёт в `SearchState`, а не в `@State` бара: по нему строится
    /// выдача, а её показывает отдельный слой (`SearchResultsView`).
    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(AppNavigationState.self) private var navigation
    /// Чей это бар: корня или экрана слоя фильма (см. `isLive`).
    @Environment(\.chromeLayer) private var chromeLayer
    @FocusState private var searchFocused: Bool

    /// Живой ли бар — его хром верхний на экране. У экранов, открытых из фильма
    /// дальше, свой хром в слое (2026-10-04), а корневой бар остаётся под слоем:
    /// фокус поиска берёт только верхний, иначе два поля тянули бы его друг у друга.
    private var isLive: Bool {
        navigation.isTop(layer: chromeLayer)
    }

    /// «Назад»: выйти из поиска совсем — стереть запрос, убрать клавиатуру, погасить
    /// просмотр выдачи. Клавиатура уходит тем же мягким уходом, что и на скролле выдачи.
    private func exitSearch() {
        // Из полной выдачи раздела «Назад» сперва возвращает к обзору каруселями —
        // как назад по стеку; из поиска выходит уже следующее нажатие.
        if search.isSubscreenShown {
            search.collapse()
            return
        }
        search.query = ""
        search.isBrowsing = false
        search.dropSuspension()
        let wasFocused = searchFocused
        // Фокус снимаем снаружи и **раньше поля**: снятый в самом поле фокус уводит
        // в просмотр без клавиатуры — и с пустым полем тоже, там «Искали недавно»
        // (см. onChange фокуса). А «Назад» из поиска выходит.
        // Без фокуса тоже пишем: на записи `ActionBarState` повышает режим до поиска,
        // если поле сейчас круг, — музыку могли включить, пока выдача была открыта
        // (выдача → альбом → «Слушать» → назад), и без этого поле схлопнулось бы.
        actionBar.isSearchFocused = false
        if wasFocused {
            keyboard.dismissSmoothly()
            searchFocused = false
        }
    }

    var body: some View {
        @Bindable var search = search
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
        //
        // Зона «Назад» — первой: вне поиска она нулевой ширины, и поле начинается
        // на тех же полях экрана, что и раньше; в поиске она выдвигается слева тем же
        // морфом, что и всё остальное (поле — с x = 84, как в `2385:34087`).
        HStack(spacing: 0) {
            SearchBackButton(layout: layout, action: exitSearch)
                .padding(.leading, layout.screenMargin)

            SearchPill(
                layout: layout,
                searchFocused: $searchFocused,
                query: $search.query,
                isBrowsing: $search.isBrowsing,
                // Стоит над клавиатурой, а не просто стоит: в просмотре раскладка
                // тоже фокусная, и крест (фокус полю) взводил волну ещё до подъёма.
                isBarSettled: keyboard.isUp && raise.motion == nil
            )
            .padding(.leading, layout.backGap)

            TrailingSlot(layout: layout)
        }
        .frame(height: PlusMetrics.actionBarHeight)
        .offset(y: layout.lift)
        // ЕДИНСТВЕННАЯ анимация бара. Порядок обязателен: она оборачивает и HStack,
        // и падинг, и offset — поэтому ширины зон, уезд плеера, поля 24→16 и подъём
        // меняются одним апдейтом, одной кривой, с одной точкой старта.
        // Ключ — сам `layout` (синтезированный ==), а не строка: нельзя «забыть поле»,
        // и на каждом проходе body больше не строится String.
        //
        // Кривая — клавиатурная, пока клавиатура едет, и морф режимов в остальное время.
        // Иначе бар шёл своей `.smooth(0.32)` против её ~0.25 с другой кривой, она
        // уходила вверх быстрее и на мгновение накрывала его собой.
        .animation(raise.motion ?? ActionBarMotion.morph, value: layout)
        .onChange(of: searchFocused) { _, focused in
            // Бар под слоем решений не принимает: его поле теряет фокус само, уходя
            // с окна вместе с экраном, — это не выход из поиска на верхнем экране.
            guard isLive else { return }
            // Снятый фокус при непустой выдаче — в просмотр без клавиатуры (правка
            // пользователя 2026-10-03), и **в том же апдейте**, что и сам фокус.
            // Решение в корне приходило апдейтом позже: слой выдачи на кадр гас,
            // таббар проявлялся, и под выдачей мелькал экран (жалоба 2026-10-03).
            // Только если фокус сняли здесь, в поле (скролл выдачи, свайп по полю,
            // «Найти»): уход в карточку, тап по затемнению и «Назад» снимают его
            // снаружи, через `actionBar`, и решают за себя сами. С пустым полем —
            // тоже просмотр: на экране «Искали недавно» (нулевое состояние 2026-10-03).
            if !focused, actionBar.isSearchFocused, !search.isSuspended {
                search.isBrowsing = true
            }
            actionBar.isSearchFocused = focused
        }
        .onChange(of: actionBar.isSearchFocused) { _, focused in
            // Фокус берёт только живой бар, снимается — у всех.
            if focused, !isLive { return }
            if searchFocused != focused { searchFocused = focused }
        }
        #if DEBUG
        // Отладочные прогоны — только у корневого бара: у бара слоя они запускались бы
        // заново на каждом экране, открытом из фильма.
        .onAppear {
            if chromeLayer == nil, UserDefaults.standard.bool(forKey: "debugSearchFocus") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    searchFocused = true
                }
            }
        }
        .task {
            // `-debugSearchQuery <текст>` — набрать запрос без клавиатуры: выдачу
            // из шелла иначе не увидеть, а печатать по одной букве симулятор не даёт.
            guard chromeLayer == nil,
                  let text = UserDefaults.standard.string(forKey: "debugSearchQuery"), !text.isEmpty else { return }
            // `-debugSearchDelay <сек>` отодвигает фокус: чтобы снять поиск, открытый
            // **с запушенного экрана**, он должен включиться уже после того, как пуш
            // доехал (отладочный тап витрины сам занимает 2.5с).
            let delay = UserDefaults.standard.object(forKey: "debugSearchDelay") as? Double ?? 1
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            searchFocused = true
            search.query = text
        }
        .task {
            // `-debugSearchCycle` — фокус и расфокус поля по кругу. Нужен, чтобы снять
            // на видео **уход** затемнения: тапнуть по нему из шелла нечем, а именно
            // на обратном движении видно, отстаёт слой от клавиатуры или идёт с ней.
            guard chromeLayer == nil, UserDefaults.standard.bool(forKey: "debugSearchCycle") else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                searchFocused = true
                try? await Task.sleep(for: .seconds(3))
                // Выход — как у «Назад»: тем же мягким уходом клавиатуры, что и скролл
                // выдачи. Голый уход клавиатуры теперь оставляет поиск открытым
                // в просмотре («Искали недавно», 2026-10-03), и затемнение не уходило бы.
                exitSearch()
            }
        }
        .task {
            // `-debugMorphCycle` — прогон всех четырёх режимов по кругу, чтобы снять
            // морф на видео: тапнуть по бару из шелла симулятора нельзя.
            guard chromeLayer == nil, UserDefaults.standard.bool(forKey: "debugMorphCycle") else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1600))
                actionBar.cycleDebugMode()
            }
        }
        .task {
            // `-debugFullPlayer` — открыть и закрыть полноэкранный плеер музыки:
            // выезд и уход иначе не снять на видео, тапнуть по пилюле из шелла нечем.
            guard chromeLayer == nil, UserDefaults.standard.bool(forKey: "debugFullPlayer") else { return }
            try? await Task.sleep(for: .seconds(2))
            actionBar.openMusicPlayer()
            try? await Task.sleep(for: .seconds(6))
            actionBar.closeContentPlayer()
        }
        .task {
            // `-debugPlayCycle` — play/pause по кругу: инерцию вращения обложки
            // иначе не снять, кнопку из шелла не нажать.
            guard chromeLayer == nil, UserDefaults.standard.bool(forKey: "debugPlayCycle") else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                actionBar.toggleMusicPlayback()
            }
        }
        .task {
            // `-debugTapChip 1` — тап по чипу кино или книги: киноплеер и читалку
            // из бара иначе не открыть, тапнуть по симулятору из шелла нечем.
            // Пара к `-debugActionBar movie|book`. Задержка — с запасом на заставку.
            guard chromeLayer == nil, UserDefaults.standard.bool(forKey: "debugTapChip") else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            switch actionBar.mode {
            case .movie: if let movie = actionBar.movie { actionBar.watch(movie) }
            case .book: if let book = actionBar.book { actionBar.read(book) }
            case .search, .music: break
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
    /// Ширина правой зоны. **Всегда число**, и это главный инвариант раскладки:
    /// гибкой в баре может быть только левая зона, поэтому сумма зон по построению
    /// равна ширине бара, а «обе широкие» — состояние, которого не существует.
    ///
    /// Раньше роль гибкой зоны переключалась: в `.music` фиксировали поиск, в остальных
    /// режимах — плеер. Переключение `nil` ↔ число не интерполируется, и на кадре смены
    /// обе зоны оказывались гибкими и делили бар пополам: правую сжимало ниже круга,
    /// пилюля вылезала за неё, и клип срезал обложку слева (жалоба пользователя 2026-08-29).
    let trailingWidth: CGFloat
    let showMiniPlayer: Bool
    /// Плеер сейчас круг 60×60. Тап по нему разворачивает бар в музыку, а не открывает
    /// полноэкранный плеер (правило пользователя 2026-08-29).
    let isMiniPlayerCompact: Bool
    let showBookChip: Bool
    let showMovieChip: Bool
    let placeholderOpacity: Double
    let searchIconOnly: Bool
    let trackInfoOpacity: Double
    let progressOpacity: Double
    /// Фокусная раскладка: поле занимает бар целиком, плеер уезжает за кромку.
    /// Она же — у просмотра выдачи без клавиатуры (см. `BottomChrome.raise`).
    let isRaised: Bool
    /// Место под крест в поле — в фокусной раскладке, то есть и в просмотре выдачи.
    /// Виден крест только при непустом запросе (`SearchPill.clearButton`): это сброс
    /// текста, а выход из поиска — кнопка «Назад».
    let showsClear: Bool
    /// Кнопка «Назад» слева от поля — во всех состояниях поиска: пустой фокус, выдача
    /// в фокусе и без него (правка пользователя 2026-10-03, макет `2385:34087`).
    /// Выдача закрывает весь экран, до затемнения не дотянуться — это и есть выход.
    let showsBack: Bool
    /// Ширина зоны «Назад» и зазор от неё до поля: 0 вне поиска, 60 + 8 в поиске.
    let backWidth: CGFloat
    let backGap: CGFloat
    /// Подъём над клавиатурой — свойство ОБЩЕГО предка обеих зон, а не зоны.
    let lift: CGFloat
    let screenMargin: CGFloat
    /// Зазор между зонами (бывший HStack spacing).
    let gap: CGFloat

    init(mode: ActionBarMode, hasMusic: Bool, raise: ActionBarRaise) {
        let compact = PlusMetrics.actionBarCompact
        isRaised = raise.isRaised
        showsClear = raise.isRaised
        showsBack = raise.isRaised
        backWidth = raise.isRaised ? ActionBarGeometry.backButtonSize : 0
        backGap = raise.isRaised ? ActionBarGeometry.backButtonGap : 0
        lift = raise.lift
        screenMargin = raise.isRaised ? ActionBarGeometry.focusedScreenMargin : PlusMetrics.screenMargin

        // Фокус поиска перекрывает режим: поле занимает бар целиком, плейсхолдер гаснет,
        // а плеер уезжает вправо за кромку экрана (`2021:11248` — в баре остаётся
        // только поле 370pt при полях 16).
        if raise.isRaised {
            trailingWidth = 0
            gap = 0
            // Слои остаются в дереве, чтобы уехать, а не мигнуть исчезновением.
            // Мини-плеер только в своих режимах: иначе в .book/.movie он оказывался
            // активным одновременно с чипом и проявлялся из блюра прямо во время уезда.
            showMiniPlayer = hasMusic && (mode == .music || mode == .search)
            // Уехавший за кромку плеер тапов не ловит — компактным его звать незачем.
            isMiniPlayerCompact = false
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
            isMiniPlayerCompact = hasMusic
            showBookChip = false
            showMovieChip = false
            placeholderOpacity = 1
            trackInfoOpacity = 0
            progressOpacity = 0
            searchIconOnly = false
            // Свёрнутый плеер — круг; без музыки правой зоны нет вовсе.
            trailingWidth = hasMusic ? compact : 0
            gap = hasMusic ? PlusMetrics.actionBarGap : 0

        case .music:
            showMiniPlayer = hasMusic
            isMiniPlayerCompact = false
            showBookChip = false
            showMovieChip = false
            // Фокус перехвачен ранним return выше — сюда попадаем только вне фокуса.
            trackInfoOpacity = 1
            progressOpacity = 1

            if !hasMusic {
                searchIconOnly = false
                placeholderOpacity = 1
                trailingWidth = 0
                gap = 0
            } else {
                // Поле сжимается в круг, плеер занимает раскрытую ширину. Она задана
                // числом, а не остатком: гибкой остаётся только левая зона (см. выше).
                searchIconOnly = true
                placeholderOpacity = 0
                trailingWidth = ActionBarGeometry.miniPlayerExpandedWidth
                gap = PlusMetrics.actionBarGap
            }

        case .book:
            showMiniPlayer = false
            isMiniPlayerCompact = false
            showBookChip = true
            showMovieChip = false
            placeholderOpacity = 1
            searchIconOnly = false
            trackInfoOpacity = 0
            progressOpacity = 0
            trailingWidth = ActionBarGeometry.bookChipAABBWidth
            gap = PlusMetrics.actionBarGap

        case .movie:
            showMiniPlayer = false
            isMiniPlayerCompact = false
            showBookChip = false
            showMovieChip = true
            placeholderOpacity = 1
            searchIconOnly = false
            trackInfoOpacity = 0
            progressOpacity = 0
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
    /// Выдача открыта без фокуса — поле показывает запрос, а не плейсхолдер.
    /// Привязка, а не значение: крест закрывает и такой поиск.
    @Binding var isBrowsing: Bool
    /// Бар стоит: клавиатура не едет. По этому признаку взводится «Поиск по всему».
    let isBarSettled: Bool

    /// «Поиск по всему» взведён: в этом фокусе бар уже доехал до клавиатуры.
    /// Защёлка, а не прямое условие: клавиатура едет и без смены фокуса (переход
    /// на эмодзи, другая раскладка), и плейсхолдер мигал бы на каждом её сдвиге.
    @State private var isFocusedPlaceholderArmed = false
    /// Шкала волны «Поиск по всему»: 0 — не видно, 1 — вся строка на месте.
    @State private var focusedPlaceholderWave: Double = 0
    /// Волна в этом фокусе уже сыграна: второй показ (стёрли запрос) — без неё.
    @State private var didPlayFocusedPlaceholderWave = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Мягкий уход клавиатуры по «Найти» (`dismissSmoothly`).
    @Environment(KeyboardObserver.self) private var keyboard

    /// Натяжение резины 0…1. Живёт здесь, а не в `ActionBarState`: запись 120 раз
    /// в секунду в `@Observable` инвалидировала бы весь хром — плеер, таббар, подложку.
    @State private var pull: CGFloat = 0
    /// Хаптика порога уже отдана.
    @State private var tickArmed = false
    /// Текущий жест уже снял фокус. Открыть поиск обратно он больше не может:
    /// закрытие и открытие в одном протягивании — это всегда ошибка отсчёта,
    /// а не намерение пользователя.
    @State private var dismissedByPull = false

    private var stretch: CGFloat { pull * SearchPullConfig.heightLimit }

    /// Куда растёт капсула. Резина одна и та же, отличается только якорь:
    /// вне фокуса тянут вверх и на месте остаётся нижняя кромка (капсула идёт
    /// туда, куда сейчас уедет), в фокусе тянут вниз и на месте остаётся верхняя.
    /// Чистый transform поверх выросшего фрейма, раскладку не трогает.
    private var stretchOffset: CGFloat {
        searchFocused ? stretch / 2 : -stretch / 2
    }

    /// Сжимается только гибкая капсула: у круга 60pt те же 16pt — это 27% ширины,
    /// и HStack тащил бы за собой мини-плеер каждый кадр.
    private var squeeze: CGFloat {
        layout.searchIconOnly ? 0 : pull * SearchPullConfig.widthLimit
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
                        .opacity(isBrowsing ? 0 : layout.placeholderOpacity)
                        // В просмотр бегущая фраза уходит сразу, без морфа бара:
                        // иначе 0.32 с она лежала бы на «Поиске по всему» (ревью
                        // 2026-10-03, возврат из карточки в «Искали недавно»). Только
                        // на входе: на выходе раскладка бара меняется тем же апдейтом,
                        // и без морфа фраза встала бы на финальный x поверх едущей
                        // лупы. Там её везёт морф, а «Поиск по всему» и так гаснет сразу.
                        .transaction(value: isBrowsing) { [isBrowsing] transaction in
                            if isBrowsing { transaction.animation = nil }
                        }
                    focusedPlaceholder
                }
                // Поле ввода живёт всегда, но до фокуса невидимо: пересоздавать его
                // по условию — значит терять фокус и каретку на первом же кадре.
                // Гейт по сырому фокусу, а не по раскладке: каретка и набранный текст
                // видны сразу, даже если клавиатура ещё не пришла. В просмотре выдачи
                // без фокуса поле тоже видно — внизу стоит тот запрос, чью выдачу видно.
                input
                    .opacity(searchFocused || isBrowsing ? 1 : 0)
            }

            // Крест живёт в дереве всегда и схлопывается в ноль по ширине.
            //
            // Раньше он вставлялся по `if` — то есть рождался уже на своём финальном
            // месте и просто проявлялся, читаясь как приклеенный к прилетевшему полю.
            // Теперь он с самого начала лежит в том же `HStack`, что и лупа с вводом,
            // поэтому едет вместе с правой кромкой поля: и когда та расширяется,
            // и когда поле поднимается над клавиатурой. Ширина и отступ интерполируются
            // в той же единственной транзакции бара, что и всё остальное.
            clearButton
                .scaleEffect(
                    isClearVisible ? 1 : ActionBarGeometry.clearCollapsedScale,
                    anchor: .trailing
                )
                .opacity(isClearVisible ? 1 : 0)
                // Появляется с первой буквой и уходит со стёртой — за 250 мс (правка
                // пользователя 2026-10-03). Своя анимация только на смену текста:
                // морф бара по-прежнему везёт единственная анимация бара.
                .animation(SearchClearMotion.fade, value: query.isEmpty)
                // Ширина анимируется, а это проход раскладки на кадр. Здесь он
                // несущий: без схлопывания ширины крест переполнит контент круга
                // 60pt и утащит лупу влево — та же ловушка, что описана выше про
                // общий `spacing`. Бар и так анимирует ширины зон, класс работы
                // не меняется.
                .frame(width: layout.showsClear ? ActionBarGeometry.searchIconBox : 0)
                .padding(.leading, layout.showsClear ? ActionBarGeometry.clearLeadingGap : 0)
                // Схлопнутый и погасший крест остаётся в дереве — гасим хит-тест
                // явно, иначе он ловил бы касания в свёрнутом поле.
                .allowsHitTesting(isClearVisible)
        }
        .padding(.horizontal, ActionBarGeometry.searchPaddingH)
        // Левая зона гибкая всегда: она забирает остаток бара после правой.
        // Ролями зоны больше не меняются — см. `ActionBarLayout.trailingWidth`.
        .frame(maxWidth: .infinity)
        .frame(height: PlusMetrics.actionBarHeight + stretch)
        .glassPill()
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        // Фрейм растёт вокруг центра — сдвиг на половину прижимает одну кромку
        // на месте, а уходит только противоположная (см. `stretchOffset`).
        .offset(y: stretchOffset)
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
            if !focused {
                isFocusedPlaceholderArmed = false
                didPlayFocusedPlaceholderWave = false
            }
        }
        .onChange(of: searchFocused && layout.isRaised && isBarSettled) { _, ready in
            guard ready else { return }
            // Строка уже «показана», но ждёт взвода (крест в просмотре: фокус есть,
            // бар только что доехал) — волну запускает взвод. Иначе её запустит
            // смена показа ниже, как только взвод её включит.
            let waiting = isFocusedPlaceholderShown && focusedPlaceholderWave == 0
            isFocusedPlaceholderArmed = true
            if waiting { playFocusedPlaceholderWave() }
        }
        // Из просмотра — в ввод, а строка уже стоит (пустое поле в просмотре): бар
        // поднимается вместе с ней. Взводим сразу, иначе между концом просмотра
        // и защёлкой строка гасла бы и проявлялась волной заново.
        .onChange(of: isBrowsing) { _, browsing in
            if !browsing, searchFocused, focusedPlaceholderWave == 1 {
                isFocusedPlaceholderArmed = true
                didPlayFocusedPlaceholderWave = true
            }
        }
        // Волна — один раз за фокус, когда бар доехал до клавиатуры. Вернулся
        // плейсхолдер потому, что стёрли запрос, — встаёт сразу, как системный:
        // стирают десятки раз за сессию, и полсекунды волны каждый раз — шум (ревью
        // анимации 2026-10-03). Гаснет всегда мгновенно — под первой буквой, на снятии
        // фокуса; без транзакции, иначе строка таяла бы обратной волной поверх текста.
        .onChange(of: isFocusedPlaceholderShown) { _, shown in
            var instant = Transaction()
            instant.disablesAnimations = true
            guard shown else {
                withTransaction(instant) { focusedPlaceholderWave = 0 }
                return
            }
            // В просмотре без фокуса (возврат из карточки в «Искали недавно») строка
            // просто стоит: поле никто не открывал.
            guard searchFocused else {
                withTransaction(instant) { focusedPlaceholderWave = 1 }
                return
            }
            // Фокус есть, а бар ещё едет к клавиатуре (крест в просмотре): проявление
            // на ходу читалось бы выездом снизу — ждём взвода (ревью 2026-10-03).
            guard isFocusedPlaceholderArmed else {
                withTransaction(instant) { focusedPlaceholderWave = 0 }
                return
            }
            playFocusedPlaceholderWave()
        }
    }

    /// «Поиск по всему» в фокусе: волной в первый раз за фокус, дальше — сразу.
    private func playFocusedPlaceholderWave() {
        var instant = Transaction()
        instant.disablesAnimations = true
        guard !didPlayFocusedPlaceholderWave else {
            withTransaction(instant) { focusedPlaceholderWave = 1 }
            return
        }
        didPlayFocusedPlaceholderWave = true
        withTransaction(instant) { focusedPlaceholderWave = 0 }
        withAnimation(.linear(duration: focusedPlaceholderWaveDuration)) {
            focusedPlaceholderWave = 1
        }
    }

    /// «Поиск по всему» на экране: поле пустое, и либо фокус и бар доехал
    /// до клавиатуры, либо просмотр «Искали недавно» без клавиатуры.
    private var isFocusedPlaceholderShown: Bool {
        query.isEmpty && (isBrowsing || (searchFocused && isFocusedPlaceholderArmed))
    }

    /// Вся волна — от первого глифа до последнего; с «уменьшением движения» —
    /// одна прозрачность строки.
    private var focusedPlaceholderWaveDuration: Double {
        reduceMotion
            ? SearchPlaceholderMotion.focusedReducedFade
            : SearchPlaceholderMotion.focusedWave.total(glyphs: Self.focusedPlaceholderText.count)
    }

    /// Свайп вверх по полю: капсула тянется как резина, на пороге открывается поиск.
    /// Фокус ставится только на отпускании — иначе бар прыгнет вверх из-под пальца.
    ///
    /// Обратное движение — свайп вниз по уже сфокусированному полю — снимает фокус:
    /// клавиатура уезжает, бар опускается. Здесь фокус снимается **сразу на пороге**,
    /// не дожидаясь отпускания: жест повторяет привычный сброс клавиатуры протягиванием,
    /// а он идёт за пальцем.
    private var pullGesture: some Gesture {
        // **Глобальное** пространство, не локальное. Снятие фокуса опускает бар из-под
        // пальца сразу на высоту клавиатуры, и в локальных координатах это читается как
        // рывок пальца вверх на те же ~300pt: жест, который только что закрыл поиск,
        // тут же видел «протяжку вверх за порог» и на отпускании открывал его обратно.
        // Ровно то, что ловится медленным свайпом вниз с задержкой перед отпусканием.
        // В глобальных координатах движение вью на замер не влияет.
        DragGesture(minimumDistance: SearchPullConfig.activation, coordinateSpace: .global)
            .onChanged { value in
                guard !searchFocused else {
                    // Та же резина, что на подъёме, только вниз: капсула тянется
                    // за пальцем, а на пороге отпускает клавиатуру.
                    pull = SearchPullConfig.progress(travel: value.translation.height)
                    if value.translation.height >= SearchPullConfig.dismissDistance {
                        searchFocused = false
                        dismissedByPull = true
                        // Резина расходится вместе со снятием фокуса — иначе капсула
                        // поехала бы вниз растянутой и «схлопнулась» уже на месте.
                        withAnimation(ActionBarMotion.morph) { pull = 0 }
                    }
                    return
                }
                // Один жест либо закрывает, либо открывает. Защёлка на случай, если
                // до отпускания придёт ещё что-нибудь, что сдвинет отсчёт.
                guard !dismissedByPull else { return }
                let travel = -value.translation.height
                // Без withAnimation: резина идёт за пальцем один в один.
                pull = SearchPullConfig.progress(travel: travel)
                updateTick(travel: travel)
            }
            .onEnded { value in
                tickArmed = false
                guard !dismissedByPull else {
                    dismissedByPull = false
                    pull = 0
                    return
                }
                guard !searchFocused else {
                    // Короткий рывок вниз закрывает, не дотягивая до порога, — зеркально
                    // тому, как рывок вверх открывает.
                    let down = value.translation.height
                    let flickDown = value.velocity.height >= SearchPullConfig.flickVelocity
                        && down >= SearchPullConfig.flickMinDistance
                        && down > abs(value.translation.width)
                    if down >= SearchPullConfig.dismissDistance || flickDown {
                        searchFocused = false
                        // Уходит вместе с баром — тем же морфом, что и подъём.
                        withAnimation(ActionBarMotion.morph) { pull = 0 }
                    } else {
                        // Не дотянули: резина возвращается сама, своей кривой.
                        withAnimation(SearchPullConfig.release) { pull = 0 }
                    }
                    return
                }
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
            // Видимую подсказку рисует `focusedPlaceholder`, а VoiceOver читает её здесь.
            .accessibilityLabel("Поиск по всему")
            .textFieldStyle(.plain)
            // Каретка — наш фиолетовый, тот же, что у активного чипса (правка
            // пользователя 2026-10-05; была белой).
            .tint(Color.moviesAccent)
            .foregroundStyle(Color.fillOne)
            // Не `plusHeadline`: у поля точная строка срезала хвосты букв снизу.
            .plusHeadlineField(.s)
            .submitLabel(.search)
            // «Найти» — тем же мягким уходом клавиатуры, что скролл выдачи: системный
            // уход перегружен в начало, и бар, едущий своей кривой, за ним отставал
            // (правка пользователя 2026-10-05). Дальше — как при любом снятом фокусе:
            // выдача в просмотре без клавиатуры.
            .onSubmit { keyboard.dismissSmoothly() }
            // Без автокоррекции — и, как следствие, без строки автоподсказок
            // (QuickType): она стояла плашкой прямо под полем и отбирала у выдачи
            // полсотни пунктов (правка пользователя 2026-08-25).
            .autocorrectionDisabled(true)
            // Первая буква — заглавная: клавиатура открывается с включённым шифтом
            // (правка пользователя 2026-10-03; прежде заглавные были выключены
            // вовсе). Строку подсказок это не возвращает — её держит автокоррекция.
            .textInputAutocapitalization(.sentences)
            // opacity 0 в SwiftUI не выключает хит-тест: без этого невидимое поле
            // перехватывало бы касания мимо жеста резины. Гейт тот же, что и у opacity.
            .allowsHitTesting(searchFocused)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Крест виден в поиске, когда в поле есть хоть один символ.
    private var isClearVisible: Bool {
        layout.showsClear && !query.isEmpty
    }

    /// Крест справа — **сброс текста** (правка пользователя 2026-10-03; выход из поиска
    /// теперь у кнопки «Назад»). Фокус остаётся: стёрли — набирают новое. В просмотре
    /// выдачи без клавиатуры поле получает фокус: иначе пустой запрос без клавиатуры
    /// оставил бы поиск ни в выдаче, ни во вводе. В макете 24×24 с полем 18 от правого
    /// края поля — на месте общего внутреннего отступа пилюли.
    private var clearButton: some View {
        Button {
            query = ""
            if !searchFocused { searchFocused = true }
        } label: {
            Image("iconCross")
                .renderingMode(.template)
                .resizable()
                .frame(width: ActionBarGeometry.searchIconBox, height: ActionBarGeometry.searchIconBox)
                .foregroundStyle(Color.searchIcon)
                .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Стереть запрос")
    }

    private var searchIcon: some View {
        Image("iconSearch")
            .renderingMode(.template)
            .resizable()
            .frame(width: ActionBarGeometry.searchIconBox, height: ActionBarGeometry.searchIconBox)
            .foregroundStyle(Color.searchIcon)
    }

    /// «Поиск по всему» — в фокусе, пока поле пустое (правка пользователя 2026-10-03).
    /// Бегущие фразы предлагают сервисы, а в фокусе поле уже ждёт ввода, и подсказка
    /// одна: искать можно по всему сразу.
    ///
    /// Проявляется волной, глиф за глифом (правка пользователя 2026-10-03), — на месте,
    /// когда бар уже доехал до клавиатуры (`isFocusedPlaceholderArmed`): проявление
    /// посреди подъёма читалось как выезд снизу. Гаснет мгновенно — под первой буквой,
    /// как системный плейсхолдер, и на снятии фокуса, ещё до того, как бар тронулся.
    /// Шкала волны меняется только вместе с видимостью, а та — никогда в одном апдейте
    /// с раскладкой бара, поэтому геометрию её анимация не перехватывает.
    private var focusedPlaceholder: some View {
        Text(Self.focusedPlaceholderText)
            .plusHeadline(
                .s,
                wave: SearchPlaceholderMotion.focusedWave,
                progress: focusedPlaceholderWave,
                reduceMotion: reduceMotion
            )
            .foregroundStyle(Self.focusedPlaceholderColor)
            .frame(height: SearchPlaceholderMotion.lineHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            // Для VoiceOver подсказка — у самого поля, вторая копия была бы шумом.
            .accessibilityHidden(true)
    }

    /// Бледнее бегущих фраз (`searchPlaceholder`, белый 30 %): те зовут в сервисы,
    /// а эта только подписывает пустое поле (правка пользователя 2026-10-03).
    private static let focusedPlaceholderColor = Color.white.opacity(0.2)
    fileprivate static let focusedPlaceholderText = "Поиск по всему"

    private var placeholderStack: some View {
        ZStack(alignment: .leading) {
            // Пауза совпадает с гашением плейсхолдера — значит по раскладке.
            SearchPlaceholderTicker(isPaused: layout.isRaised || isBrowsing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Без `clipped()`: он срезал бы 4pt хода подмены. Границу и так держит
        // капсула поля, а фразы заведомо уже доступной ширины.
        .allowsHitTesting(false)
    }
}

/// Подмена плейсхолдера поиска.
private enum SearchPlaceholderMotion {
    /// Ход по вертикали: уходящий вниз, приходящий сверху.
    static let travel: CGFloat = 4
    /// Уход: обычный ease-in-out — фраза спокойно убирается с дороги.
    /// Длительность парная с `swapOutDuration`, их правят вместе: по одной анимируется
    /// движение, по второй ждёт цикл подмены.
    static let swapOut: Animation = .timingCurve(0.4, 0, 0.6, 1, duration: 0.26)
    static let swapOutDuration: Duration = .milliseconds(260)
    /// Приход: сильный ease-out, движение видно с первого кадра, торможение длинное.
    static let swapIn: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.36)
    /// Пауза между уходом и приходом. Глаз должен увидеть пустое поле — тогда смена
    /// читается как «одна фраза сменила другую», а не как проявление сквозь неё.
    static let swapGap: Duration = .milliseconds(100)
    /// Высота строки плейсхолдера — тот же стиль, что у фраз (`plusHeadline(.s)`).
    static let lineHeight: CGFloat = PlusHeadline.s.lineHeight
    /// Волна «Поиск по всему» — на месте, когда бар уже стоит: к этому времени бегущая
    /// фраза погасла вместе с подъёмом, и нахлёста нет. Символы встают резко, без
    /// проявления прозрачностью и без сдвига — как печать (правки пользователя
    /// 2026-10-03 и 2026-10-04; прежде глиф проявлялся за 240 мс). Шаг 30 мс по буквам
    /// и пауза 120 мс перед словом — «Поиск — по — всему»: слегка ручной набор, а не
    /// ровная лента (правка пользователя 2026-10-05). Вся строка — ~0.6 с; волну
    /// попросили видимой, она ничего не блокирует и гаснет мгновенно.
    static let focusedWave = HeadlineWave.typing(SearchPill.focusedPlaceholderText, stagger: 0.03, pause: 0.12)
    /// С «уменьшением движения» — без волны: строка проявляется целиком, прозрачностью
    /// за 250 мс (как было до волны).
    static let focusedReducedFade: Double = 0.25
}

/// Плейсхолдеры поиска: подмена со сдвигом на 4pt, уход и приход разведены по времени.
///
/// Карусели больше нет. Вертикальная лента прокручивала все три фразы разом и
/// читалась как механизм — было видно, что за кадром едет лишний текст.
///
/// **Одна строка, три фазы, а не две вью с `transition`.** Через переход это не
/// собирается: SwiftUI ставит уход и приход в одну транзакцию, и обе фразы
/// оказываются полупрозрачными в одном кадре — тот самый нахлёст. Собственная
/// анимация на половинках `.asymmetric` этого не лечит: задержка у вставки
/// сдвигает старт, но уходящая вью всё равно живёт в дереве рядом с приходящей.
/// Поэтому фраза здесь **одна**, а смена — последовательность: уехала вниз и погасла →
/// текст подменился, пока прозрачность 0 → выехала сверху и проявилась.
private struct SearchPlaceholderTicker: View {
    var isPaused: Bool

    /// Где строка находится сейчас. `.above` и `.below` — одно и то же невидимое
    /// состояние, отличаются только стороной, с которой строка входит и выходит.
    private enum Phase {
        case above, visible, below
    }

    /// Ход подмены — движение декоративное: оно ничего не объясняет, только
    /// намекает на смену фразы. При включённом «уменьшении движения» его надо
    /// убрать, но не гасить подмену целиком: смена помогает понять, что текст
    /// изменился, и остаётся.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// По глаголу на сервис — и только они (правка пользователя 2026-10-03: «Найти»
    /// и «Создать» убраны).
    private static let phrases = [
        "Послушать",
        "Посмотреть",
        "Почитать",
    ]

    @State private var activeIndex = 0
    @State private var phase: Phase = .visible

    var body: some View {
        phrase(Self.phrases[activeIndex])
            .opacity(phase == .visible ? 1 : 0)
            .offset(y: offsetY)
            .frame(height: SearchPlaceholderMotion.lineHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Клипа нет: он срезал бы те самые 4pt хода. Границу держит капсула поля.
            .task(id: isPaused) {
                guard !isPaused else {
                    // Пауза застаёт строку в любой фазе, в том числе в невидимой.
                    // Без сброса плейсхолдер так и остался бы пустым.
                    var instant = Transaction()
                    instant.disablesAnimations = true
                    withTransaction(instant) { phase = .visible }
                    return
                }
                await runPlaceholderLoop()
            }
    }

    private var offsetY: CGFloat {
        switch phase {
        case .above: -travel
        case .visible: 0
        case .below: travel
        }
    }

    private var travel: CGFloat {
        reduceMotion ? 0 : SearchPlaceholderMotion.travel
    }

    /// Троеточие статичное: набегающие точки читались как индикатор загрузки —
    /// будто поле думает, — хотя ничего не происходит.
    private func phrase(_ text: String) -> some View {
        Text(text + "...")
            .plusHeadline(.s)
            .foregroundStyle(Color.searchPlaceholder)
    }

    private func runPlaceholderLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: ActionBarMotion.placeholderInterval)
            guard !Task.isCancelled else { return }

            withAnimation(SearchPlaceholderMotion.swapOut) { phase = .below }
            try? await Task.sleep(for: SearchPlaceholderMotion.swapOutDuration)
            guard !Task.isCancelled else { return }

            // Подмена текста и переброс на исходную позицию — строго без анимации:
            // иначе строка проедет снизу вверх через всё поле, а видно этого быть
            // не должно, она в этот момент прозрачная.
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                activeIndex = (activeIndex + 1) % Self.phrases.count
                phase = .above
            }

            try? await Task.sleep(for: SearchPlaceholderMotion.swapGap)
            guard !Task.isCancelled else { return }
            withAnimation(SearchPlaceholderMotion.swapIn) { phase = .visible }
        }
    }
}

// MARK: - Назад

/// Появление и уход креста при наборе: сильный ease-out за 250 мс (правка
/// пользователя 2026-10-03; первая версия — 200).
private enum SearchClearMotion {
    static let fade: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.25)
}

/// Кнопка «Назад» в поиске — стеклянный круг 60 со стрелкой влево (`2385:34087`,
/// `close button`). Живёт в дереве всегда: вне поиска её зона нулевой ширины, а сама
/// кнопка уехала за левую кромку экрана — зеркально тому, как плеер в фокусе уезжает
/// за правую. Так она выдвигается и прячется тем же морфом бара, без вставки по `if`.
private struct SearchBackButton: View {
    let layout: ActionBarLayout
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Тот же глиф, что у шевронов, — без отзеркаливания он и есть «назад».
            Image("iconDropleft")
                .renderingMode(.template)
                .resizable()
                .frame(width: ActionBarGeometry.searchIconBox, height: ActionBarGeometry.searchIconBox)
                .foregroundStyle(Color.searchIcon)
                .frame(width: ActionBarGeometry.backButtonSize, height: ActionBarGeometry.backButtonSize)
                .glassPill()
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Назад")
        .opacity(layout.showsBack ? 1 : 0)
        .offset(x: layout.showsBack ? 0 : -(ActionBarGeometry.backButtonSize + layout.screenMargin))
        // Зона растёт вместе с выездом кнопки; кнопка прижата к её правому краю
        // и в нулевой зоне целиком за кромкой.
        .frame(width: layout.backWidth, alignment: .trailing)
        .allowsHitTesting(layout.showsBack)
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
        // Каждый слой получает ширину зоны сам (`zoneWidth`), и это несущее правило.
        // Иначе `ZStack` берёт размер по самому широкому ребёнку — а в зоне лежат все
        // три плеера разом, включая чип кино 91.5 с нулевой прозрачностью. Мини-плеер
        // с `maxWidth: .infinity` растягивался по нему: вместо круга 60 выходила
        // капсула 91.5, обрезанная кромкой экрана (жалоба пользователя 2026-08-29).
        //
        // Выравнивание по левой кромке — там же: чип, который шире зоны, обязан
        // вылезать вправо, где `TrailingClipShape` ничего не режет, а не влево.
        ZStack(alignment: .leading) {
            if let music = actionBar.music {
                MiniPlayerPill(
                    item: music,
                    trackInfoOpacity: layout.trackInfoOpacity,
                    progressOpacity: layout.progressOpacity,
                    progress: actionBar.musicProgress,
                    isPlaying: actionBar.isMusicPlaying,
                    isLiked: actionBar.isMusicLiked,
                    onTogglePlay: { actionBar.toggleMusicPlayback() },
                    onToggleLike: { actionBar.toggleMusicLike() },
                    // Из круга разворачиваем плеер в баре, из широкой пилюли —
                    // открываем полноэкранный (правило пользователя 2026-08-29).
                    // Полноэкранный из круга не открываем: круг — это свёрнутый
                    // плеер, и первый тап обязан его развернуть.
                    onExpand: {
                        if layout.isMiniPlayerCompact {
                            actionBar.expandMiniPlayer()
                        } else {
                            actionBar.openMusicPlayer()
                        }
                    }
                )
                .zoneWidth(layout)
                .blurReplaceLayer(layout.showMiniPlayer)
            }

            // Чипы — «продолжить читать» и «продолжить смотреть»: тап открывает
            // читалку и киноплеер (в макете они и нарисованы развёрнутыми
            // именно под этот переход).
            if let book = actionBar.book {
                ChipButton(title: book.title, action: { actionBar.read(book) }) {
                    BookChip(cover: book.cover)
                }
                .zoneWidth(layout)
                .blurReplaceLayer(layout.showBookChip)
            }

            if let movie = actionBar.movie {
                ChipButton(title: movie.title, action: { actionBar.watch(movie) }) {
                    MovieChip(still: movie.still)
                }
                .zoneWidth(layout)
                .blurReplaceLayer(layout.showMovieChip)
            }
        }
        // Ширина зоны — всегда число, поэтому она интерполируется от кадра к кадру
        // и не может «поделить бар» с гибким полем поиска.
        //
        // `alignment: .leading` — не косметика, а лечение: в зоне лежат все три плеера
        // разом (мини-плеер, чип книги, чип кино), неактивные с нулевой прозрачностью,
        // и `ZStack` берёт размер по самому широкому из них — чип кино 91.5. Когда зона
        // уже его (круг 60), `frame` по умолчанию **центрирует** переросток и уводит
        // содержимое влево на половину разницы, где его срезает `TrailingClipShape`.
        // Так и получался «обрезанный слева кавер» — но только у тех, у кого payload
        // кино или книги вообще есть, поэтому ловилось не всегда (жалоба 2026-08-29).
        .frame(width: layout.trailingWidth, alignment: .leading)
        .frame(height: PlusMetrics.actionBarHeight)
        #if DEBUG
        // `-debugBarProbe 1` — надпись поверх правой зоны: заказанная ширина, реальная
        // отрисованная и режим. Отвечает на вопрос, разъехались ли состояние и геометрия:
        // на скриншоте сломанного плеера это видно сразу, а гадать по картинке нельзя.
        // Замер здесь ни на что не влияет — он в overlay и в раскладку не возвращается.
        .overlay(alignment: .topLeading) {
            if UserDefaults.standard.bool(forKey: "debugBarProbe") {
                GeometryReader { proxy in
                    Text("\(actionBar.mode.rawValue) w\(Int(layout.trailingWidth.rounded()))→\(Int(proxy.size.width.rounded()))\(layout.isRaised ? " up" : "")")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .fixedSize()
                        .offset(y: -12)
                }
            }
        }
        #endif
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
/// перерисовки и вешает рендер. Плюс покадровый lerp
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

/// Не `private`: тот же мини-плеер в компактном варианте живёт в читалке
/// (`BookReaderView`) — круг, который разворачивается в пилюлю.
struct MiniPlayerPill: View {
    let item: MusicNowPlaying
    let trackInfoOpacity: Double
    let progressOpacity: Double
    let progress: Double
    let isPlaying: Bool
    let isLiked: Bool
    let onTogglePlay: () -> Void
    let onToggleLike: () -> Void
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
            // Пол по ширине — круг 60. Пилюля режет свой контент капсулой, и если
            // родитель предложит меньше круга, капсула срежет обложку: пользователь
            // видел «полуовальный обрезанный кавер» после перехода из поисковой
            // выдачи (жалоба 2026-08-29). Предложить меньше родитель может дважды:
            // в фокусе поиска зона схлопывается в 0 (плеер уезжает за кромку), и
            // на любой ширине, где анимация зоны застряла между 0 и 60. Пол делает
            // обрезку невозможной в обоих случаях: в фокусе круг просто уезжает
            // целым, а левый вылет за зону срезает `TrailingClipShape`.
            .frame(minWidth: PlusMetrics.actionBarCompact, maxWidth: .infinity)
            .frame(height: PlusMetrics.actionBarHeight)
            .glassPill()
            .overlay(alignment: .leading) {
                MiniPlayerProgressFill(progress: progress, opacity: progressOpacity)
                    // Заливка гаснет и приходит вместе с остальными внутренностями:
                    // на сужении она иначе доживает до круга полосой в полкруга.
                    .animation(ActionBarMotion.miniContentFade, value: progressOpacity)
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
                    .animation(ActionBarMotion.miniContentFade, value: trackInfoOpacity)
            }
            actions
                .opacity(trackInfoOpacity)
                .animation(ActionBarMotion.miniContentFade, value: trackInfoOpacity)
        }
        .padding(.leading, ActionBarGeometry.miniPlayerPaddingLeading)
        .padding(.trailing, ActionBarGeometry.miniPlayerPaddingTrailing)
        // Раскладка по раскрытой ширине, а не по текущей — см. `miniPlayerExpandedWidth`.
        // Сжатую пилюлю лишнее просто не видит: его срезает капсула.
        .frame(width: ActionBarGeometry.miniPlayerExpandedWidth, alignment: .leading)
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
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .lineLimit(1)
            Text(item.artist)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillSubtitle)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        HStack(spacing: ActionBarGeometry.miniPlayerActionsGap) {
            likeButton
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

    /// Лайк прямо из мини-плеера (просьба пользователя 2026-10-03). Нравится — залитое
    /// белое сердце, как в полноэкранном плеере (правка того же дня: раньше лайк здесь
    /// был акцентным контуром); смена — тем же кросс-попом, что у play/pause.
    private var likeButton: some View {
        Button {
            PlayerHaptics.tap()
            onToggleLike()
        } label: {
            // Общий рисунок лайка (`LikeGlyph`) — эталон для всех сердец проекта.
            LikeGlyph(isLiked: isLiked, box: ActionBarGeometry.searchIconBox)
            // Хит-зона крупнее глифа, раскладка — нет: тот же приём, что у play.
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .contentShape(.rect)
            .padding(.horizontal, -8)
            .padding(.vertical, -10)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(isLiked ? "Убрать из любимых" : "Нравится")
    }

    private func actionIcon(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: ActionBarGeometry.searchIconBox, height: ActionBarGeometry.searchIconBox)
            .foregroundStyle(Color.fillOne)
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

/// Нажимаемый чип: пресс-стейт стеклянных кнопок и хаптика «включить контент» —
/// та же, что у «Смотреть» и «Читать» на экранах сущностей.
private struct ChipButton<Label: View>: View {
    let title: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            action()
        } label: {
            label()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }
}

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
        .secondaryButtonSurface(
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
        .secondaryButtonSurface(
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

    /// Ширина правой зоны на самом слое. Даёт `ZStack`'у одинаковый размер всех
    /// детей: без неё стек берёт максимум по ним, и активный слой растягивается
    /// по неактивному соседу (см. комментарий в `TrailingSlot`).
    func zoneWidth(_ layout: ActionBarLayout) -> some View {
        frame(width: layout.trailingWidth, alignment: .leading)
    }
}


