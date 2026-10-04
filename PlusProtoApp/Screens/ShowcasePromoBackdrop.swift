import SwiftUI

/// Числа фона промо витрин.
enum ShowcasePromoBackdropStyle {
    /// Размытие 60 — «размыть сильнее» (правка пользователя 2026-10-04, было 40)
    static let blur: CGFloat = 60
    static let dim: Double = 0.35
    /// Весь фон — на 80 %: ещё темнее поверх затемнения (правка пользователя 2026-10-04)
    static let opacity: Double = 0.8
    /// Смена слайда — кроссфейдом фона
    static let fade: Animation = .easeInOut(duration: 0.4)
    /// До этой доли высоты фон в полную силу, ниже — уходит в чёрный экрана
    static let solidShare: CGFloat = 0.55
}

/// Фон промо витрины — размытая копия картинки текущего слайда от физического верха
/// экрана до низа промо, затемнённая и уходящая в чёрный. Общий у витрин Книг
/// (обложка книги) и Кинопоиска (кадр фильма, задача пользователя 2026-10-04): область
/// над промо, под навигацией, не стоит пустой чёрной.
///
/// Ставится фоном промо по нижней кромке: `height` — от верха экрана до низа промо.
/// При оттяге ленты фон растёт вверх ровно на его величину — сверху не открывается
/// чёрное (правка пользователя 2026-10-04 для Книг).
struct ShowcasePromoBackdrop: View {
    let source: ArtworkSource?
    /// Слайд — от него кроссфейд смены
    let id: String?
    let height: CGFloat
    let pull: CGFloat

    var body: some View {
        ZStack {
            if let source, let id {
                SkeletonArtwork(source: source)
                    .frame(width: PlusMetrics.designWidth, height: height)
                    .blur(radius: ShowcasePromoBackdropStyle.blur, opaque: true)
                    .overlay { Color.black.opacity(ShowcasePromoBackdropStyle.dim) }
                    .id(id)
                    .transition(.opacity)
            }
        }
        .frame(width: PlusMetrics.designWidth, height: height)
        .clipped()
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: ShowcasePromoBackdropStyle.solidShare),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .opacity(ShowcasePromoBackdropStyle.opacity)
        .animation(ShowcasePromoBackdropStyle.fade, value: id)
        .scaleEffect((height + pull) / height, anchor: .bottom)
        .allowsHitTesting(false)
    }
}
