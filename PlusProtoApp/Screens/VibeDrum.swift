import SwiftUI
import UIKit

/// Числа барабана станций «Моей волны» — макет `2:6398` (файл «ЯПС · Mobile · Current
/// State», задача пользователя 2026-10-09). Лепесток снят в центре, в полную величину:
/// кадр 213×278, видимый центр — на 149 от левого края (капля наклонена вправо, иконка
/// и подпись стоят над её верхней частью).
enum VibeDrumLayout {
    static let petal = CGSize(width: 213, height: 278)
    /// Видимый центр лепестка — иконка и подпись — по горизонтали от левого края кадра
    static let petalCenterX: CGFloat = 149
    /// Капля — 213×244 под иконкой: с 34 сверху до низа кадра
    static let blobTop: CGFloat = 34
    /// Иконка агента — 64 по центру на 34 сверху; ассет с полем под тени — ~70
    static let agentCenterY: CGFloat = 34
    static let agentSize: CGFloat = 70
    /// Фото исполнителя — сам круг 64, без поля под тени
    static let photoSize: CGFloat = 64
    /// Подпись — Text M, колонка 112, с 74 сверху, до четырёх строк (бокс 80)
    static let titleTop: CGFloat = 74
    static let titleWidth: CGFloat = 112
    static let titleLines = 3

    /// Барабан: лепестки стоят на окружности. По макету соседи в 120.5 от центра,
    /// следующие — ещё в 108.5: это точки окружности радиуса 380 через 18.5°.
    /// Масштаб — 1, 0.9, 0.8 к краям, низ у всех на одной линии.
    static let radius: CGFloat = 380
    static let angleStep: Double = 18.5 * .pi / 180
    static var step: CGFloat { radius * CGFloat(sin(angleStep)) }
    static let scaleStep: CGFloat = 0.1
    static let minScale: CGFloat = 0.5

    /// Видимая часть барабана над action bar — от верха лепестка до верха бара:
    /// в макете до верха таббара 186, барабан опущен на 12 (правка пользователя
    /// 2026-10-10). Ниже лепестки уходят под нижний хром.
    static let visibleHeight: CGFloat = 174

    /// Блюр капли — макетный stdDeviation 15.82 (Figma 31.65 пополам, как у всех
    /// блюров проекта) и поле растра под него.
    static let blobBlur: CGFloat = 15.82
    static let blobPadding: CGFloat = 48

    /// Где лепесток относительно центра барабана в шагах: 0 — по центру, ±1 — соседи.
    static func position(of proxy: GeometryProxy) -> CGFloat {
        guard let viewport = proxy.bounds(of: .scrollView) else { return 0 }
        return (proxy.size.width / 2 - viewport.midX) / step
    }

    /// Сдвиг лепестка с прямой ленты на дугу: на ленте он в `d · step`, на окружности —
    /// в `R · sin(d · α)`. Дальше ±90° он уже за краем экрана — там держим на прямой.
    static func arcShift(_ d: CGFloat) -> CGFloat {
        let angle = Double(d) * angleStep
        guard abs(angle) < .pi / 2 else { return 0 }
        return radius * CGFloat(sin(angle)) - d * step
    }

    static func scale(_ d: CGFloat) -> CGFloat {
        max(minScale, 1 - scaleStep * abs(d))
    }
}

/// Станция барабана — текстом и цветами макета. Иконки агентов растрированы из SVG
/// макета с их внутренними тенями (фильтры SVG iOS не рисует).
struct VibeStation: Identifiable {
    let id: String
    let title: String
    /// Иконка агента — ассет; у станции исполнителя вместо неё фото (`photo`).
    let agent: String
    /// Цвет капли и её светлой кромки
    let fill: Color
    let rim: Color
    /// Фото исполнителя кругом — у станции исполнителя (в макете у Cream soda фото
    /// группы; в экспорт SVG оно не попало, берём фото Deezer, id 5535442).
    var photo: URL? = nil

    /// Пять лепестков макета, слева направо. Капсулу «В стиле: The Mars Volta» не
    /// добавляем (правка пользователя 2026-10-09).
    static let all: [VibeStation] = [
        VibeStation(id: "testosterone", title: "Укол тестостерона", agent: "vibeAgentElectronicsPink",
                    fill: Color(hex: 0xE7338F), rim: Color(hex: 0xF4A4CD)),
        VibeStation(id: "cream-soda", title: "Cream soda", agent: "",
                    fill: Color(hex: 0x5C8E9B), rim: Color(hex: 0x99F2FF),
                    photo: URL(string: "https://cdn-images.dzcdn.net/images/artist/e41bf19f0bd5fbe74298b1981a21cd77/250x250-000000-80-0-0.jpg")),
        VibeStation(id: "garage", title: "Спальничный гэридж", agent: "vibeAgentPop",
                    fill: Color(hex: 0xF02A4F), rim: Color(hex: 0xF8A0B0)),
        VibeStation(id: "night-minimal", title: "Ночной минимал", agent: "vibeAgentElectronicsBlue",
                    fill: Color(hex: 0x426DF5), rim: Color(hex: 0x9EB4FA)),
        VibeStation(id: "testosterone-altrock", title: "Укол тестостерона", agent: "vibeAgentAltrock",
                    fill: Color(hex: 0x4F6C9B), rim: Color(hex: 0xBBC8DD)),
    ]

    /// Стартовая — по центру макета
    static let startIndex = 2
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Барабан станций над action bar: лепестки листаются вбок и катятся по дуге — к краям
/// уходят вниз-внутрь и мельчают. Положение, масштаб и сдвиг — функция скролла
/// (`visualEffect`), без стейта на кадре.
///
/// Круг — три копии набора, как у промо: работает средняя, а свайп, остановившийся
/// в крайней, перескакивает на тот же лепесток средней. Ряды не ленивые — у ленивых
/// перескок мелькал прежней карточкой (грабли промо «Главной»).
struct VibeDrum: View {
    /// Тап по лепестку в центре — включить его станцию
    var onPlay: (VibeStation) -> Void

    private typealias Layout = VibeDrumLayout
    private static let copies = 3
    private let stations = VibeStation.all

    @State private var page: Int?
    @State private var isPlaced = false
    /// Станция в центре — по ней щёлкает трещотка: перескок копий и стартовая
    /// постановка станцию не меняют и молчат.
    @State private var centered = VibeStation.startIndex

    init(onPlay: @escaping (VibeStation) -> Void) {
        self.onPlay = onPlay
        _page = State(initialValue: VibeStation.all.count + VibeStation.startIndex)
    }

    private var count: Int { stations.count }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(0..<(count * Self.copies), id: \.self) { index in
                        slot(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, (PlusMetrics.designWidth - Layout.step) / 2, for: .scrollContent)
            .scrollPosition(id: $page, anchor: .center)
            .scrollIndicators(.hidden)
            // Лепестки шире шага и выходят за кадр ленты — их видно.
            .scrollClipDisabled()
            .frame(height: Layout.petal.height)
            .onScrollGeometryChange(for: DrumGeometry.self) { geometry in
                DrumGeometry(
                    position: (geometry.contentOffset.x + geometry.contentInsets.leading) / Layout.step,
                    contentWidth: geometry.contentSize.width
                )
            } action: { _, geometry in
                placeIfNeeded(at: geometry, proxy: proxy)
            }
            .onScrollPhaseChange { _, phase in
                if phase == .idle { settle() }
            }
            .onChange(of: page) { _, page in
                guard let page, page % count != centered else { return }
                centered = page % count
                // Лепесток прошёл через центр — щелчок трещотки, как у колеса пикера.
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    private func slot(_ index: Int) -> some View {
        let station = stations[index % count]
        return VibePetal(station: station)
            // Видимый центр лепестка — по центру слота
            .offset(x: Layout.petal.width / 2 - Layout.petalCenterX)
            .frame(width: Layout.step, height: Layout.petal.height, alignment: .top)
            .visualEffect { content, proxy in
                let d = Layout.position(of: proxy)
                return content
                    .scaleEffect(Layout.scale(d), anchor: .bottom)
                    .offset(x: Layout.arcShift(d))
            }
            // Соседи — поверх центрального, как в макете.
            .zIndex(index == page ? 0 : 1)
            .contentShape(.rect)
            .pressScale(PressMotion.cardScale)
            .onTapGesture { tap(index) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(station.title)
            .accessibilityAddTraits(.isButton)
    }

    /// Тап по центральному — его станция; по соседу — он доезжает в центр.
    private func tap(_ index: Int) {
        if index == page {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            onPlay(stations[index % count])
        } else {
            withAnimation(ShowcasePromoMotion.step) { page = index }
        }
    }

    /// Свайп остановился в крайней копии — перескок на ту же станцию средней, без анимации.
    private func settle() {
        guard let current = page else { return }
        let middle = count + current % count
        guard current != middle else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { page = middle }
    }

    /// Стартовая позиция по id приходит раньше раскладки — первая геометрия ставит
    /// барабан на стартовую станцию (приём промо «Главной», `ShowcasePromo`).
    /// Ставим, только когда у ленты уже есть ширина: первая геометрия бывает до раскладки,
    /// и барабан уезжал в конец ленты (кадр 2026-10-09).
    private func placeIfNeeded(at geometry: DrumGeometry, proxy: ScrollViewProxy) {
        guard !isPlaced, geometry.contentWidth > 0, let target = page else { return }
        isPlaced = true
        guard abs(geometry.position - CGFloat(target)) > 0.01 else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { proxy.scrollTo(target, anchor: .center) }
    }
}

private struct DrumGeometry: Equatable {
    let position: CGFloat
    let contentWidth: CGFloat
}

/// Лепесток: размытая капля, иконка агента сверху, подпись внутри.
private struct VibePetal: View {
    let station: VibeStation

    private typealias Layout = VibeDrumLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            VibeBlobRaster(station: station)
                .offset(x: -Layout.blobPadding, y: -Layout.blobPadding)

            agent
                .offset(
                    x: Layout.petalCenterX - Layout.agentSize / 2,
                    y: Layout.agentCenterY - Layout.agentSize / 2
                )

            Text(station.title)
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillOne)
                .multilineTextAlignment(.center)
                .lineLimit(Layout.titleLines)
                .frame(width: Layout.titleWidth, alignment: .top)
                .offset(x: Layout.petalCenterX - Layout.titleWidth / 2, y: Layout.titleTop)
        }
        .frame(width: Layout.petal.width, height: Layout.petal.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    /// Иконка агента или фото исполнителя кругом; пока фото грузится — серый круг скелетона.
    @ViewBuilder
    private var agent: some View {
        if let photo = station.photo {
            ArtworkImage(source: .remote(photo))
                .aspectRatio(contentMode: .fill)
                .frame(width: Layout.photoSize, height: Layout.photoSize)
                .background(PlusSkeleton.fill)
                .clipShape(Circle())
                .frame(width: Layout.agentSize, height: Layout.agentSize)
        } else {
            Image(station.agent)
                .resizable()
                .frame(width: Layout.agentSize, height: Layout.agentSize)
        }
    }
}

/// Капля — растр на цвет, посчитанный один раз: блюр по капле 213×244 на скролле
/// пересчитывался бы у каждого из пятнадцати лепестков. Растр ×2 — правая кромка
/// у капли чёткая.
private struct VibeBlobRaster: View {
    let station: VibeStation

    var body: some View {
        if let image = VibeBlobCache.image(for: station) {
            Image(uiImage: image)
                .resizable()
                .frame(width: VibeBlobShape.canvas.width, height: VibeBlobShape.canvas.height)
        }
    }
}

@MainActor
private enum VibeBlobCache {
    private static var images: [String: UIImage] = [:]

    static func image(for station: VibeStation) -> UIImage? {
        if let hit = images[station.id] { return hit }
        let renderer = ImageRenderer(content: VibeBlobShape(fill: station.fill, rim: station.rim))
        renderer.scale = 2
        let image = renderer.uiImage
        images[station.id] = image
        return image
    }
}

/// Капля макета `testosterone_bg_x2`: наклонный овал из SVG, заливка — цвет станции,
/// к низу-влево уходящий в прозрачность, кромка 1 изнутри — светлый тон, тающий к низу.
///
/// Блюр — прогрессивный: справа-сверху капля чёткая, со светлой кромкой, к низу-влево
/// размыта (кадр макета). Экспорт SVG передаёт его ровным блюром на всю каплю — так она
/// выходила бледным пятном. Повторяем двумя слоями: чёткая и размытая копии, сменяющие
/// друг друга по градиенту маски. Координаты — кадра лепестка, со сдвигом на поле растра.
private struct VibeBlobShape: View {
    let fill: Color
    let rim: Color

    private typealias Layout = VibeDrumLayout

    static var canvas: CGSize {
        CGSize(
            width: Layout.petal.width + Layout.blobPadding * 2,
            height: Layout.petal.height + Layout.blobPadding * 2
        )
    }

    /// Доля непрозрачности заливки по ходу градиента — 16 стопов макета. Цвет стопа —
    /// цвет станции, притушенный на ту же долю: так в макете.
    private static let fillStops: [(location: CGFloat, opacity: Double)] = [
        (0, 1), (0.111674, 0.922548), (0.208059, 0.849719), (0.2912, 0.7808),
        (0.363141, 0.715081), (0.425926, 0.651852), (0.4816, 0.5904), (0.532207, 0.530015),
        (0.579793, 0.469985), (0.6264, 0.4096), (0.674074, 0.348148), (0.724859, 0.284919),
        (0.7808, 0.2192), (0.843941, 0.150281), (0.916326, 0.0774519), (1, 0),
    ]

    /// Ось прогрессивного блюра — от чёткого верха-справа к размытому низу-слева, в долях холста
    private static let sharpPoint = UnitPoint(x: 0.82, y: 0.12)
    private static let blurredPoint = UnitPoint(x: 0.2, y: 0.7)

    var body: some View {
        ZStack {
            blob
                .mask(LinearGradient(colors: [.white, .clear], startPoint: Self.sharpPoint, endPoint: Self.blurredPoint))
            blob
                .blur(radius: Layout.blobBlur)
                .mask(LinearGradient(colors: [.clear, .white], startPoint: Self.sharpPoint, endPoint: Self.blurredPoint))
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
    }

    private var blob: some View {
        let p = Layout.blobPadding
        return Canvas { context, _ in
            let shape = Self.path(offset: CGPoint(x: p, y: p))
            // Клип макета — прямоугольник капли 213×244
            context.clip(to: Path(CGRect(x: p, y: p + Layout.blobTop, width: Layout.petal.width, height: Layout.petal.height - Layout.blobTop)))
            context.fill(shape, with: .linearGradient(
                Gradient(stops: Self.fillStops.map { stop in
                    .init(color: Self.dimmed(fill, by: stop.opacity).opacity(stop.opacity), location: stop.location)
                }),
                startPoint: CGPoint(x: p + 176.187, y: p + 35.751),
                endPoint: CGPoint(x: p + 90.064, y: p + 152.698)
            ))
            // Кромка 2 по контуру, срезанная по самой капле, — внутренняя 1
            var rimContext = context
            rimContext.clip(to: shape)
            rimContext.stroke(shape, with: .linearGradient(
                Gradient(colors: [rim, rim.opacity(0)]),
                startPoint: CGPoint(x: p + 184.771, y: p + 36.502),
                endPoint: CGPoint(x: p + 122.291, y: p + 143.540)
            ), lineWidth: 2)
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
    }

    /// Цвет, притушенный к чёрному на долю `factor` — стопы макета.
    private static func dimmed(_ color: Color, by factor: Double) -> Color {
        let resolved = color.resolve(in: EnvironmentValues())
        return Color(
            red: Double(resolved.red) * factor,
            green: Double(resolved.green) * factor,
            blue: Double(resolved.blue) * factor
        )
    }

    /// Контур капли — путь SVG макета в координатах кадра лепестка (SVG сдвинут
    /// на поле своего фильтра 31.65 и стоит на 34 ниже верха кадра).
    private static func path(offset o: CGPoint) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: o.x + x - 31.6468, y: o.y + y - 31.6468 + VibeDrumLayout.blobTop)
        }
        var path = Path()
        path.move(to: pt(209.527, 188.805))
        path.addCurve(to: pt(59.1092, 270.437), control1: pt(165.876, 253.307), control2: pt(98.5314, 289.855))
        path.addCurve(to: pt(66.7666, 118.488), control1: pt(19.687, 251.02), control2: pt(23.1153, 182.99))
        path.addCurve(to: pt(217.184, 36.8562), control1: pt(110.418, 53.9866), control2: pt(177.762, 17.4387))
        path.addCurve(to: pt(209.527, 188.805), control1: pt(256.607, 56.2737), control2: pt(253.178, 124.304))
        path.closeSubpath()
        return path
    }
}
