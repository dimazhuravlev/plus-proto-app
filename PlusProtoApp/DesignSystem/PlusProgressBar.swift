import SwiftUI

enum PlusProgressBarConfig {
    /// Высота из макета; радиус 8 при такой высоте схлопывается в капсулу
    static let height: CGFloat = 6
    /// Подтяжка филла за прогрессом — как у мини-плеера MusicPlayer
    static let fillAnimation: Animation = .easeOut(duration: 0.12)
}

/// Прогресс-бар витрины: трек white 10%, филл — акцент Плюса.
/// Ширину задаёт вызывающая сторона (108 в карточке чтения, 261 в карточке просмотра).
struct PlusProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.buttonsPrimary)
                Capsule(style: .continuous)
                    .fill(Color.plusAccent)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: PlusProgressBarConfig.height)
        .animation(PlusProgressBarConfig.fillAnimation, value: progress)
    }
}
