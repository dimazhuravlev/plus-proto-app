import SwiftUI
import VariableBlur

/// Полный список коллекции — переход из заголовка любой её карусели.
struct CollectionListRoute: Hashable {
    /// Фильтр, с которым экран открывается, — вид карусели, из которой пришли
    let kind: CollectionItem.Kind
    let shelf: CollectionStore.Shelf
}

/// Числа полных списков — `list-item / music` макета Музыки (`2128:94020`).
enum CollectionListLayout {
    /// Строка 96: обложка 80 и поля 8, между обложкой и текстом 12
    static let cover: CGFloat = 80
    static let coverRadius: CGFloat = 12
    /// Постер фильма и книга — той же ширины, что обложка альбома и плейлиста, а высота —
    /// своя (правка пользователя 2026-10-04): постер 2:3 — 80 × 120, строка выше
    static let posterHeight: CGFloat = cover * 3 / 2

    /// Книга — наша проекция шириной 80 вместе с выступом страниц справа; высота
    /// обложки — от её пропорций, поэтому строки книг разной высоты.
    static func book(aspect: CGFloat?) -> BookFigureGeometry {
        let range = BookFigureGeometry.aspectRange
        let clamped = min(max(aspect ?? BookFigureGeometry.defaultAspect, range.lowerBound), range.upperBound)
        // Кадр книги — обложка и выступ страниц: 2 на каждые 128 высоты.
        return BookFigureGeometry(coverHeight: cover / (clamped + 2 / BookFigureGeometry.referenceHeight))
    }
    static let side: CGFloat = 16
    static let rowPadding: CGFloat = 8
    static let textGap: CGFloat = 12
    static let controlsGap: CGFloat = 8
    static let titleLines = 2
    /// Список — на 8 ниже ряда чипсов (`stack` макета)
    static let listTop: CGFloat = 8
    /// Подложка шапки сходит на нет на 24 ниже чипсов
    static let backdropTail: CGFloat = 24
    static let backdropRamp: CGFloat = 24
}

/// Полные списки коллекции «Моё» — по макету полных списков Музыки (`2128:94020`,
/// задача пользователя 2026-10-04), с нашим навбаром: «назад» и название полки. Под ним —
/// ряд чипсов, как у полной выдачи музыки в поиске: все виды полки по порядку каруселей
/// коллекции. Открывается из заголовка любой карусели сразу на её виде. В «Скачанном»
/// исполнителей нет — у них нечего скачивать.
///
/// Строки — `list-item / music`: обложка 80, название в две строки и деталь, справа
/// отметка «скачано» и «ещё» с действиями записи; тап открывает сущность, трек
/// и плейлист — играют. Смена фильтра — как в выдаче: старый список гаснет, новый
/// проявляется.
struct CollectionListScreen: View {
    let route: CollectionListRoute

    @Environment(CollectionStore.self) private var collection

    /// Выбранный фильтр — им подсвечен чипс, сразу по нажатию.
    @State private var kind: CollectionItem.Kind
    /// Фильтр показанного списка — догоняет выбранный, когда старый список погас.
    @State private var shownKind: CollectionItem.Kind
    @State private var listOpacity: Double = 1
    @State private var swap: Task<Void, Never>?
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// Чипсы — на время экрана: виды, в которых что-то было при входе. Снятая отметка
    /// не выдёргивает чипс из-под пальца — список просто пустеет.
    private let options: [CollectionItem.Kind]

    init(route: CollectionListRoute) {
        self.route = route
        _kind = State(initialValue: route.kind)
        _shownKind = State(initialValue: route.kind)
        let store = CollectionStore.shared
        options = Self.kinds(on: route.shelf).filter { kind in
            kind == route.kind || !store.items(kind, on: route.shelf).isEmpty
        }
    }

    /// Виды полки — порядок каруселей коллекции; исполнителей в «Скачанном» нет.
    static func kinds(on shelf: CollectionStore.Shelf) -> [CollectionItem.Kind] {
        CollectionItem.Kind.allCases.filter { shelf == .favorites || $0 != .artist }
    }

    private var items: [CollectionItem] {
        collection.items(shownKind, on: route.shelf)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                // Чипсы — закреплённым заголовком внутри ленты, как у полной выдачи
                // музыки и сетки поиска, а не в оверлее экрана: там UIKit раздувал скролл
                // ряда до кромок соседей, и его прозрачный низ забирал касания первой
                // строки (жалоба пользователя 2026-10-06, замер `-debugHitSweep`).
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        LazyVStack(spacing: 0) {
                            ForEach(items) { item in
                                CollectionListRow(item: item, isFirst: item.id == items.first?.id)
                            }
                        }
                        .padding(.top, CollectionListLayout.listTop)
                        // Строки съезжают плавно, только когда отметку сняли в этом же списке.
                        .animation(CollectionMotion.itemsChange, value: items.map(\.id))
                        // Список другого фильтра — новый целиком, а не те же строки с другим
                        // содержимым: иначе на смене фильтра строки переезжали и морфились
                        // под проявлением (правка пользователя 2026-10-04 — «не нужно это»).
                        // Смена — одной прозрачностью: старый гаснет, новый проявляется.
                        .id(shownKind)
                        .opacity(listOpacity)
                    } header: {
                        chips
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.top, EntityNavBarGeometry.barHeight, for: .scrollContent)
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)

            // Пустой список гаснет и проявляется вместе со строками — той же прозрачностью.
            if items.isEmpty {
                Text("Здесь пока ничего нет")
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .opacity(listOpacity)
            }
        }
        .overlay(alignment: .top) {
            EntityNavBar(title: route.shelf.title, scrollOffset: scrollOffset, thresholds: Self.navThresholds)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: kind) { _, selected in swapList(to: selected) }
    }

    /// Чипсы под навбаром. Подложка одна на навбар и чипсы: прогрессивный блюр без
    /// затемнения от верха экрана до чуть ниже чипсов, проявляется по скроллу. Висит
    /// фоном закреплённого ряда и уходит от него вверх, под навбар. При оттяге ряд
    /// едет за лентой вчетверо медленнее — как навигация витрин; заголовок секции на
    /// оттяге едет вместе с лентой, сдвиг возвращает разницу.
    private var chips: some View {
        FilterChipsRow(options: options, selection: $kind, title: \.title)
            .background(alignment: .top) { headerBackdrop }
            .offset(y: ServiceTopNavMotion.pullShift(for: scrollOffset) - max(0, -scrollOffset))
    }

    private var headerBackdrop: some View {
        let above = ServiceTopNavLayout.topSafeArea + EntityNavBarGeometry.barHeight
        return VariableBlurView(
            maxBlurRadius: EntityNavBarGeometry.backdropBlurRadius,
            direction: .blurredTopClearBottom
        )
        .frame(height: above + FilterChipsLayout.rowHeight + CollectionListLayout.backdropTail)
        .offset(y: -above)
        .opacity(NavBarRamp.progress(scrollOffset, start: 0, length: CollectionListLayout.backdropRamp))
        .allowsHitTesting(false)
    }

    /// Название полки в баре — всегда, и при оттяге тоже: это свой тип навбара, а не
    /// название сущности, проявляющееся по скроллу (правка пользователя 2026-10-04).
    /// Нулевая рампа от нуля гасила его на отрицательном сдвиге — старт на минус
    /// бесконечности держит его всегда. Своей подложки у бара нет — она общая с чипсами.
    private static let navThresholds = EntityNavBarThresholds(
        backgroundStart: .greatestFiniteMagnitude,
        backgroundRamp: 1,
        titleStart: -.greatestFiniteMagnitude,
        titleRamp: 0
    )

    /// Старый список гаснет, в паузе подменяется и уезжает к началу, новый проявляется —
    /// как смена фильтров полной выдачи. Быстрые нажатия подряд прерывают незаконченную
    /// смену: показан всегда последний выбранный.
    private func swapList(to selected: CollectionItem.Kind) {
        swap?.cancel()
        guard selected != shownKind else {
            withAnimation(CollectionListMotion.fadeIn) { listOpacity = 1 }
            return
        }
        swap = Task { @MainActor in
            withAnimation(CollectionListMotion.fadeOut) { listOpacity = 0 }
            try? await Task.sleep(for: CollectionListMotion.fadeOutDuration)
            guard !Task.isCancelled else { return }
            shownKind = selected
            scrollPosition.scrollTo(edge: .top)
            withAnimation(CollectionListMotion.fadeIn) { listOpacity = 1 }
        }
    }
}

/// Смена списков по фильтру — те же 300 + 300 мс, что у полной выдачи поиска.
enum CollectionListMotion {
    static let fadeOutDuration: Duration = .milliseconds(300)
    static let fadeOut: Animation = .easeInOut(duration: 0.3)
    static let fadeIn: Animation = .easeInOut(duration: 0.3)
}

// MARK: - Строка

/// Строка полного списка — `list-item / music`: обложка 80 (квадрат r12, у исполнителя
/// круг, у фильма постер 2:3, у книги наша проекция), название Text M в две строки
/// с бейджем 18+, деталь серым; справа отметка «скачано» и «ещё». Разделители 0.5.
private struct CollectionListRow: View {
    let item: CollectionItem
    let isFirst: Bool

    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        HStack(spacing: CollectionListLayout.textGap) {
            thumbnail

            VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(CollectionListLayout.titleLines)
                    if item.isExplicit == true {
                        EntityExplicitBadge()
                    }
                }
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: CollectionListLayout.controlsGap) {
                if collection.isDownloaded(item.id) {
                    Image("iconDownload")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: CollectionLayout.downloadIcon, height: CollectionLayout.downloadIcon)
                        .foregroundStyle(Color.moviesAccent)
                        .accessibilityLabel("Скачано")
                }
                Menu {
                    CollectionItemMenu(item: item)
                } label: {
                    Image("iconMore")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: CollectionLayout.moreIcon, height: CollectionLayout.moreIcon)
                        .foregroundStyle(CollectionLayout.more)
                        .padding(10)
                        .contentShape(.rect)
                        // Своё нажатие у «ещё» — и палец на нём не просаживает строку.
                        .pressScale(GlassIconButtonConfig.pressedScale)
                }
                .padding(-10)
                .accessibilityLabel("Ещё")
            }
        }
        .padding(.horizontal, CollectionListLayout.side)
        .padding(.vertical, CollectionListLayout.rowPadding)
        .frame(minHeight: CollectionListLayout.cover + 2 * CollectionListLayout.rowPadding)
        .contentShape(.rect)
        // Проседает строка, а черты стоят: просевшая черта короче соседних и съезжает.
        .pressScale(PressMotion.rowScale)
        .overlay(alignment: .bottom) { divider }
        .overlay(alignment: .top) { if isFirst { divider } }
        .onTapGesture(perform: open)
        .contextMenu { CollectionItemMenu(item: item) }
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.kind {
        case .movie:
            source(CollectionArtwork(
                source: item.artwork,
                width: CollectionListLayout.cover,
                height: CollectionListLayout.posterHeight,
                shape: RoundedRectangle(cornerRadius: CollectionListLayout.coverRadius, style: .continuous)
            ))
        case .book:
            source(bookFigure)
        case .artist:
            source(CollectionArtwork(
                source: item.artwork,
                width: CollectionListLayout.cover,
                height: CollectionListLayout.cover,
                shape: Circle()
            ))
        case .track, .album, .playlist:
            source(CollectionArtwork(
                source: item.artwork,
                width: CollectionListLayout.cover,
                height: CollectionListLayout.cover,
                shape: RoundedRectangle(cornerRadius: CollectionListLayout.coverRadius, style: .continuous)
            ))
        }
    }

    private var bookFigure: some View {
        let geometry = CollectionListLayout.book(aspect: item.aspect)
        return BookFigure(geometry: geometry, coverWidth: geometry.coverWidth(aspect: item.aspect)) {
            if let artwork = item.artwork {
                SkeletonArtwork(source: artwork)
            }
        }
    }

    /// Обложка — источник зума в экран сущности, как карточки коллекции.
    @ViewBuilder
    private func source(_ view: some View) -> some View {
        if let route = item.route, item.kind != .track, let zoom {
            view.matchedTransitionSource(id: route, in: zoom)
        } else {
            view
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(CollectionLayout.divider)
            .frame(height: 0.5)
            .padding(.horizontal, CollectionListLayout.side)
    }

    /// Трек и плейлист играют сразу, остальные открывают свой экран.
    private func open() {
        if item.kind != .track, let route = item.route {
            navigation.open(route)
        } else if let playable = item.playable {
            PlayerHaptics.tap()
            actionBar.open(.music(playable))
        }
    }
}
