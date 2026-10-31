import SwiftUI

/// Числа карусели витрин сервисов — `carousel / Movies` главной Кинопоиска (`2269:16939`).
enum ServiceCarouselLayout {
    static let side: CGFloat = 16
    static let sectionPad: CGFloat = 8
    /// Строка заголовка — Headline S при 100 % (шапка 52 = 16 + 24 + 12)
    static var headerLine: CGFloat { PlusHeadline.s.lineHeight }
    static let cardGap: CGFloat = 8
}

/// Карусель витрины сервиса — каркас макета (`carousel / Movies`): поля 8 сверху
/// и снизу, шапка с шевроном, лента с полями 16. Общая у главных Кинопоиска, Книг, Музыки
/// и «Главной». Полных списков в прототипе нет — заголовок нажимается, только если ему
/// есть куда вести (`headerAction`: на «Главной» — таб сервиса).
///
/// Вариант «Топ-10» (`isRanked`) — тип `top 10` того же `carousel / Movies`: шапка с молнией,
/// сиреневая, без шеврона; карточки рисуют цифру места сами (`ServiceCarouselRankNumber`).
///
/// **Высота ленты — явная**, из размеров карточки. Своей `LazyHStack` здесь не меряла:
/// все карусели экрана получали одну и ту же высоту (238), будто по оценке, а не по
/// карточкам, — под «Смотреть дальше» (ей нужно ~182) стояла дыра в 56pt, а подписи
/// постеров (нужно 246) срезались снизу (жалобы пользователя 2026-10-04, замер кадром).
struct ServiceCarousel<Content: View>: View {
    let title: String
    /// Высота карточки целиком — вместе с подписью.
    let cardHeight: CGFloat
    /// Шеврон за заголовком — у Музыки он только там, где есть полный список
    /// («Новые релизы», макет `68:15807`).
    var showsChevron = true
    /// Поле под лентой: 8 у Кино и Книг, у каруселей Музыки — 16 и 24 (`pb-[…]` макета).
    var bottomPadding: CGFloat = ServiceCarouselLayout.sectionPad
    /// «Топ-10» — шапка с молнией, без шеврона.
    var isRanked = false
    /// Тап по шапке. `nil` — шапка не кнопка: выключенная кнопка приглушила бы заголовок.
    var headerAction: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: ServiceCarouselLayout.cardGap) {
                    content
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, ServiceCarouselLayout.side, for: .scrollContent)
            .frame(height: cardHeight)
        }
        .padding(.top, ServiceCarouselLayout.sectionPad)
        .padding(.bottom, bottomPadding)
    }

    /// Есть ли куда вести, у карусели не меняется — ветка не переключается.
    @ViewBuilder
    private var header: some View {
        if let headerAction {
            Button(action: headerAction) {
                headerLabel.contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            headerLabel
        }
    }

    @ViewBuilder
    private var headerLabel: some View {
        if isRanked {
            ServiceCarouselRankHeader(title: title)
        } else {
            EntitySectionHeader(title: title, showsChevron: showsChevron, lineHeight: ServiceCarouselLayout.headerLine)
        }
    }
}

// MARK: - Топ-10

/// Числа «Топ-10» — `carousel / Movies`, тип `top 10` (`1028:70262`), и карточка
/// `card / poster / top-10` (`205:26409`) ДС «Платформа / Мобайл»: перед карточкой поле 48
/// под цифру, цифра — бокс 110×160 на 75 левее обложки, центр на 1 выше её центра. Цифра
/// стоит поверх своей обложки и под предыдущей карточкой (`zIndex` по убыванию места).
/// Числа сняты при постере 148 — карусель передаёт свой масштаб (`CarouselFit.scale`).
enum ServiceCarouselRank {
    /// Мест в карусели
    static let limit = TopPicks.limit
    /// Поле под цифру перед карточкой (`pl-[48px]`)
    static let lead: CGFloat = 48
    static let boxLeading: CGFloat = 75
    static let boxHeight: CGFloat = 160
    static let boxRise: CGFloat = 1
    /// Растр цифры (`topRank1…10`) — бокс с запасом под выступы цифр: x −18…134, y 4…156
    static let artOrigin = CGPoint(x: -18, y: 4)
    static let artSize: CGFloat = 152
    /// Молния шапки и зазор до заголовка
    static let iconSize: CGFloat = 16
    static let iconGap: CGFloat = 4
    /// Сиреневый шапки — `#E2BCE8` макета, вне палитры
    static let tint = Color(red: 226 / 255, green: 188 / 255, blue: 232 / 255)

    /// Порядок слоёв: первое место — выше всех.
    static func zIndex(place: Int) -> Double { Double(limit - place) }
}

/// Шапка «Топ-10» — молния и заголовок Headline S сиреневым, поля как у `EntitySectionHeader`.
private struct ServiceCarouselRankHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: ServiceCarouselRank.iconGap) {
            Image("iconTopTen")
                .renderingMode(.template)
                .resizable()
                .frame(width: ServiceCarouselRank.iconSize, height: ServiceCarouselRank.iconSize)
            Text(title)
                .plusHeadline(.s)
                .lineLimit(1)
        }
        .foregroundStyle(ServiceCarouselRank.tint)
        .frame(height: ServiceCarouselLayout.headerLine)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, EntitySectionLayout.headerTop)
        .padding(.bottom, EntitySectionLayout.headerBottom)
        .padding(.horizontal, ServiceCarouselLayout.side)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Цифра места — оверлеем на обложке (`alignment: .topLeading`): раскладку не трогает,
/// выступает влево, в поле `lead` перед карточкой. Источник зума — обложка без цифры:
/// оверлей вешается после `matchedTransitionSource`.
struct ServiceCarouselRankNumber: View {
    let place: Int
    /// Центр обложки по вертикали — в координатах вью под оверлеем.
    let coverCenter: CGFloat
    let scale: CGFloat

    var body: some View {
        let rank = ServiceCarouselRank.self
        let boxTop = coverCenter - (rank.boxRise + rank.boxHeight / 2) * scale
        Image("topRank\(place)")
            .resizable()
            .frame(width: rank.artSize * scale, height: rank.artSize * scale)
            .offset(x: (rank.artOrigin.x - rank.boxLeading) * scale, y: boxTop + rank.artOrigin.y * scale)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Название раздела-фильтра, который в прототипе не спроектирован («Спорт», «Для вас»,
/// «Аудиокниги»), — как у заглушек сервисов.
struct ServiceFilterStub: View {
    let title: String

    var body: some View {
        Text(title)
            .plusHeadline(.l)
            .foregroundStyle(Color.fillSix)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
