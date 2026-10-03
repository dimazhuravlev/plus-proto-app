import SwiftUI

/// Текст с горизонтальной градиентной заливкой — в макете так набраны почти все подписи
/// (figma-screen1 §1): градиент подтянут к той стороне, где лежит обложка.
/// Типографика навешивается снаружи: `GradientText("…", from: …, to: …).plusText(.textM, .medium)`.
struct GradientText: View {
    private let text: String
    private let gradient: LinearGradient

    init(_ text: String, from: Color, to: Color) {
        self.init(text, gradient: .horizontal(from, to))
    }

    init(_ text: String, gradient: LinearGradient) {
        self.text = text
        self.gradient = gradient
    }

    var body: some View {
        Text(text).foregroundStyle(gradient)
    }
}

extension View {
    /// Горизонтальный градиент как `foregroundStyle` — для случаев, когда текст собирается не из строки.
    func gradientFill(from: Color, to: Color) -> some View {
        foregroundStyle(LinearGradient.horizontal(from, to))
    }
}

extension LinearGradient {
    static func horizontal(_ from: Color, _ to: Color) -> LinearGradient {
        LinearGradient(colors: [from, to], startPoint: .leading, endPoint: .trailing)
    }
}
