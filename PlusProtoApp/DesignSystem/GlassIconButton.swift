import SwiftUI
import UIKit

/// Геометрия и отклик кнопки. Компонент Figma `11:9189` (Size=md 40px, Type=primary, Icon=only).
enum GlassIconButtonConfig {
    /// Диаметр круга
    static let size = PlusMetrics.circleButton
    /// Бокс глифа: padding 10 внутри круга 40. Держит хит-зону и раскладку,
    /// но глиф его не заполняет — в макете сердце 16.67×14.82, крестик 13.08², поиск 20.51².
    static let iconBox: CGFloat = 20
    /// Насколько кнопка проседает под пальцем — как в MusicPlayer (BottomBarV2)
    static let pressedScale: CGFloat = 0.92
    static let pressDuration: Double = 0.15
}

/// Круглая стеклянная кнопка 40×40: глиф рисуется в натуральную величину внутри бокса 20×20.
/// По решению из DECISIONS логики по тапу пока нет — колбэк опционален.
struct GlassIconButton: View {
    let icon: String
    var accessibilityTitle: String = ""
    var action: () -> Void = {}

    private var glyph: CGSize {
        glyphSize(of: icon, box: GlassIconButtonConfig.iconBox)
    }

    var body: some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: glyph.width, height: glyph.height)
                .foregroundStyle(Color.fillOne)
                .frame(width: GlassIconButtonConfig.iconBox, height: GlassIconButtonConfig.iconBox)
                .frame(width: GlassIconButtonConfig.size, height: GlassIconButtonConfig.size)
                .glassCircle()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(accessibilityTitle)
    }
}

/// Глифы экспортированы листовыми путями, поэтому инсеты из макета в ассете не запечены:
/// рисуем в натуральный размер вектора и ужимаем пропорционально только то, что в бокс не влезает
/// (`iconSearch` — 20.51 при боксе 20). Для всех остальных множитель ровно 1, растяжки нет.
/// Сердце в макете сидит на 0.42pt ниже центра бокса — этот сдвиг сознательно не переносим,
/// иначе пришлось бы держать таблицу «имя ассета → смещение», которая молча разойдётся с реэкспортом.
private func glyphSize(of name: String, box: CGFloat) -> CGSize {
    guard let natural = UIImage(named: name)?.size, natural.width > 0, natural.height > 0 else {
        return CGSize(width: box, height: box)
    }
    let fit = min(1, min(box / natural.width, box / natural.height))
    return CGSize(width: natural.width * fit, height: natural.height * fit)
}

/// Пара ♥/✕ под карточкой — figma-screen1 §2: HStack с зазором 6, лайк слева.
struct LikeDismissPair: View {
    var onLike: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(spacing: PlusMetrics.circleButtonGap) {
            GlassIconButton(icon: "iconHeart", accessibilityTitle: "Нравится", action: onLike)
            GlassIconButton(icon: "iconClose", accessibilityTitle: "Скрыть", action: onDismiss)
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
