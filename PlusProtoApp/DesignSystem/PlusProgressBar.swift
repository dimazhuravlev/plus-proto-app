import SwiftUI

enum PlusProgressBarConfig {
    /// Высота из макета; радиус 8 при такой высоте схлопывается в капсулу
    static let height: CGFloat = 6
    /// Подтяжка филла за прогрессом — как у мини-плеера MusicPlayer
    static let fillAnimation: Animation = .easeOut(duration: 0.12)
}

/// Прогресс-бар витрины: трек white 10%, филл — акцент Плюса.
///
/// Две неочевидности, обе выяснены отладкой на карточке «продолжить смотреть»:
///
/// 1. Форма — `RoundedRectangle` с радиусом в половину высоты, а не `Capsule`.
///    Внутри повёрнутого контейнера капсула печаталась **двумя** полосами: одна на своём
///    месте, вторая ниже. С прямоугольником дефекта нет, а при высоте 6 форма та же.
/// 2. Заливка — одна фигура с двухзонным градиентом, а не «трек + филл поверх».
///    Двумя слоями филл раздваивался точно так же.
///
/// Ширина задаётся явно (108 в карточке чтения, 261 в карточке просмотра): `GeometryReader`
/// занял бы всё предложенное место и добавил лишний проход раскладки на каждом кадре скролла.
struct PlusProgressBar: View {
    let progress: Double
    let width: CGFloat

    private var fraction: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: PlusProgressBarConfig.height / 2, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .plusAccent, location: 0),
                        .init(color: .plusAccent, location: fraction),
                        .init(color: .buttonsPrimary, location: fraction),
                        .init(color: .buttonsPrimary, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: PlusProgressBarConfig.height)
            .animation(PlusProgressBarConfig.fillAnimation, value: progress)
    }
}
