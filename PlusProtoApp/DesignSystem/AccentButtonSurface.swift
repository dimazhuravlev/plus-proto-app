import SwiftUI

/// Accent YaPS — `Type=accent YaPS` кнопки ДС (`7284:43450`). Прежде здесь был акцент
/// Yango Play (`2103:15149`) — по ДС это кнопка другого проекта (решение пользователя
/// 2026-10-17).
///
/// Три краски одной формы, все — в нормированном пространстве бокса, как их кладёт Figma
/// (`gradientTransform`): у растянутой кнопки градиент и вспышка тянутся вместе с ней.
/// - линейный градиент от тёмно-фиолетового к розовому;
/// - радиальная вспышка у верхней кромки, 37 %;
/// - бордер 1 внутрь — линейный градиент белого 10 % → 35 % → 0.
private enum AccentYaPS {
    static let base = Gradient(stops: [
        .init(color: Color(hex: 0x291A54), location: 0),
        .init(color: Color(hex: 0x5C28B1), location: 0.3977),
        .init(color: Color(hex: 0x9227D5), location: 0.5852),
        .init(color: Color(hex: 0xE668E5), location: 0.8224),
        .init(color: Color(hex: 0xF4BBE5), location: 1),
    ])
    static let baseAxis = FigmaLinearAxis(a: 0.9588, b: 0.3202, c: -0.2382)

    static let spark = Gradient(stops: [
        .init(color: Color(hex: 0xF4DAD9).opacity(0.95), location: 0),
        .init(color: Color(hex: 0xF678A4).opacity(0.85), location: 0.28),
        .init(color: Color(hex: 0xF678A4).opacity(0.45), location: 0.52),
        .init(color: Color(hex: 0x8216C5).opacity(0), location: 1),
    ])
    /// Центр и полуоси эллипса вспышки — доли бокса (матрица `[[1.8362, 0, 0.0086], [0, 4.7236, 0.5]]`)
    static let sparkCenter = CGPoint(x: 0.2676, y: 0)
    static let sparkRadii = CGSize(width: 0.2723, height: 0.1059)
    static let sparkOpacity: Double = 0.37

    static let border = Gradient(stops: [
        .init(color: .white.opacity(0.1), location: 0),
        .init(color: .white.opacity(0.35), location: 0.4759),
        .init(color: .white.opacity(0), location: 1),
    ])
    static let borderAxis = FigmaLinearAxis(a: -1.0931, b: 0.2017, c: 0.9061)
    static let borderWidth: CGFloat = 1
}

/// Ось линейного градиента Figma: первая строка `gradientTransform` — доля градиента
/// в точке бокса `t = a·x + b·y + c` (x, y — доли ширины и высоты).
private struct FigmaLinearAxis {
    let a: CGFloat
    let b: CGFloat
    let c: CGFloat

    /// Концы градиента в поинтах бокса: t = 0 и t = 1 на перпендикуляре к изолиниям.
    func points(in size: CGSize) -> (start: CGPoint, end: CGPoint) {
        let g = CGVector(dx: a / size.width, dy: b / size.height)
        let norm = g.dx * g.dx + g.dy * g.dy
        let step = CGVector(dx: g.dx / norm, dy: g.dy / norm)
        let start = CGPoint(x: -c * step.dx, y: -c * step.dy)
        return (start, CGPoint(x: start.x + step.dx, y: start.y + step.dy))
    }
}

/// Подложка accent YaPS: градиент, вспышка, бордер — одним холстом по размеру кнопки.
struct AccentYaPSFill<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.clip(to: shape.path(in: rect))

            let base = AccentYaPS.baseAxis.points(in: size)
            context.fill(Path(rect), with: .linearGradient(AccentYaPS.base, startPoint: base.start, endPoint: base.end))

            var spark = context
            spark.opacity = AccentYaPS.sparkOpacity
            let radii = CGSize(
                width: AccentYaPS.sparkRadii.width * size.width,
                height: AccentYaPS.sparkRadii.height * size.height
            )
            spark.translateBy(x: AccentYaPS.sparkCenter.x * size.width, y: AccentYaPS.sparkCenter.y * size.height)
            spark.scaleBy(x: radii.width, y: radii.height)
            let local = CGRect(
                x: -AccentYaPS.sparkCenter.x * size.width / radii.width,
                y: -AccentYaPS.sparkCenter.y * size.height / radii.height,
                width: size.width / radii.width,
                height: size.height / radii.height
            )
            spark.fill(Path(local), with: .radialGradient(AccentYaPS.spark, center: .zero, startRadius: 0, endRadius: 1))

            let border = AccentYaPS.borderAxis.points(in: size)
            let inset = AccentYaPS.borderWidth / 2
            context.stroke(
                shape.path(in: rect.insetBy(dx: inset, dy: inset)),
                with: .linearGradient(AccentYaPS.border, startPoint: border.start, endPoint: border.end),
                lineWidth: AccentYaPS.borderWidth
            )
        }
    }
}
