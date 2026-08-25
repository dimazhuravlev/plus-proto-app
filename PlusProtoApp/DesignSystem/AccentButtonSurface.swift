import SwiftUI

/// Акцентная фиолетовая кнопка — компонент макета `2103:15149` (Size=xl,
/// Type=accent; по описанию компонента «не меняется в зависимости от темы»).
///
/// Три слоя одной капсулы:
/// - линейный градиент 125°: шесть стопов от тёмно-синего к розовому — стопы
///   дословно из CSS макета, ручки переведены в юнит-спейс бокса 145×56
///   тем же приёмом, что прежний градиент Play;
/// - «свечение»: плоская розовая вспышка у верхней кромки — радиальный градиент,
///   сплюснутый сжатием слоя по матрице макета (rx 39.5, ry 5.9), поверх базы
///   с непрозрачностью 0.7. За краем вспышки слой прозрачен, сжатие безопасно;
/// - бордер white 10% × 1pt.
///
/// Живёт в DesignSystem, а не у экрана: акцентные кнопки в проекте две —
/// «Смотреть» карточки тайтла и «Слушать» альбома, — и стиль у них общий
/// (решение пользователя 2026-08-25; прежде каждая несла свой градиент
/// `Gradients/Yango/Accent` без вспышки и бордера).
private enum AccentButtonStyle {
    static let base = LinearGradient(
        stops: [
            .init(color: Color(red: 0x33 / 255, green: 0x24 / 255, blue: 0x5E / 255), location: 0),
            .init(color: Color(red: 0x59 / 255, green: 0x25 / 255, blue: 0xAE / 255), location: 0.1624),
            .init(color: Color(red: 0x79 / 255, green: 0x37 / 255, blue: 0xE5 / 255), location: 0.37243),
            .init(color: Color(red: 0xA6 / 255, green: 0x45 / 255, blue: 0xF3 / 255), location: 0.57778),
            .init(color: Color(red: 0xE6 / 255, green: 0x68 / 255, blue: 0xE5 / 255), location: 0.83912),
            .init(color: Color(red: 0xF4 / 255, green: 0xBB / 255, blue: 0xE5 / 255), location: 1),
        ],
        startPoint: UnitPoint(x: 0.0761, y: -0.2782),
        endPoint: UnitPoint(x: 0.9239, y: 1.2782)
    )

    /// Вспышка. Центр — юнитами (26.8 % ширины, верхняя кромка), радиус — поинтами
    /// из макета: вспышка физического размера, на растянутой кнопке она не раздувается.
    static let spark = RadialGradient(
        stops: [
            .init(color: Color(red: 244 / 255, green: 218 / 255, blue: 217 / 255).opacity(0.95), location: 0),
            .init(color: Color(red: 245 / 255, green: 169 / 255, blue: 191 / 255).opacity(0.9), location: 0.14),
            .init(color: Color(red: 246 / 255, green: 120 / 255, blue: 164 / 255).opacity(0.85), location: 0.28),
            .init(color: Color(red: 246 / 255, green: 120 / 255, blue: 164 / 255).opacity(0.45), location: 0.52),
            .init(color: Color(red: 188 / 255, green: 71 / 255, blue: 180 / 255).opacity(0.225), location: 0.76),
            .init(color: Color(red: 130 / 255, green: 22 / 255, blue: 197 / 255).opacity(0), location: 1),
        ],
        center: UnitPoint(x: 0.2676, y: 0),
        startRadius: 0,
        endRadius: 39.5
    )
    /// Эллиптичность вспышки: ry / rx из матрицы градиента макета
    static let sparkFlatten: CGFloat = 5.93 / 39.48
    static let sparkOpacity: Double = 0.7

    static let border = Color.white.opacity(0.1)
    static let borderWidth: CGFloat = 1
}

extension View {
    /// Подложка акцентной кнопки: градиент, вспышка у верхней кромки, бордер.
    func accentButtonSurface() -> some View {
        let shape = Capsule(style: .continuous)
        return background {
            ZStack {
                Rectangle()
                    .fill(AccentButtonStyle.base)
                Rectangle()
                    .fill(AccentButtonStyle.spark)
                    .scaleEffect(x: 1, y: AccentButtonStyle.sparkFlatten, anchor: .top)
                    .opacity(AccentButtonStyle.sparkOpacity)
            }
            .clipShape(shape)
        }
        .overlay {
            shape.strokeBorder(AccentButtonStyle.border, lineWidth: AccentButtonStyle.borderWidth)
        }
        .contentShape(shape)
    }
}
