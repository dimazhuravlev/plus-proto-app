import SwiftUI
import UIKit

/// Числа промоблока — макет `2269:16942`, обновлённый 2026-10-04: карточки лентой,
/// справа из-под края выглядывает следующая. Кадр 375 перенесён на холст 402:
/// поля и выглядывающий край те же, ширина карточки тянется, высота — от пропорций.
enum CinemaPromoLayout {
    /// Кадр макета — 3:4 от ширины экрана (`height fixer 3:4`): от него считается обложка
    static let frameHeight: CGFloat = PlusMetrics.designWidth * 4 / 3
    /// Под кнопками воздух поджат на 16 (правка пользователя 2026-10-04): блок короче
    /// кадра, мета опущена на те же 16 — кнопки на месте, следующая секция ближе
    static let bottomTrim: CGFloat = 16
    static let height: CGFloat = frameHeight - bottomTrim
    /// Карточка — та же ширина, что с первого прогона: экран без 42, 360 на холсте 402
    /// (замер кадром). Лента ставит её по центру экрана, и соседи выглядывают поровну
    /// с обеих сторон — по 13 за зазором 8 (правка пользователя 2026-10-04: габариты
    /// не менять, только сдвинуть; прежде карточка стояла у поля 8 слева, а выглядывала
    /// только следующая).
    ///
    /// Ширина — сам контейнер: `containerRelativeFrame` меряет ленту уже **без** её
    /// полей. Две первые версии центровки этого не учли и вычитали поля ещё раз —
    /// карточка сужалась до 298 и 334.
    static let cardGap: CGFloat = 8
    /// Поле ленты с каждой стороны — зазор и край соседа
    static let sideInset: CGFloat = 21
    static var cardWidth: CGFloat { PlusMetrics.designWidth - 2 * sideInset }
    /// Обложка занимает верхние 83.2 % блока (416 из 500)
    static let coverHeight: CGFloat = frameHeight * 416 / 500
    static let coverRadius: CGFloat = 24
    /// Фон над промо — в полную силу только верхние 300 от верха экрана, дальше за 160
    /// плавно уходит в чёрный (правка пользователя 2026-10-04)
    static let backdropSolid: CGFloat = 300
    static let backdropFade: CGFloat = 160
    /// Мета прижата к низу блока: поля 24 внутри карточки, зазор 8
    static let metaSide: CGFloat = 24
    static let metaBottom: CGFloat = 24 - bottomTrim
    static let metaGap: CGFloat = 8
    /// Логотип вписывается в бокс 238×61.2, под ним 6.8 — бокс макета, уменьшенный
    /// вслед за правкой пользователя «немного уменьшить» (280×72 × 0.85).
    static let logoBox = CGSize(width: 238, height: 61.2)
    static let logoBottom: CGFloat = 6.8
    static let leadLines = 3
    static let titleLines = 2
    /// Кнопки: ряд с полями 12 сверху и снизу, высота 48, зазор 8
    static let buttonsPadding: CGFloat = 12
    static let buttonHeight: CGFloat = 48
    static let buttonGap: CGFloat = 8
    static let buttonIcon: CGFloat = 24
    static let watchLeading: CGFloat = 20
    static let watchTrailing: CGFloat = 24
    static let watchIconGap: CGFloat = 8

    /// Затемнение обложки к низу — 16 стопов макета (`fade`): обложка уходит в чёрный
    /// фон экрана без нижней кромки, а мета читается поверх неё.
    static let fade = LinearGradient(
        stops: [
            (0, 0), (0.1459, 0.0103), (0.2658, 0.0393), (0.3632, 0.0848),
            (0.4414, 0.1441), (0.5037, 0.2148), (0.5536, 0.2944), (0.5944, 0.3804),
            (0.6296, 0.4703), (0.6624, 0.5616), (0.6963, 0.6519), (0.7346, 0.7385),
            (0.7808, 0.8192), (0.8382, 0.8913), (0.9101, 0.9524), (1, 1),
        ].map { Gradient.Stop(color: Color.black.opacity($0.1), location: $0.0) },
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Промоблок — крупные карточки, листаются по одной в обе стороны **по кругу**
/// (задача пользователя 2026-10-04). Круг — три копии набора: работает средняя, а когда
/// свайп остановился в крайней, лента перескакивает на тот же слайд средней — картинка
/// та же, прыжка не видно.
///
/// Прежде круг был лентой из двухсот повторов, открытой на середине: на устройстве она
/// открывалась пролистанной до конца (жалоба пользователя) — позиция по id ставилась
/// раньше, чем лента знала ширину карточек, и смещение к шестисотому слайду упиралось
/// в край. Текущий слайд живёт в каталоге — позиция сохраняется на всю сессию.
///
/// Текущая карточка — по центру, соседи выглядывают из-под краёв поровну: круг видно
/// с обеих сторон (правка пользователя 2026-10-04; прежде — только следующая справа); мета —
/// логотип, описание, кнопки — проявляется прозрачностью **вслед за сдвигом**
/// карточек, а не по таймеру: у уезжающей гаснет, у приезжающей проступает
/// (правка пользователя тем же днём).
struct CinemaPromoCarousel: View {
    let promos: [CinemaCatalog.Promo]
    /// Оттяг ленты — фон промо растёт вверх вслед за ним.
    let pull: CGFloat
    /// Слайд набора, на котором остановились, — живёт в каталоге, на всю сессию.
    @Binding var savedIndex: Int

    /// Копий набора в ленте: средняя — рабочая, крайние — запас под свайп за край.
    private static let copies = 3

    /// Видимый слайд — индекс в ленте копий. Стартовый задан сразу, в `init`: лента
    /// открывается на сохранённом слайде средней копии, без прыжка от нулевого.
    @State private var page: Int?

    init(promos: [CinemaCatalog.Promo], pull: CGFloat = 0, savedIndex: Binding<Int>) {
        self.promos = promos
        self.pull = pull
        _savedIndex = savedIndex
        let count = max(promos.count, 1)
        _page = State(initialValue: count + savedIndex.wrappedValue % count)
    }

    var body: some View {
        let count = promos.count
        ScrollView(.horizontal) {
            LazyHStack(spacing: CinemaPromoLayout.cardGap) {
                ForEach(0..<(count * Self.copies), id: \.self) { index in
                    CinemaPromoSlide(promo: promos[index % count], isCurrent: index == page)
                        // Во всю видимую ширину ленты — её поля уже вычтены.
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        // По одной карточке за свайп, как бы ни бросили, — «послайдово».
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .contentMargins(.horizontal, CinemaPromoLayout.sideInset, for: .scrollContent)
        // Якорь — левый край: без якоря перескок на среднюю копию прокручивал минимально,
        // «лишь бы была видна», и карточка вставала у края (кадр 2026-10-04). Левый
        // край ложится ровно на поле ленты — а карточка шириной в ленту без полей,
        // значит она по центру. Якорь `.center` промахивался на 3 (замер кадром).
        .scrollPosition(id: $page, anchor: .leading)
        .scrollIndicators(.hidden)
        // Один слайд — листать некуда.
        .scrollDisabled(count < 2)
        .frame(height: CinemaPromoLayout.height)
        // Над промо и под навигацией — размытый кадр текущего слайда, как у промо Книг
        // (задача пользователя 2026-10-04): область над промо не стоит пустой чёрной.
        .background(alignment: .bottom) {
            ShowcasePromoBackdrop(
                source: current?.cover,
                id: current?.id,
                height: ServiceTopNavLayout.topSafeArea + CinemaLayout.contentTop + CinemaPromoLayout.height,
                pull: pull,
                solid: CinemaPromoLayout.backdropSolid,
                fade: CinemaPromoLayout.backdropFade
            )
        }
        .onScrollPhaseChange { _, phase in
            if phase == .idle { settle() }
        }
        .onChange(of: promos.map(\.id)) {
            savedIndex = 0
            page = startPage
        }
        #if DEBUG
        // `-debugPromoStep <back|next|n>` — через 3с пролистать промо: круг иначе
        // не проверить, свайпнуть из шелла нечем. Назад с первого слайда — последний
        // набора: значит, лента открыта на середине, а не у края. Словами, а не «-1»:
        // значение с минусом аргументы запуска читают как следующий ключ.
        .task {
            let value = UserDefaults.standard.string(forKey: "debugPromoStep") ?? ""
            let step = value == "back" ? -1 : (value == "next" ? 1 : Int(value) ?? 0)
            guard step != 0 else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { page = (page ?? startPage) + step }
        }
        #endif
    }

    /// Первый слайд средней копии.
    private var startPage: Int {
        promos.count
    }

    /// Слайд набора на месте — по видимому слайду ленты копий.
    private var current: CinemaCatalog.Promo? {
        let count = promos.count
        guard count > 0 else { return nil }
        let index = ((page ?? startPage) % count + count) % count
        return promos[index]
    }

    /// Свайп остановился: запомнить слайд и, если это крайняя копия, перескочить
    /// на тот же слайд средней — без анимации, картинка та же.
    private func settle() {
        let count = promos.count
        guard count > 0, let current = page else { return }
        let index = ((current % count) + count) % count
        savedIndex = index
        let middle = count + index
        guard current != middle else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { page = middle }
    }
}

/// Слайд: обложка с затемнением, поверх неё логотип и описание, под ними
/// «Смотреть» и «Позже». Тап по слайду открывает карточку тайтла, кнопки — своё.
private struct CinemaPromoSlide: View {
    let promo: CinemaCatalog.Promo
    /// Видимый слайд — источник зума: повторы того же тайтла в ленте источником
    /// быть не должны, иначе у перехода два кандидата.
    let isCurrent: Bool

    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(CollectionStore.self) private var collection
    @Environment(\.stackZoomNamespace) private var zoom

    /// Тайтл в коллекции «Моё» — «Позже» кладёт его в «Любимое». Моковый слайд
    /// (лента без сети) — без записи: id Кинопоиска у него нет.
    private var collectionItem: CollectionItem? {
        guard promo.id.hasPrefix("kp-") else { return nil }
        return .movie(
            EntityRef(id: promo.id, title: promo.title, subtitle: "", artwork: promo.cover),
            poster: promo.poster,
            year: promo.year
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            coverSource
                .frame(maxHeight: .infinity, alignment: .top)

            meta
                .padding(.horizontal, CinemaPromoLayout.metaSide)
                .padding(.bottom, CinemaPromoLayout.metaBottom)
        }
        .frame(height: CinemaPromoLayout.height)
        .contentShape(.rect)
        .onTapGesture { navigation.open(promo.route) }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var coverSource: some View {
        if isCurrent, let zoom {
            cover.matchedTransitionSource(id: promo.route, in: zoom)
        } else {
            cover
        }
    }

    private var cover: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: CinemaPromoLayout.coverRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: CinemaPromoLayout.coverRadius,
            style: .continuous
        )
        return PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: promo.cover) }
            .overlay { PromoCoverEdge.border }
            // Затемнение — поверх рамки: к низу она гаснет вместе с кадром (макет).
            .overlay { CinemaPromoLayout.fade }
            .clipShape(shape)
            .frame(height: CinemaPromoLayout.coverHeight)
    }

    /// Логотип, под ним описание и кнопки — последние два без зазора, кнопки
    /// отступают своими полями (макет). Прозрачность — от положения в ленте:
    /// 1 у карточки на месте, 0 у выглядывающей из-под края.
    private var meta: some View {
        VStack(spacing: CinemaPromoLayout.metaGap) {
            logo
                .frame(width: CinemaPromoLayout.logoBox.width, height: CinemaPromoLayout.logoBox.height)
                .padding(.bottom, CinemaPromoLayout.logoBottom)

            VStack(spacing: 0) {
                Text(promo.lead)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillFour)
                    .multilineTextAlignment(.center)
                    .lineLimit(CinemaPromoLayout.leadLines)
                    .frame(maxWidth: .infinity)

                buttons
                    .padding(.vertical, CinemaPromoLayout.buttonsPadding)
            }
        }
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content.opacity(1 - min(1, abs(phase.value)))
        }
    }

    /// Логотип вписан в бокс и стоит по его центру. Нет логотипа — название тем же
    /// местом, двумя строками максимум.
    @ViewBuilder
    private var logo: some View {
        if let logo = promo.logo {
            CinemaPromoLogo(source: logo, title: promo.title)
        } else {
            Text(promo.title)
                .plusHeadline(.l)
                .foregroundStyle(Color.fillOne)
                .multilineTextAlignment(.center)
                .lineLimit(CinemaPromoLayout.titleLines)
                .minimumScaleFactor(0.7)
        }
    }

    private var buttons: some View {
        HStack(spacing: CinemaPromoLayout.buttonGap) {
            Button(action: watch) {
                HStack(spacing: CinemaPromoLayout.watchIconGap) {
                    MovieIcon(name: "iconPlay", box: CinemaPromoLayout.buttonIcon)
                    Text("Смотреть")
                        .plusText(.textM, .semibold)
                        .foregroundStyle(Color.fillOne)
                        .fixedSize()
                }
                .padding(.leading, CinemaPromoLayout.watchLeading)
                .padding(.trailing, CinemaPromoLayout.watchTrailing)
                .frame(height: CinemaPromoLayout.buttonHeight)
                // Общий акцентный стиль ДС — как «Смотреть» карточки тайтла.
                .accentButtonSurface()
            }
            .buttonStyle(PressScaleButtonStyle())

            // «Позже» — как на карточке тайтла: закладка в «Любимом» коллекции «Моё».
            let isSaved = collectionItem.map { collection.isFavorite($0.id) } ?? false
            Button {
                guard let collectionItem else { return }
                PlayerHaptics.tap()
                collection.toggleFavorite(collectionItem)
            } label: {
                BookmarkGlyph(isSaved: isSaved, box: CinemaPromoLayout.buttonIcon)
                    .frame(width: CinemaPromoLayout.buttonHeight, height: CinemaPromoLayout.buttonHeight)
                    .secondaryButtonSurface(Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isSaved ? "Убрать из «Позже»" : "Буду смотреть")
        }
    }

    /// «Смотреть» открывает киноплеер — и кладёт фильм в «Смотреть дальше»
    /// (история пишется в `ActionBarState.watch`).
    private func watch() {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        actionBar.open(.movie(promo.movie))
    }
}

/// Рамка обложки — по макету карточки промо (`2455:75990`, правка пользователя
/// 2026-10-04): 0.67 × белый 8 % по всему кадру обложки, скругление сверху 24.
/// Лежит под затемнением, как в макете: к низу гаснет вместе с кадром, а под мету
/// и кнопки не заходит. ~~Кромка сверху и по бокам поверх затемнения~~ — прежняя
/// версия правки того же дня, линии по бокам доходили до самого низа.
private enum PromoCoverEdge {
    static let width: CGFloat = 0.67

    static var border: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: CinemaPromoLayout.coverRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: CinemaPromoLayout.coverRadius,
            style: .continuous
        )
        .strokeBorder(Color.fillNine, lineWidth: width)
        .allowsHitTesting(false)
    }
}

/// Логотип промо: вписан в бокс по центру, проявляется, приехав по сети.
/// Тёмный PNG рисуется белым силуэтом — на затемнённой обложке чёрный не читается
/// (`ArtworkLoader.isDarkLogo`).
private struct CinemaPromoLogo: View {
    let source: ArtworkSource
    let title: String

    @State private var image: UIImage?
    @State private var isDark = false

    var body: some View {
        // Распорка, а не пустое тело: у пустой вью `.task` не выполняется.
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .renderingMode(isDark ? .template : .original)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.fillOne)
                        .accessibilityLabel(title)
                }
            }
            .task(id: source) { await load() }
    }

    private func load() async {
        switch source {
        case .asset(let name):
            image = UIImage(named: name)
            isDark = false
        case .remote(let url, _):
            if let hit = ArtworkLoader.shared.cached(url) {
                isDark = ArtworkLoader.shared.isDarkLogo(url, image: hit)
                image = hit
                return
            }
            guard let loaded = await ArtworkLoader.shared.image(for: url) else { return }
            let dark = ArtworkLoader.shared.isDarkLogo(url, image: loaded)
            withAnimation(PlusSkeleton.appear) {
                isDark = dark
                image = loaded
            }
        }
    }
}

/// Скелетон промоблока — та же лента: карточка с полосами меты и край следующей.
/// Ряд — оверлеем на распорке во всю ширину экрана: своей ширины ленте он не
/// предлагает (иначе раздувал бы её, как было со скелетоном подборок).
struct CinemaPromoSkeleton: View {
    private static var cardWidth: CGFloat { CinemaPromoLayout.cardWidth }

    var body: some View {
        // Три карточки по центру — края соседей выглядывают поровну, как у ленты.
        Color.clear
            .frame(height: CinemaPromoLayout.height)
            .overlay(alignment: .top) {
                HStack(alignment: .top, spacing: CinemaPromoLayout.cardGap) {
                    cover
                        .frame(width: Self.cardWidth)
                    card
                    cover
                        .frame(width: Self.cardWidth)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var cover: some View {
        PlusSkeleton.fill
            .overlay { PromoCoverEdge.border }
            .overlay { CinemaPromoLayout.fade }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: CinemaPromoLayout.coverRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: CinemaPromoLayout.coverRadius,
                style: .continuous
            ))
            .frame(height: CinemaPromoLayout.coverHeight)
    }

    private var card: some View {
        ZStack(alignment: .bottom) {
            cover
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: CinemaPromoLayout.metaGap) {
                SkeletonBar(width: 160, height: 32)
                    .frame(height: CinemaPromoLayout.logoBox.height)
                    .padding(.bottom, CinemaPromoLayout.logoBottom)
                // Описание — полосы по центру, как сам текст.
                VStack(spacing: 8) {
                    SkeletonBar(width: 260)
                    SkeletonBar(width: 200)
                }
                .padding(.vertical, 4)
                Capsule()
                    .fill(PlusSkeleton.fill)
                    .frame(width: 148, height: CinemaPromoLayout.buttonHeight)
                    .padding(.vertical, CinemaPromoLayout.buttonsPadding)
            }
            .padding(.bottom, CinemaPromoLayout.metaBottom)
        }
        .frame(width: Self.cardWidth, height: CinemaPromoLayout.height)
    }
}
