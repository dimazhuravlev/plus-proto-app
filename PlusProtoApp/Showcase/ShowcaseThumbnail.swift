import SwiftUI

/// Куда ведёт тап по миниатюре карточки и в каком namespace живёт зум-переход.
///
/// Едет через environment, а не параметром карточки: миниатюра лежит в глубине вёрстки
/// блока (у «продолжить читать» это стеклянный блок внутри ZStack), и маршрут пришлось бы
/// протаскивать через каждый слой. Лента ставит контекст на карточку целиком, а карточка
/// сама решает, какая её часть — миниатюра.
struct ShowcaseThumbnailContext {
    /// `nil` — переходить некуда: у «Моей Волны» нет своей сущности, это генератор потока.
    var route: EntityRoute?
    var zoom: Namespace.ID
    /// Имя миниатюры для VoiceOver. Без него кнопкой читается имя ассета обложки,
    /// да ещё дважды — у `AmbilightArtwork` картинка лежит в кадре и в ореоле.
    var title: String
    /// Хаптика и перевод action bar в режим сущности — общее для тапа по любой карточке.
    var onTap: () -> Void
    /// Открыть маршрут, который показывается слоем поверх хрома. Для пуша не нужен:
    /// его делает сам `NavigationLink`.
    var present: (EntityRoute) -> Void
}

extension EnvironmentValues {
    @Entry var showcaseThumbnail: ShowcaseThumbnailContext?
}

extension View {
    /// Помечает вью **интерактивной миниатюрой** карточки: только она подсаживается под
    /// пальцем и только она разворачивается в экран сущности. Обвязка вокруг — подписи,
    /// ♥/✕, прогресс, блок оценки — остаётся снаружи, в переходе не участвует и живёт
    /// своей жизнью (кнопки наконец нажимаются сами, а не через карточку).
    func showcaseThumbnail() -> some View {
        modifier(ShowcaseThumbnailModifier())
    }

    /// Ставит миниатюру в её место в кадре карточки — отступом, а не `offset`.
    ///
    /// `offset` двигает только отрисовку: layout-кадр остаётся в нуле, а зум-переход
    /// и его клип-форма читают именно layout-кадр. С `offset` обложка обрезалась по
    /// правому краю кадра карточки, а разворот пошёл бы из её левого верхнего угла.
    /// Ставится **снаружи** `showcaseThumbnail()`, иначе просадка под пальцем считалась бы
    /// вокруг центра отступа, а не вокруг центра обложки.
    func showcasePlaced(at origin: CGPoint) -> some View {
        padding(EdgeInsets(top: origin.y, leading: origin.x, bottom: 0, trailing: 0))
    }
}

private struct ShowcaseThumbnailModifier: ViewModifier {
    @Environment(\.showcaseThumbnail) private var context

    func body(content: Content) -> some View {
        if let context, let route = context.route, route.coversChrome {
            // Кнопка, а не `NavigationLink`: карточка тайтла показывается слоем поверх
            // хрома, а не пушем внутрь стека. Источник зума тот же — сам маршрут.
            Button {
                context.onTap()
                context.present(route)
            } label: {
                content
            }
            .buttonStyle(ShowcaseThumbnailButtonStyle())
            .matchedTransitionSource(id: route, in: context.zoom)
            .accessibilityLabel(context.title)
        } else if let context, let route = context.route {
            NavigationLink(value: route) { content }
                .buttonStyle(ShowcaseThumbnailButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { context.onTap() })
                // Источник зума — ровно эта миниатюра, тот же `EntityRoute`, что лежит
                // в пути навигации: стороны перехода адресуются одним значением
                // и разъехаться не могут.
                //
                // Без `configuration { $0.clipShape(...) }`: клип-форма из конфигурации
                // режет **живую** миниатюру, а не только кадр перехода — у обложек
                // с ней пропадал ореол (замер 2026-08-23: свечение слева от постера
                // 16.9 → 7.4 по яркости). Скругление старта система берёт сама.
                .matchedTransitionSource(id: route, in: context.zoom)
                .accessibilityLabel(context.title)
        } else if let context {
            // Карточка без своей сущности: миниатюра всё равно нажимается, но только
            // включает плеер — переходить некуда.
            Button { context.onTap() } label: { content }
                .buttonStyle(ShowcaseThumbnailButtonStyle())
                .accessibilityLabel(context.title)
        } else {
            content
        }
    }
}

/// Нажатие на миниатюру. Отдельный стиль, а не `PressScaleButtonStyle` хрома: у обложки
/// площадь на порядок больше кнопки, и просадка 0.92 читалась бы прыжком. `.plain` внутри
/// не нужен — стиль сам не красит содержимое в акцентный цвет и не подсвечивает подложкой.
struct ShowcaseThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? ShowcaseMotion.pressedScale : 1)
            .animation(.smooth(duration: ShowcaseMotion.pressDuration), value: configuration.isPressed)
    }
}
