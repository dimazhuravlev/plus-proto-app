import SwiftUI
import VariableBlur

/// Полная выдача одного раздела — Музыка, Кино или Книги (задача пользователя
/// 2026-10-03; макет музыки `2440:27920`, кино и книги — те же, с другими фильтрами).
///
/// Заголовка нет (правка макета пользователем 2026-10-03). У музыки сверху чипсы
/// фильтров и колдунщик (самый подходящий исполнитель), у кино и книг — сразу список.
/// Открывается переходом по заголовку карусели, живёт подэкраном слоя выдачи
/// (`SearchResultsView`), «Назад» в баре сворачивает её к обзору.
struct SearchSectionView: View {
    let kind: SearchState.Section.Kind
    /// Уход в сущность — тот же, что из каруселей: отметка ухода, клавиатура вниз.
    let open: (EntityRoute) -> Void
    let zoom: Namespace.ID?

    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(ActionBarState.self) private var actionBar

    /// Выбранный фильтр — им подсвечен чипс, сразу по нажатию.
    @State private var filter: SearchFilter = .all
    /// Фильтр показанного списка — догоняет выбранный после того, как старый список
    /// погас (`FilterMotion`).
    @State private var shownFilter: SearchFilter = .all
    @State private var listOpacity: Double = 1
    @State private var filterSwap: Task<Void, Never>?
    /// Сколько проскроллено — от него проявляется подложка закреплённых чипсов.
    @State private var scrolled: CGFloat = 0
    /// Сердца — визуальные, на время экрана: избранного в прототипе нет.
    @State private var liked: Set<String> = []
    /// Текст выдачи, на который выбран фильтр: новый текст сбрасывает фильтр на «Всю
    /// музыку», а пропавшая на миг выдача (скелетон) — нет.
    @State private var filterText: String?

    private enum Layout {
        static let side: CGFloat = 16
        /// Список кино и книг — на 8 ниже безопасной зоны: столько же, сколько колдунщик
        /// музыки стоит ниже чипсов (`stack` макета, колдунщик на y = 8).
        static let listTop: CGFloat = 8
        static let chipsVertical: CGFloat = 8
        /// Шаг между чипсами — 6 (правка пользователя 2026-10-03; в макете 8).
        static let chipGap: CGFloat = 6
        /// Подложка закреплённых чипсов проявляется за первые 24pt скролла: в покое
        /// верх экрана не темнеет, а уезжающие под чипсы строки уже размыты.
        static let backdropRamp: CGFloat = 24
        static let barGap: CGFloat = 12
        static let skeletonRows = 7
    }

    /// Переключение фильтров (правки пользователя 2026-10-03): списки сменяются
    /// **последовательно** — старый гаснет за 300 мс, затем новый проявляется за 300 мс
    /// (по 150 было слишком резко — правка пользователя 2026-10-03)
    /// (кроссфейд пробовали — не понравился); лента чипсов доезжает до активного.
    private enum FilterMotion {
        static let fadeOutDuration: Duration = .milliseconds(300)
        static let fadeOut: Animation = .easeInOut(duration: 0.3)
        static let fadeIn: Animation = .easeInOut(duration: 0.3)
        /// Подкрутка ленты к активному чипсу — та же длительность, сильный ease-out:
        /// лента отвечает сразу и мягко встаёт.
        static let centerChip: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
    }

    var body: some View {
        ZStack {
            sectionList
            // Пустая выдача — тот же экран, что у обзора: по центру между верхом
            // и баром поиска.
            if isEmpty {
                SearchEmptyState()
            }
        }
    }

    /// Выдача пришла, а показывать нечего — ни строк под фильтром, ни колдунщика.
    private var isEmpty: Bool {
        guard let full = search.fullResults else { return false }
        let hasWizard = shownFilter == .all && full.wizard != nil
        return !hasWizard && !full.hits.contains { shownFilter.matches($0.kind) }
    }

    private var sectionList: some View {
        ScrollViewReader { proxy in
            sectionScroll
                .onChange(of: shownFilter) {
                    // Список невидим — к началу: новый начинается сверху.
                    proxy.scrollTo(Self.topAnchor, anchor: .top)
                }
        }
    }

    private static let topAnchor = "section-top"

    private var sectionScroll: some View {
        ScrollView {
            Color.clear.frame(height: 0).id(Self.topAnchor)
            // Чипсы музыки закреплены — заголовком секции, который липнет к верху
            // при скролле (правка пользователя 2026-10-03). У кино и книг фильтров нет.
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: kind == .music ? [.sectionHeaders] : []) {
                Section {
                    list
                } header: {
                    if kind == .music {
                        chips
                            .background(alignment: .top) {
                                PinnedChipsBackdrop()
                                    .opacity(NavBarRamp.progress(scrolled, start: 0, length: Layout.backdropRamp))
                            }
                    }
                }
            }
            .padding(.top, kind == .music ? 0 : Layout.listTop)
            // Как у обзора: список уходит под поле и клавиатуру, последняя строка
            // выкручивается из-под них.
            .padding(.bottom, keyboard.overlap + PlusMetrics.actionBarHeight + Layout.barGap)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.never)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            scrolled = offset
        }
        // Клавиатура уходит с первого движения скролла — как в обзоре; у горизонтальных
        // лент (чипсы, альбомы колдунщика) — тоже.
        .modifier(DismissKeyboardOnScroll())
        // Новый запрос — с «Всей музыки»: фильтр прошлого запроса мог оставить пустой
        // список. Только когда пришла выдача **другого** текста: прежде фильтр сбрасывался
        // и на приходе первой выдачи — выбранный над скелетоном чипс тут же гас.
        .onChange(of: search.fullResults?.text, initial: true) { _, text in
            guard let text else { return }
            if let filterText, filterText != text {
                // Новая выдача — сразу на «Всей музыке», без смены по фазам.
                filterSwap?.cancel()
                filter = .all
                shownFilter = .all
                listOpacity = 1
            }
            filterText = text
        }
        .onChange(of: filter) { _, selected in swapList(to: selected) }
        #if DEBUG
        // `-debugSearchFilter <n>` — выбрать n-й фильтр музыки (0 — «Всё»), когда
        // выдача раздела пришла: тапнуть по чипсу из шелла нечем.
        .task(id: search.fullResults?.text) {
            let index = UserDefaults.standard.integer(forKey: "debugSearchFilter")
            let options = SearchFilter.options(for: kind)
            guard index > 0, options.indices.contains(index), search.fullResults != nil else { return }
            try? await Task.sleep(for: .milliseconds(500))
            filter = options[index]
        }
        #endif
    }

    /// Содержимое под показанным фильтром; смена — через прозрачность (`swapList`).
    private var list: some View {
        filteredContent
            .opacity(listOpacity)
    }

    /// Старый список гаснет, в паузе подменяется, новый проявляется. Быстрые нажатия
    /// подряд прерывают незаконченную смену — показан всегда последний выбранный.
    private func swapList(to selected: SearchFilter) {
        filterSwap?.cancel()
        guard selected != shownFilter else {
            withAnimation(FilterMotion.fadeIn) { listOpacity = 1 }
            return
        }
        filterSwap = Task { @MainActor in
            withAnimation(FilterMotion.fadeOut) { listOpacity = 0 }
            try? await Task.sleep(for: FilterMotion.fadeOutDuration)
            guard !Task.isCancelled else { return }
            shownFilter = selected
            withAnimation(FilterMotion.fadeIn) { listOpacity = 1 }
        }
    }

    @ViewBuilder
    private var filteredContent: some View {
        if let full = search.fullResults {
            VStack(alignment: .leading, spacing: 0) {
                    if shownFilter == .all, let wizard = full.wizard {
                        MusicWizardCard(
                            wizard: wizard,
                            isLiked: liked.contains(wizard.artist.id),
                            onLike: { toggleLike(wizard.artist.id) },
                            open: open,
                            zoom: zoom
                        )
                    }
                    let rows = full.hits.filter { shownFilter.matches($0.kind) }
                    // Пусто — экран пустой выдачи поверх (`isEmpty`), список молчит.
                    ForEach(rows) { hit in
                        row(hit, isFirst: hit.id == rows.first?.id)
                    }
            }
        } else {
            ForEach(0..<Layout.skeletonRows, id: \.self) { _ in
                SearchListSkeletonRow(isPoster: kind != .music)
            }
        }
    }

    private var chips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Layout.chipGap) {
                    ForEach(SearchFilter.options(for: kind), id: \.self) { option in
                        SearchFilterChip(title: option.title, isActive: option == filter) {
                            filter = option
                        }
                        .id(option)
                    }
                }
                .padding(.horizontal, Layout.side)
                .padding(.vertical, Layout.chipsVertical)
            }
            .scrollIndicators(.hidden)
            .modifier(DismissKeyboardOnScroll())
            // Выбранный чипс — в центр экрана; у краёв лента упирается в свои поля.
            .onChange(of: filter) { _, active in
                withAnimation(FilterMotion.centerChip) {
                    proxy.scrollTo(active, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ hit: SearchHit, isFirst: Bool) -> some View {
        let content = SearchListRow(
            hit: hit,
            isFirst: isFirst,
            isLiked: liked.contains(hit.id),
            onLike: { toggleLike(hit.id) }
        )
        if hit.kind == .track {
            // Трек из полного списка играет сразу, без перехода в альбом (правка
            // пользователя 2026-10-03). В карусели обзора трек по-прежнему открывает
            // альбом. Мини-плеер в поиске не виден — он встанет в бар на выходе.
            Button { play(hit) } label: { content }
                .buttonStyle(.plain)
                .accessibilityHint("Включить трек")
        } else if let route = hit.route {
            Button { open(route) } label: { content }
                .buttonStyle(.plain)
                .modifier(SearchResultsView.SearchZoomSource(route: route, zoom: zoom))
        } else {
            content
        }
    }

    /// Включить трек в плеере бара: обложка, название, исполнитель и альбом — из строки.
    private func play(_ track: SearchHit) {
        PlayerHaptics.tap()
        let album: String? = if case .album(let ref) = track.route { ref.title } else { nil }
        actionBar.startMusic(MusicNowPlaying(
            id: track.id,
            cover: track.artwork ?? .asset("mockAlbumCover"),
            title: track.title,
            artist: track.subtitle,
            album: album
        ))
    }

    private func toggleLike(_ id: String) {
        if liked.contains(id) { liked.remove(id) } else { liked.insert(id) }
    }
}

/// Подложка закреплённых чипсов — прогрессивный блюр от самого верха экрана (под
/// статус-баром тоже едут строки) до чуть ниже чипсов. Без затемнения: тёмный
/// градиент навбара сущностей здесь убран по правке пользователя 2026-10-03 — как
/// прежде у навбара витрины.
private struct PinnedChipsBackdrop: View {
    /// Насколько подложка уходит выше чипсов — под статус-бар с запасом.
    private static let above: CGFloat = 80
    /// И насколько ниже: блюр сходит на нет уже под чипсами, а не на их кромке.
    private static let below: CGFloat = 24
    private static let chipsRow: CGFloat = 56

    var body: some View {
        VariableBlurView(
            maxBlurRadius: EntityNavBarGeometry.backdropBlurRadius,
            direction: .blurredTopClearBottom
        )
        .frame(height: Self.above + Self.chipsRow + Self.below)
        .offset(y: -Self.above)
        .allowsHitTesting(false)
    }
}

/// Скролл начался — клавиатура уходит мягко, как в обзоре выдачи. Общий для
/// вертикального списка и горизонтальных лент раздела.
private struct DismissKeyboardOnScroll: ViewModifier {
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(ActionBarState.self) private var actionBar

    func body(content: Content) -> some View {
        content.onScrollPhaseChange { _, phase in
            guard phase == .interacting, actionBar.isSearchFocused else { return }
            keyboard.dismissSmoothly()
        }
    }
}

// MARK: - Фильтры

/// Фильтры полной выдачи — только у музыки, ровно по макету: «Вся музыка»,
/// Исполнители, Альбомы, Плейлисты (треки — в «Всей музыке»). У кино и книг фильтров
/// нет — правка пользователя 2026-10-03.
enum SearchFilter: Hashable {
    case all, artists, albums, playlists

    static func options(for kind: SearchState.Section.Kind) -> [SearchFilter] {
        switch kind {
        case .music: [.all, .artists, .albums, .playlists]
        case .movies, .books: []
        }
    }

    var title: String {
        switch self {
        case .all: "Вся музыка"
        case .artists: "Исполнители"
        case .albums: "Альбомы"
        case .playlists: "Плейлисты"
        }
    }

    func matches(_ kind: SearchHit.Kind) -> Bool {
        switch self {
        case .all: true
        case .artists: kind == .artist
        case .albums: kind == .album
        case .playlists: kind == .playlist
        }
    }
}

/// Цвета строк и чипсов по макету — разовые, токенов не заводим.
private enum SearchSectionColors {
    /// Разделитель строк — Fill/Eight.
    static let divider = Color.white.opacity(0.15)
    /// Сердце без лайка — Fill/Five.
    static let like = Color.white.opacity(0.6)
    /// Точка-разделитель в подписи — Fill/Seven.
    static let dot = Color.white.opacity(0.3)
}

/// Чипс фильтра — `chips-row` макета: 15/20 Semibold, поля 16 × 10, капсула.
/// Активный — фиолетовый с подсветкой снизу, остальные — стекло кнопок.
private struct SearchFilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    /// Фиолетовый активного чипса — #A332FF макета. Один вызов — токен не заводим.
    private static let accent = Color(red: 163 / 255, green: 50 / 255, blue: 1)

    var body: some View {
        Button(action: action) {
            Text(title)
                .plusText(.textM, .semibold)
                .foregroundStyle(isActive ? Color.fillOne : Color.fillFour)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    if isActive {
                        ZStack {
                            Capsule().fill(
                                Self.accent.opacity(0.5)
                                    .shadow(.inner(color: Self.accent.opacity(0.5), radius: 1, y: 1))
                            )
                            // Подсветка снизу — эллипс макета: центр под нижней кромкой
                            // (0.505 ширины, 1.15 высоты), радиусы 0.696 ширины и 0.8875 высоты.
                            GeometryReader { proxy in
                                let size = proxy.size
                                let center = UnitPoint(x: 0.505, y: 1.15)
                                RadialGradient(
                                    colors: [Self.accent.opacity(0.4), Self.accent.opacity(0)],
                                    center: center,
                                    startRadius: 0,
                                    endRadius: 0.8875 * size.height
                                )
                                .scaleEffect(
                                    x: (0.696 * size.width) / max(0.8875 * size.height, 1),
                                    y: 1,
                                    anchor: center
                                )
                            }
                        }
                    } else {
                        Color.buttonsSecondary
                    }
                }
                .clipShape(Capsule())
                .overlay {
                    Capsule().strokeBorder(
                        Color.white.opacity(isActive ? 0.3 : 0.15),
                        lineWidth: PlusMetrics.hairline
                    )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Строка

/// Строка полной выдачи — `list-item / music` макета: 64 = 8 + обложка 48 + 8,
/// название и подпись 15/20, сердце справа, разделители 0.5. У фильма, книги,
/// режиссёра и писателя обложка — вертикальный постер 48 × 72, строка 88.
private struct SearchListRow: View {
    let hit: SearchHit
    let isFirst: Bool
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            SearchRowThumbnail(hit: hit)

            VStack(alignment: .leading, spacing: -2) {
                Text(hit.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                subtitleLine
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onLike) {
                Image(isLiked ? "iconLiked" : "iconLove")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isLiked ? Color.fillOne : SearchSectionColors.like)
                    .padding(10)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.trailing, -10)
            .accessibilityLabel(isLiked ? "Убрать из избранного" : "В избранное")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: SearchRowThumbnail.height(hit.kind) + 16)
        .overlay(alignment: .bottom) { divider }
        .overlay(alignment: .top) { if isFirst { divider } }
        .contentShape(.rect)
    }

    private var divider: some View {
        Rectangle()
            .fill(SearchSectionColors.divider)
            .frame(height: 0.5)
            .padding(.horizontal, 16)
    }

    /// Подпись — вид результата и, где есть, исполнитель, год или автор, через точку
    /// 3pt с зазорами 4: «Трек · New Order», как в макете.
    private var subtitleLine: some View {
        HStack(spacing: 4) {
            Text(label)
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillSubtitle)
                .fixedSize()
            if showsDetail {
                Circle()
                    .fill(SearchSectionColors.dot)
                    .frame(width: 3, height: 3)
                Text(hit.subtitle)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .lineLimit(1)
            }
        }
    }

    private var label: String {
        switch hit.kind {
        case .track: "Трек"
        case .album: "Альбом"
        case .artist: "Исполнитель"
        case .playlist: "Плейлист"
        case .movie: "Фильм"
        case .book: "Книга"
        case .director: "Режиссёр"
        case .writer: "Писатель"
        }
    }

    /// Деталь после точки — у трека, альбома, фильма и книги, если она есть.
    private var showsDetail: Bool {
        guard !hit.subtitle.isEmpty else { return false }
        switch hit.kind {
        case .track, .album, .movie, .book: return true
        default: return false
        }
    }
}

/// Обложка строки шириной 48 — как у альбома и плейлиста: квадрат у музыки, круг
/// у исполнителя; у фильма, книги, режиссёра и писателя — вертикальный постер 48 × 72
/// с тем же скруглением 6 (правка пользователя 2026-10-03: «всё то же самое, только
/// постер вертикальный»).
private struct SearchRowThumbnail: View {
    let hit: SearchHit

    static let width: CGFloat = 48
    static func height(_ kind: SearchHit.Kind) -> CGFloat {
        isPoster(kind) ? 72 : 48
    }

    static func isPoster(_ kind: SearchHit.Kind) -> Bool {
        switch kind {
        case .movie, .book, .director, .writer: true
        default: false
        }
    }

    var body: some View {
        let shape = self.shape
        PlusSkeleton.fill
            .frame(width: Self.width, height: Self.height(hit.kind))
            .overlay {
                if let source = hit.artwork {
                    ResolvedArtwork(source: source, appear: PlusSkeleton.appear) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                // У круга исполнителя обводки в макете нет.
                if hit.kind != .artist {
                    shape.stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline)
                }
            }
    }

    private var shape: AnyShape {
        hit.kind == .artist
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Строка-скелетон — того же габарита, пока полная выдача собирается: у кино
/// и книг — с вертикальным постером.
private struct SearchListSkeletonRow: View {
    let isPoster: Bool

    private var thumbHeight: CGFloat { isPoster ? 72 : 48 }

    var body: some View {
        HStack(spacing: 12) {
            // Тот же скелетон, что у карточек каруселей: цвет, хайрлайн, полосы 12.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .plusSkeleton()
                .frame(width: SearchRowThumbnail.width, height: thumbHeight)
            VStack(alignment: .leading, spacing: 8) {
                Rectangle().fill(PlusSkeleton.fill).frame(width: 160, height: 12)
                Rectangle().fill(PlusSkeleton.fill).frame(width: 100, height: 12)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: thumbHeight + 16)
        .accessibilityHidden(true)
    }
}

// MARK: - Колдунщик

/// Колдунщик музыки — `search widget` макета (`2440:29310`): самый подходящий запросу
/// исполнитель. Строка 48: фото кругом, имя и «Исполнитель», сердце и play; ниже —
/// карусель его альбомов (95, обложка со скруглением 12). Фон — размытая фотография
/// исполнителя на 20 % поверх тонкой подложки.
private struct MusicWizardCard: View {
    let wizard: SearchState.MusicWizard
    /// Лайк — общий со строкой того же исполнителя в списке.
    let isLiked: Bool
    let onLike: () -> Void
    let open: (EntityRoute) -> Void
    let zoom: Namespace.ID?

    @Environment(ActionBarState.self) private var actionBar

    private enum Layout {
        static let radius: CGFloat = 16
        static let inner: CGFloat = 12
        static let avatar: CGFloat = 48
        static let albumWidth: CGFloat = 95
        static let albumRadius: CGFloat = 12
        static let albumGap: CGFloat = 8
        static let playSize: CGFloat = 40
    }

    var body: some View {
        VStack(spacing: Layout.inner) {
            topRow
            if !wizard.albums.isEmpty {
                albums
            }
        }
        .padding(.vertical, Layout.inner)
        .background { background }
        .clipShape(RoundedRectangle(cornerRadius: Layout.radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.radius, style: .continuous)
                .strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var topRow: some View {
        HStack(spacing: 0) {
            PlusSkeleton.fill
                .frame(width: Layout.avatar, height: Layout.avatar)
                .overlay { artwork(wizard.artist.artwork) }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: -2) {
                Text(wizard.artist.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                Text("Исполнитель")
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onLike) {
                Image(isLiked ? "iconLiked" : "iconLove")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isLiked ? Color.fillOne : SearchSectionColors.like)
                    .padding(10)
                    .contentShape(.rect)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isLiked ? "Убрать из избранного" : "В избранное")
            .padding(.trailing, 6)

            Button(action: togglePlay) {
                Image(isPlayingThis ? "iconPause" : "iconPlay")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.fillOne)
                    .frame(width: Layout.playSize, height: Layout.playSize)
                    .background(Color.buttonsSecondary, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isPlayingThis ? "Пауза" : "Слушать")
        }
        .frame(height: Layout.avatar)
        .padding(.horizontal, Layout.inner)
    }

    private var albums: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Layout.albumGap) {
                ForEach(wizard.albums) { album in
                    albumCard(album)
                }
            }
            .padding(.horizontal, Layout.inner)
        }
        .scrollIndicators(.hidden)
        .modifier(DismissKeyboardOnScroll())
    }

    @ViewBuilder
    private func albumCard(_ album: SearchHit) -> some View {
        let card = VStack(alignment: .leading, spacing: 6) {
            PlusSkeleton.fill
                .frame(width: Layout.albumWidth, height: Layout.albumWidth)
                .overlay { artwork(album.artwork) }
                .clipShape(RoundedRectangle(cornerRadius: Layout.albumRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.albumRadius, style: .continuous)
                        .stroke(PlusSkeleton.fill, lineWidth: PlusMetrics.hairline)
                }
            Text(album.title)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 8)
        }
        .frame(width: Layout.albumWidth, alignment: .leading)
        .contentShape(.rect)

        if let route = album.route {
            Button { open(route) } label: { card }
                .buttonStyle(PressScaleButtonStyle())
                .modifier(SearchResultsView.SearchZoomSource(route: route, zoom: zoom))
        } else {
            card
        }
    }

    private var background: some View {
        ZStack {
            // Фото раздуто втрое до размытия — в карточку попадает его центр, а тинт
            // не гаснет к краям (в макете слой 1029 × 651 под карточкой 370 × 217).
            artwork(wizard.artist.artwork)
                .scaleEffect(3)
                .blur(radius: 60)
                .opacity(0.2)
            Color.fillNine
        }
    }

    @ViewBuilder
    private func artwork(_ source: ArtworkSource?) -> some View {
        if let source {
            ResolvedArtwork(source: source, appear: PlusSkeleton.appear) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
        }
    }

    // MARK: Play

    /// Этот исполнитель — то, за чем сейчас бар: музыка в его режиме, а не payload,
    /// оставшийся под чипом книги или фильма.
    private var isBarOnThisArtist: Bool {
        (actionBar.mode == .music || actionBar.mode == .search)
            && actionBar.music?.artist == wizard.artist.title
    }

    /// Играет ли сейчас этот исполнитель — play превращается в паузу.
    private var isPlayingThis: Bool {
        actionBar.isMusicPlaying && isBarOnThisArtist
    }

    /// Включить исполнителя: его трек из выдачи, а нет — первый альбом. Уже играет —
    /// пауза. Мини-плеер появится в баре, когда из поиска выйдут.
    private func togglePlay() {
        // Пауза — только если бар за этим исполнителем: в режиме книги или фильма
        // переключение payload запустило бы музыку-«призрака» без мини-плеера.
        if isBarOnThisArtist {
            actionBar.toggleMusicPlayback()
            return
        }
        guard let pick = wizard.topTrack ?? wizard.albums.first else { return }
        let albumTitle: String? = if case .album(let ref) = pick.route { ref.title } else { nil }
        actionBar.startMusic(MusicNowPlaying(
            id: pick.id,
            cover: pick.artwork ?? .asset("mockAlbumCover"),
            title: pick.title,
            artist: wizard.artist.title,
            album: albumTitle,
            artistPicture: wizard.artist.artwork
        ))
    }
}
