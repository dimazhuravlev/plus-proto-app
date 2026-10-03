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

/// Круглая стеклянная кнопка 40×40: ассет заполняет бокс 20×20.
/// По решению из DECISIONS логики по тапу пока нет — колбэк опционален.
struct GlassIconButton: View {
    let icon: String
    var accessibilityTitle: String = ""
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: GlassIconButtonConfig.iconBox, height: GlassIconButtonConfig.iconBox)
                .foregroundStyle(Color.fillOne)
                .frame(width: GlassIconButtonConfig.size, height: GlassIconButtonConfig.size)
                .glassCircle()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(accessibilityTitle)
    }
}

// Пара под карточками витрины — `ShowcaseFeedbackPair` (✕/✓, с логикой).

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
