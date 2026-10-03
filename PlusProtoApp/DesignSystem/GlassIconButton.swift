import SwiftUI

/// Геометрия и отклик кнопки. Компонент Figma `11:9189` (Size=md 40px, Type=primary, Icon=only).
enum GlassIconButtonConfig {
    /// Диаметр круга
    static let size = PlusMetrics.circleButton
    /// Бокс глифа: padding 10 внутри круга 40. Ассет рисуется ровно в этот бокс —
    /// собственные поля глифа уже внутри холста, см. DECISIONS про единый холст 16×16.
    static let iconBox: CGFloat = 20
    /// Насколько кнопка проседает под пальцем — как в MusicPlayer (BottomBarV2)
    static let pressedScale: CGFloat = 0.92
    static let pressDuration: Double = 0.15
}

/// Размер круглой кнопки — ось `Size` компонента ДС.
enum GlassIconButtonSize {
    /// `11:9189` Size=md 40px: круг 40, глиф 20, стекло кнопок (блюр 20, бордер white 6 %).
    case md
    /// `2088:13431` Size=sm 32px: круг 32, глиф 16, блюр 16 и без бордера — так
    /// компонент нарисован в навбаре экрана книги (`2427:26464`).
    case sm

    var diameter: CGFloat {
        switch self {
        case .md: GlassIconButtonConfig.size
        case .sm: 32
        }
    }

    var iconBox: CGFloat {
        switch self {
        case .md: GlassIconButtonConfig.iconBox
        case .sm: 16
        }
    }
}

/// Круглая стеклянная кнопка: 40×40 с глифом 20 (`md`) или 32×32 с глифом 16 (`sm`).
/// По решению из DECISIONS логики по тапу пока нет — колбэк опционален.
struct GlassIconButton: View {
    let icon: String
    var size: GlassIconButtonSize = .md
    var accessibilityTitle: String = ""
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: size.iconBox, height: size.iconBox)
                .foregroundStyle(Color.fillOne)
                .frame(width: size.diameter, height: size.diameter)
                .modifier(GlassIconButtonSurface(size: size))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(accessibilityTitle)
    }
}

private struct GlassIconButtonSurface: ViewModifier {
    let size: GlassIconButtonSize

    func body(content: Content) -> some View {
        switch size {
        case .md:
            content.glassCircle()
        case .sm:
            content.glassSurface(Circle(), blur: 16, border: .clear)
        }
    }
}

/// Пара ♥/✕ под карточкой — figma-screen1 §2: HStack с зазором 6, лайк слева.
struct LikeDismissPair: View {
    var onLike: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(spacing: PlusMetrics.circleButtonGap) {
            GlassIconButton(icon: "iconLove", accessibilityTitle: "Нравится", action: onLike)
            GlassIconButton(icon: "iconCross", accessibilityTitle: "Скрыть", action: onDismiss)
        }
    }
}

/// Общий пресс-стейт для стеклянных кнопок: `ButtonStyle` сам снимает нажатие при скролле,
/// в отличие от `DragGesture(minimumDistance: 0)`.
struct PressScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = GlassIconButtonConfig.pressedScale

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.smooth(duration: GlassIconButtonConfig.pressDuration), value: configuration.isPressed)
    }
}
