import SwiftUI

/// Числа карусели витрин сервисов — `carousel / Movies` главной Кинопоиска (`2269:16939`).
enum ServiceCarouselLayout {
    static let side: CGFloat = 16
    static let sectionPad: CGFloat = 8
    /// Строка заголовка — Headline M при 100 % (шапка 52 = 16 + 24 + 12)
    static let headerLine: CGFloat = 24
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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            EntitySectionHeader(title: title, lineHeight: ServiceCarouselLayout.headerLine)

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
        .padding(.vertical, ServiceCarouselLayout.sectionPad)
    }
}

/// Название раздела-фильтра, который в прототипе не спроектирован («Спорт», «Для вас»,
/// «Аудиокниги»), — как у заглушек сервисов.
struct ServiceFilterStub: View {
    let title: String

    var body: some View {
        Text(title)
            .plusHeadline(.xl)
            .foregroundStyle(Color.fillSix)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
