import SwiftUI
import UIKit

/// Числа промоблока — макет `2269:16942` (кадр 375 перенесён на холст 402: поля
/// те же, ширины тянутся, высота — от пропорций макета).
enum CinemaPromoLayout {
    /// Блок — 3:4 от ширины экрана (`height fixer 3:4`)
    static let height: CGFloat = PlusMetrics.designWidth * 4 / 3
    /// Обложка отступает от краёв на 8 и занимает верхние 83.2 % блока (416 из 500)
    static let coverInset: CGFloat = 8
    static let coverHeight: CGFloat = height * 416 / 500
    static let coverRadius: CGFloat = 24
    /// Мета прижата к низу блока: поля 24, зазоры 8
    static let metaSide: CGFloat = 24
    static let metaBottom: CGFloat = 24
    static let metaGap: CGFloat = 8
    /// Логотип вписывается в бокс, под боксом ещё 8. В макете бокс 280×72 —
    /// уменьшен на ~15 % (правка пользователя 2026-10-04: «немного уменьшить»).
    static let logoBox = CGSize(width: 240, height: 62)
    static let logoBottom: CGFloat = 8
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
    /// фон экрана без кромки, а мета читается поверх неё.
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

/// Промоблок — крупные слайды, листаются по одному в обе стороны **по кругу**
/// (задача пользователя 2026-10-04). Круг — лента из многих повторов набора,
/// открытая на середине: до края её не долистать, а подмены позиции, которая
/// дёргала бы картинку, нет вовсе.
struct CinemaPromoCarousel: View {
    let promos: [CinemaCatalog.Promo]

    /// Повторов набора в ленте. В каждую сторону — сотня кругов.
    private static let laps = 200

    /// Видимый слайд — индекс в ленте повторов. Стартовый задан сразу, в `init`:
    /// лента открывается на середине с первого кадра, без прыжка от нулевого слайда.
    @State private var page: Int?

    init(promos: [CinemaCatalog.Promo]) {
        self.promos = promos
        _page = State(initialValue: promos.count * (Self.laps / 2))
    }

    var body: some View {
        let count = promos.count
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<(count * Self.laps), id: \.self) { index in
                    CinemaPromoSlide(promo: promos[index % count], isCurrent: index == page)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        // Один слайд — листать некуда.
        .scrollDisabled(count < 2)
        .frame(height: CinemaPromoLayout.height)
        .onChange(of: promos.map(\.id)) {
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

    /// Середина ленты — начало первого слайда.
    private var startPage: Int {
        promos.count * (Self.laps / 2)
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
    @Environment(\.stackZoomNamespace) private var zoom

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
            .overlay { shape.strokeBorder(Color.fillNine, lineWidth: PlusMetrics.hairline) }
            // Затемнение — поверх бордера: снизу обложка уходит в фон целиком.
            .overlay { CinemaPromoLayout.fade }
            .clipShape(shape)
            .frame(height: CinemaPromoLayout.coverHeight)
            .padding(.horizontal, CinemaPromoLayout.coverInset)
    }

    private var meta: some View {
        VStack(spacing: CinemaPromoLayout.metaGap) {
            logo
                .frame(width: CinemaPromoLayout.logoBox.width, height: CinemaPromoLayout.logoBox.height)
                .padding(.bottom, CinemaPromoLayout.logoBottom)

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

            // «Позже» — как на карточке тайтла: списка «Буду смотреть» в прототипе нет,
            // кнопка только откликается.
            Button {} label: {
                MovieIcon(name: "iconBookmark", box: CinemaPromoLayout.buttonIcon)
                    .frame(width: CinemaPromoLayout.buttonHeight, height: CinemaPromoLayout.buttonHeight)
                    .glassSurface(Circle(), blur: PlusMetrics.buttonBlur)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Буду смотреть")
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

/// Скелетон промоблока — обложка той же формы и полосы меты.
struct CinemaPromoSkeleton: View {
    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: CinemaPromoLayout.coverRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: CinemaPromoLayout.coverRadius,
            style: .continuous
        )
        ZStack(alignment: .bottom) {
            PlusSkeleton.fill
                .overlay { CinemaPromoLayout.fade }
                .clipShape(shape)
                .frame(height: CinemaPromoLayout.coverHeight)
                .padding(.horizontal, CinemaPromoLayout.coverInset)
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: CinemaPromoLayout.metaGap) {
                Capsule()
                    .fill(PlusSkeleton.fill)
                    .frame(width: 180, height: 32)
                    .frame(height: CinemaPromoLayout.logoBox.height)
                    .padding(.bottom, CinemaPromoLayout.logoBottom)
                // Описание — полосы по центру, как сам текст.
                VStack(spacing: 8) {
                    ForEach([260, 200] as [CGFloat], id: \.self) { width in
                        Rectangle()
                            .fill(PlusSkeleton.fill)
                            .frame(width: width, height: EntitySectionLayout.skeletonBar)
                    }
                }
                .padding(.vertical, 4)
                Capsule()
                    .fill(PlusSkeleton.fill)
                    .frame(width: 148, height: CinemaPromoLayout.buttonHeight)
                    .padding(.vertical, CinemaPromoLayout.buttonsPadding)
            }
            .padding(.bottom, CinemaPromoLayout.metaBottom)
        }
        .frame(height: CinemaPromoLayout.height)
        .accessibilityHidden(true)
    }
}
