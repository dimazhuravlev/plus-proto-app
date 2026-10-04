import SwiftUI

/// Сердце «нравится» — одно поведение везде, как в мини-плеере (правка пользователя
/// 2026-10-04): контур ↔ залитое сменяются кросс-попом — прозрачность и масштаб 0.4
/// той же пружиной, что play/pause бара (`ActionBarMotion.iconSwap`). Цвета у мест
/// свои (в строках выдачи контур приглушён), движение — общее.
struct LikeGlyph: View {
    let isLiked: Bool
    let box: CGFloat
    var offColor: Color = .fillOne
    var onColor: Color = .fillOne

    var body: some View {
        ZStack {
            glyph("iconLove")
                .foregroundStyle(offColor)
                .opacity(isLiked ? 0 : 1)
                .scaleEffect(isLiked ? ActionBarMotion.iconSwapScale : 1)
            glyph("iconLiked")
                .foregroundStyle(onColor)
                .opacity(isLiked ? 1 : 0)
                .scaleEffect(isLiked ? 1 : ActionBarMotion.iconSwapScale)
        }
        .animation(ActionBarMotion.iconSwap, value: isLiked)
    }

    private func glyph(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: box, height: box)
    }
}

/// Круглая стеклянная «нравится» 40 — ряд действий экранов альбома, книги и персоны.
/// Избранного в прототипе нет: состояние — на время экрана, как сердца строк выдачи.
/// Хаптик — как у лайка мини-плеера.
struct LikeGlassButton: View {
    @State private var isLiked = false

    var body: some View {
        Button {
            PlayerHaptics.tap()
            isLiked.toggle()
        } label: {
            LikeGlyph(isLiked: isLiked, box: GlassIconButtonConfig.iconBox)
                .frame(width: GlassIconButtonConfig.size, height: GlassIconButtonConfig.size)
                .glassCircle()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(isLiked ? "Убрать из любимых" : "Нравится")
    }
}
