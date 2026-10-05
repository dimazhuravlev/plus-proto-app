import SwiftUI

/// Геометрия и отклик кнопки. Компонент Figma `11:9189` (Size=md 40px, Type=primary, Icon=only).
enum GlassIconButtonConfig {
    /// Диаметр круга
    static let size = PlusMetrics.circleButton
    /// Бокс глифа: padding 10 внутри круга 40. Ассет рисуется ровно в этот бокс —
    /// собственные поля глифа уже внутри его единого холста 16×16.
    static let iconBox: CGFloat = 20
    /// Насколько кнопка проседает под пальцем — как в MusicPlayer (BottomBarV2).
    /// Кривые и тайминги нажатия — `PressMotion`.
    static let pressedScale: CGFloat = 0.92
}

/// Круглая стеклянная кнопка 40×40: ассет заполняет бокс 20×20.
/// Колбэк опционален: у части кнопок логики по тапу пока нет.
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
// Пресс-стейт кнопок — `PressScaleButtonStyle` (PressFeedback.swift).
