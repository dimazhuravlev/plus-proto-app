import SwiftUI

/// Тайминги стартового экрана.
enum SplashTiming {
    /// Сколько сплэш держится минимум. Ждать нечего, когда витрина собралась
    /// из кэша за сотню миллисекунд, — но мигнуть и пропасть он не должен:
    /// это читается сбоем, а не заставкой.
    static let minimum: Duration = .milliseconds(600)
    /// Потолок ожидания. Сеть может не ответить вовсе (или ответить через минуту),
    /// и держать пользователя на заставке до последнего нельзя: витрина сама
    /// умеет жить на моках и достраиваться по мере ответов.
    static let timeout: Duration = .seconds(6)
    /// Уход — только прозрачность. Витрина под сплэшем уже стоит целиком,
    /// поэтому проявлять её движением незачем: любой сдвиг читался бы как
    /// «экран ещё собирается», ровно то, от чего заставка и избавляет.
    static let fade: Animation = .easeInOut(duration: 0.45)

    /// `-debugNoSplash` — запуск без заставки. Отладочные прогоны снимают кадры
    /// по таймеру от старта процесса, и лишние секунды сдвигают им всю раскадровку.
    static var isDisabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "debugNoSplash")
        #else
        false
        #endif
    }
}

/// Стартовый экран (макет `2095:13607`): фирменный градиент и плюс, обрезанный
/// верхним и правым краем кадра.
///
/// Экран не декоративный. Он держит запуск, пока витрина не соберётся целиком:
/// три сервиса отвечают вразнобой, блоки подменяются с моковых на живые, обложки
/// въезжают по мере загрузки — и всё это происходило на глазах у пользователя
/// (задача 2026-08-27). Под сплэшем лента монтируется и догружается, а наружу
/// выходит уже готовой.
struct SplashScreen: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            SplashPalette.background
            PlusMark()
                .fill(.white)
                // Мягкий ореол из макета: чёрный 10 % без смещения, blur 20 ÷ 2
                // (единицы Figma к SwiftUI — тот же пересчёт, что у блюров проекта).
                .shadow(color: .black.opacity(0.1), radius: 10)
        }
        .ignoresSafeArea()
    }
}

/// Градиент заставки — одноразовый, поэтому живёт здесь, а не в токенах.
private enum SplashPalette {
    /// Из левого нижнего угла в правый верхний: в макете градиент задан вектором
    /// (0, 812) → (375, 0), то есть по диагонали кадра, а не по его стороне.
    static let background = LinearGradient(
        stops: [
            .init(color: Color(red: 1, green: 0x5C / 255, blue: 0x4D / 255), location: 0), // #FF5C4D
            .init(color: Color(red: 0xEB / 255, green: 0x46 / 255, blue: 0x9F / 255), location: 0.4), // #EB469F
            .init(color: Color(red: 0x83 / 255, green: 0x41 / 255, blue: 0xEF / 255), location: 1), // #8341EF
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}

/// Плюс Яндекса из макета заставки.
///
/// Контур перенесён точками из экспортированного вектора, а не собран из
/// прямоугольников: у знака наклонная штанга, и прямыми её не сложить. Координаты
/// макетные (холст 375), масштаб берётся от **ширины** кадра — знак упирается
/// в правый край и верхнюю кромку, и на широком экране обязан упираться так же.
private struct PlusMark: Shape {
    /// Ширина холста макета. Своя, а не `PlusMetrics.designWidth`: заставка
    /// нарисована на 375, остальной проект — на 402.
    private static let designWidth: CGFloat = 375

    /// Контур знака: ломаная из двенадцати точек, замкнутая на первую.
    private static let outline: [CGPoint] = [
        CGPoint(x: 316.916, y: 0),
        CGPoint(x: 281.268, y: 109.688),
        CGPoint(x: 375.411, y: 109.688),
        CGPoint(x: 375.411, y: 146.25),
        CGPoint(x: 269.385, y: 146.25),
        CGPoint(x: 240.866, y: 234),
        CGPoint(x: 200.647, y: 234),
        CGPoint(x: 229.166, y: 146.25),
        CGPoint(x: 131.807, y: 146.25),
        CGPoint(x: 143.702, y: 109.688),
        CGPoint(x: 241.049, y: 109.688),
        CGPoint(x: 276.697, y: 0),
    ]

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / Self.designWidth
        var path = Path()
        for (index, point) in Self.outline.enumerated() {
            let scaled = CGPoint(x: point.x * scale, y: point.y * scale)
            if index == 0 {
                path.move(to: scaled)
            } else {
                path.addLine(to: scaled)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    SplashScreen()
}
