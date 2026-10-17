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
/// и снизу, шапка с шевроном, лента с полями 16. Общая у главных Кинопоиска и Книг.
/// Полных списков в прототипе нет — заголовок не нажимается, как у секций экранов
/// сущностей.
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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            EntitySectionHeader(title: title, showsChevron: showsChevron, lineHeight: ServiceCarouselLayout.headerLine)

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
