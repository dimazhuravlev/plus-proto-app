import SwiftUI
import UIKit

/// Числа карточки станции «Моей волны» в промо «Главной» — макет `2688:26198` (задача 65).
/// Кадр 208×249 на 402; вся геометрия умножается на `ShowcasePromoLayout.stationScale`, шрифты — нет.
enum PromoStationLayout {
    static let frame = CGSize(width: 208, height: 249)

    /// Капля — эллипс 248.9×443.9, повёрнутый на 41° по часовой вокруг своего центра
    /// в (35.4, 233) кадра: уходит влево-вниз за кадр — это норма, слайдер без клипа.
    static let blob = CGSize(width: 248.9, height: 443.9)
    static let blobCenter = CGPoint(x: 35.4, y: 233)
    static let blobRotation: Angle = .degrees(41)
    /// Градиенты заливки и кромки — в несвёрнутой рамке эллипса, от её левого верхнего угла.
    /// Заливка к 248 уходит в ноль, кромка — к 221.8: ниже растр не нужен.
    static let fillStart = CGPoint(x: 107.9, y: 6.33)
    static let fillEnd = CGPoint(x: 143.2, y: 248)
    static let rimStart = CGPoint(x: 86.4, y: 7.05)
    static let rimEnd = CGPoint(x: 124, y: 221.8)
    /// Кромка — обводка 1.44 внутрь эллипса
    static let rimWidth: CGFloat = 1.44

    /// Блюр макета — σ 23.01 (в панели Figma вдвое больше, конвенция проекта).
    static let blur: CGFloat = 23.01
    /// Прогрессивный блюр Фигмы наращивает радиус, а не смешивает чёткую каплю с размытой:
    /// по кадру макета (замер 2026-10-13) кромка у верхнего конца чёткая, на трети длины
    /// размыта на ~7, к середине — полностью. Доли — длины большой оси от верхнего конца:
    /// чёткая копия до 8 %, к 16 % — слегка размытая, она до 28 %, к 44 % — размытая.
    /// Двумя копиями (чётко до 20 %, размыто с 70 %) по бокам оставалась резкая кромка,
    /// которой в макете нет.
    static let midBlur: CGFloat = 7
    static let sharpUntil: CGFloat = 0.08
    static let midFrom: CGFloat = 0.16
    static let midUntil: CGFloat = 0.28
    static let blurredFrom: CGFloat = 0.44
    /// Поле растра под блюр — три радиуса
    static let blobPadding: CGFloat = 70

    /// Иллюстрация агента 112×98 — по центру квадрата 112 с левым верхним углом в (48, −6)
    static let artBox: CGFloat = 112
    static let art = CGSize(width: 112, height: 98)
    /// Прозрачное поле растра иллюстрации под запечённый прогрессивный блюр её верхнего левого
    /// угла (в макете — слой фонового блюра, SVG и PNG-экспорт его не передают; запечён
    /// скриптом из растра с внутренними тенями, правка пользователя 2026-10-13).
    static let artBlurPad: CGFloat = 10
    static let artOrigin = CGPoint(x: 48, y: -6)

    /// Текст — колонка 163 с левым краем на 22.5 и верхом на 119: «Моя волна», под ней
    /// через 2 — название станции до трёх строк; всё по центру колонки.
    static let textLeading: CGFloat = 22.5
    static let textTop: CGFloat = 119
    static let textWidth: CGFloat = 163
    static let textGap: CGFloat = 2
    static let nameLines = 3

    /// Пара ✕/✓ — внутри карточки, левый верхний угол в (61, 214)
    static let pairOrigin = CGPoint(x: 61, y: 214)

    /// Волна «в стиле артиста» — макет `2698:27113`, те же координаты. Фото — круг во весь
    /// квадрат `artBox`, обводка 1 белым 15 % внутрь и внутреннее свечение белым 50 %
    /// (в макете inset-блюр 32, в коде радиус вдвое меньше — конвенция проекта).
    static let artistStroke: CGFloat = 1
    static let artistGlowRadius: CGFloat = 16
    static let artistGlowOpacity: Double = 0.5
    /// «Моя волна» и «в стиле артиста» — две строки, имя артиста под ними — до двух.
    static let artistTitleLines = 2
    static let artistNameLines = 2
}

/// Карточка станции в промо «Главной»: капля цвета станции, над ней иллюстрация агента,
/// в капле — «Моя волна» и название станции. У волны «в стиле артиста» (задача 68) вместо
/// иллюстрации — круглое фото артиста, текст — «Моя волна / в стиле артиста» и имя артиста.
/// Пару ✕/✓ кладёт слайдер — оверлеем
/// на `PromoStationLayout.pairOrigin` (`ShowcasePromo.card`); подписи под карточкой нет.
///
/// Кадр — распорка 208×249: кнопке и касаниям — ровно он, капля уходит за него фоном.
/// Смена по ✕ — на каждом слое по отдельности (`showcaseSwappable`), масштаб — от его центра.
struct PromoStationCard: View {
    let title: String
    let station: VibePromoStation
    var showsCaption = true

    private typealias Layout = PromoStationLayout

    var body: some View {
        let scale = ShowcasePromoLayout.stationScale
        Color.clear
            .frame(width: Layout.frame.width * scale, height: Layout.frame.height * scale)
            .background(alignment: .topLeading) {
                PromoStationPetal(station: station)
            }
            .overlay(alignment: .topLeading) {
                art
                    .frame(width: Layout.artBox * scale, height: Layout.artBox * scale)
                    .showcaseSwappable()
                    .offset(x: Layout.artOrigin.x * scale, y: Layout.artOrigin.y * scale)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topLeading) {
                if showsCaption {
                    PromoStationCaption(title: title, station: station)
                        .showcaseSwappable()
                        .offset(x: Layout.textLeading * scale, y: Layout.textTop * scale)
                }
            }
            .contentShape(.rect)
    }

    /// Иллюстрация агента — с прозрачным полем под запечённый блюр угла; фото артиста —
    /// круг во весь квадрат.
    @ViewBuilder
    private var art: some View {
        let scale = ShowcasePromoLayout.stationScale
        switch station.kind {
        case .genre(let asset):
            Image(asset)
                .resizable()
                .frame(width: (Layout.art.width + 2 * Layout.artBlurPad) * scale,
                       height: (Layout.art.height + 2 * Layout.artBlurPad) * scale)
        case .artist(let artist):
            PromoArtistWavePhoto(picture: artist.picture, diameter: Layout.artBox * scale)
        }
    }
}

/// Общая текстовая колонка: её реальная высота определяет положение кнопок,
/// без GeometryReader и обратной связи размера в раскладку.
struct PromoStationCaption: View {
    let title: String
    let station: VibePromoStation

    var body: some View {
        let isArtist = station.artist != nil
        let scale = ShowcasePromoLayout.stationScale
        VStack(spacing: PromoStationLayout.textGap * scale) {
            Text(title).plusText(.textM, .medium).foregroundStyle(Color.fillOne)
                .lineLimit(isArtist ? PromoStationLayout.artistTitleLines : 1)
            Text(station.name).plusText(.textM, .medium).foregroundStyle(Color.fillSubtitle)
                .lineLimit(isArtist ? PromoStationLayout.artistNameLines : PromoStationLayout.nameLines)
        }
        .multilineTextAlignment(.center)
        .frame(width: PromoStationLayout.textWidth * scale)
    }
}

/// Фото артиста волны «в стиле артиста» (макет `2698:27113`): круг, внутреннее белое
/// свечение и обводка внутрь. Фото — через скелетон (`SkeletonArtwork`: из памяти —
/// с первого кадра), свечение — готовый растр (`PromoArtistGlow`), а не блюр на кадре:
/// живой блюр пересчитывался бы у каждой копии круга.
private struct PromoArtistWavePhoto: View {
    let picture: ArtworkSource
    let diameter: CGFloat

    private typealias Layout = PromoStationLayout

    var body: some View {
        PlusSkeleton.fill
            .overlay { SkeletonArtwork(source: picture) }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay {
                if let glow = PromoArtistGlow.image(diameter: diameter) {
                    Image(uiImage: glow)
                        .resizable()
                        .frame(width: diameter, height: diameter)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        Color.fillEight,
                        lineWidth: Layout.artistStroke * ShowcasePromoLayout.stationScale
                    )
                    .allowsHitTesting(false)
            }
    }
}

/// Внутреннее свечение фото артиста — белое кольцо, размытое к центру и срезанное кругом:
/// растр, посчитанный один раз на диаметр. Масштаб промо и экрана — константы процесса.
@MainActor
private enum PromoArtistGlow {
    private static var images: [CGFloat: UIImage] = [:]

    static func image(diameter: CGFloat) -> UIImage? {
        if let hit = images[diameter] { return hit }
        let renderer = ImageRenderer(content: PromoArtistGlowShape(diameter: diameter))
        renderer.scale = PromoPetalCache.displayScale
        guard let image = renderer.uiImage else { return nil }
        let prepared = image.preparingForDisplay() ?? image
        images[diameter] = prepared
        return prepared
    }
}

/// Кольцо свечения: белая заливка снаружи круга (чётно-нечётная — сам круг пустой)
/// с полем в три радиуса блюра, размытая и срезанная по кругу.
private struct PromoArtistGlowShape: View {
    let diameter: CGFloat

    private typealias Layout = PromoStationLayout

    var body: some View {
        let radius = Layout.artistGlowRadius * ShowcasePromoLayout.stationScale
        let side = diameter + radius * 6
        Ring(diameter: diameter)
            .fill(Color.white.opacity(Layout.artistGlowOpacity), style: FillStyle(eoFill: true))
            .frame(width: side, height: side)
            .blur(radius: radius)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
    }

    /// Квадрат кадра с вырезанным по центру кругом.
    private struct Ring: Shape {
        let diameter: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path(rect)
            path.addEllipse(in: CGRect(
                x: rect.midX - diameter / 2,
                y: rect.midY - diameter / 2,
                width: diameter,
                height: diameter
            ))
            return path
        }
    }
}

/// Капля станции — растр, посчитанный один раз на цвет: живой прогрессивный блюр
/// пересчитывался бы у каждой копии круга. В растре капля не повёрнута — поворот и место
/// задаёт трансформ вью, он ничего не стоит.
struct PromoStationPetal: View {
    let station: VibePromoStation

    private typealias Layout = PromoStationLayout

    var body: some View {
        let scale = ShowcasePromoLayout.stationScale
        let canvas = PromoStationBlob.canvas(scale: scale)
        let center = PromoStationBlob.center(scale: scale)
        if let image = PromoPetalCache.image(for: station) {
            Image(uiImage: image)
                .resizable()
                .frame(width: canvas.width, height: canvas.height)
                .showcaseSwappable()
                .rotationEffect(
                    Layout.blobRotation,
                    anchor: UnitPoint(x: center.x / canvas.width, y: center.y / canvas.height)
                )
                .offset(x: Layout.blobCenter.x * scale - center.x, y: Layout.blobCenter.y * scale - center.y)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Растры капель станций среди айтемов — заранее: под заставкой (`AppRootView`)
    /// и в подготовке замены по ✕ (`ShowcaseCatalog`), а не на первом кадре показа.
    /// Фото артиста отдельно греет `ArtworkLoader` по `ShowcaseBlock.artworks`;
    /// в растр свечения промо входит только лепесток, без фото.
    /// Фон промо под волной «в стиле артиста» — растр её капли (цвет станции), а не фото.
    /// Источник фона — `ArtworkSource.asset` с этим префиксом и номером цвета палитры.
    static let backdropPrefix = "promoPetalBackdrop:"

    @MainActor
    static func backdropImage(paletteIndex: Int) -> UIImage? {
        guard VibePromoStation.palette.indices.contains(paletteIndex) else { return nil }
        let color = VibePromoStation.palette[paletteIndex]
        return PromoPetalCache.image(for: VibePromoStation(
            id: "palette-\(paletteIndex)", name: "", asset: "", fill: color.fill, rim: color.rim
        ))
    }

    static func prewarm(_ blocks: [ShowcaseBlock]) {
        for case .vibe(let vibe) in blocks {
            guard let station = vibe.station else { continue }
            _ = PromoPetalCache.image(for: station)
            if station.artist != nil {
                _ = PromoArtistGlow.image(diameter: PromoStationLayout.artBox * ShowcasePromoLayout.stationScale)
            }
        }
    }
}

/// Растры капель — по цвету станции, заливке и кромке. Масштаб промо и экрана — константы
/// процесса.
@MainActor
private enum PromoPetalCache {
    private struct Key: Hashable {
        let fill: Color
        let rim: Color
    }

    private static var images: [Key: UIImage] = [:]

    static func image(for station: VibePromoStation) -> UIImage? {
        let key = Key(fill: station.fill, rim: station.rim)
        if let hit = images[key] { return hit }
        let renderer = ImageRenderer(content: PromoStationBlob(
            fill: station.fill,
            rim: station.rim,
            scale: ShowcasePromoLayout.stationScale
        ))
        renderer.scale = displayScale
        guard let image = renderer.uiImage else { return nil }
        // Растр готов к показу сразу, а не на первой отрисовке.
        let prepared = image.preparingForDisplay() ?? image
        images[key] = prepared
        return prepared
    }

    /// Масштаб экрана — со сцены; без неё (самый ранний кадр) — 3, как у iPhone проекта.
    static var displayScale: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.traitCollection.displayScale ?? 3
    }
}

/// Второй тон капли станции — тот же цвет, повёрнутый по тону на 10° к жёлтому: зелёный
/// уходит в салатовый, синий — в бирюзу, лиловый — в мадженту; насыщенность и яркость те же.
/// Расхождение едва заметное (правка пользователя 2026-10-16).
enum PromoStationTint {
    static let hueShift: CGFloat = 10.0 / 360.0
    /// Жёлтый — 60° круга тонов.
    private static let yellow: CGFloat = 60.0 / 360.0

    static func neighbor(of color: Color) -> Color {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return color
        }
        // Кратчайший путь по кругу тонов к жёлтому, не дальше самого жёлтого.
        var delta = yellow - hue
        if delta > 0.5 { delta -= 1 }
        if delta < -0.5 { delta += 1 }
        let step = min(abs(delta), hueShift) * (delta < 0 ? -1 : 1)
        var shifted = hue + step
        if shifted < 0 { shifted += 1 }
        if shifted >= 1 { shifted -= 1 }
        return Color(hue: Double(shifted), saturation: Double(saturation), brightness: Double(brightness), opacity: Double(alpha))
    }
}

/// Несвёрнутая капля с полем под блюр: эллипс макета, заливка цветом станции, к середине
/// уходящая в прозрачность (стопы — общие с барабаном, `VibeBlobFill`), и кромка 1.44
/// изнутри — светлый тон, тающий туда же. Холст — только верх эллипса, до конца заливки:
/// ниже капля прозрачная.
///
/// Блюр — прогрессивный, приёмом капли барабана (`VibeBlobShape`): копии сменяют друг
/// друга по градиентам масок вдоль большой оси. Копий три — чёткая, слегка и полностью
/// размытая, — так радиус растёт, как в макете. Маски в сумме дают единицу, а копии
/// складываются (`plusLighter`): обычным наложением на стыках копий заливка темнела полосой.
private struct PromoStationBlob: View {
    let fill: Color
    let rim: Color
    let scale: CGFloat

    private typealias Layout = PromoStationLayout

    static func canvas(scale: CGFloat) -> CGSize {
        CGSize(
            width: (Layout.blob.width + Layout.blobPadding * 2) * scale,
            height: (Layout.fillEnd.y + Layout.blobPadding * 2) * scale
        )
    }

    /// Центр эллипса на холсте — ось поворота
    static func center(scale: CGFloat) -> CGPoint {
        CGPoint(
            x: (Layout.blobPadding + Layout.blob.width / 2) * scale,
            y: (Layout.blobPadding + Layout.blob.height / 2) * scale
        )
    }

    var body: some View {
        let canvas = Self.canvas(scale: scale)
        ZStack {
            shape
                .mask(mask([(.white, Layout.sharpUntil), (.clear, Layout.midFrom)]))
            shape
                .blur(radius: Layout.midBlur * scale)
                .mask(mask([
                    (.clear, Layout.sharpUntil), (.white, Layout.midFrom),
                    (.white, Layout.midUntil), (.clear, Layout.blurredFrom),
                ]))
                .blendMode(.plusLighter)
            shape
                .blur(radius: Layout.blur * scale)
                .mask(mask([(.clear, Layout.midUntil), (.white, Layout.blurredFrom)]))
                .blendMode(.plusLighter)
        }
        .compositingGroup()
        .frame(width: canvas.width, height: canvas.height)
    }

    /// Маска вдоль большой оси: доли её длины от верхнего конца — в доли высоты холста.
    private func mask(_ stops: [(color: Color, share: CGFloat)]) -> LinearGradient {
        let height = Layout.fillEnd.y + Layout.blobPadding * 2
        return LinearGradient(
            stops: stops.map { stop in
                .init(color: stop.color, location: (Layout.blobPadding + stop.share * Layout.blob.height) / height)
            },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shape: some View {
        let canvas = Self.canvas(scale: scale)
        return Canvas { [fill, rim, scale] context, size in
            let padding = Layout.blobPadding
            func point(_ point: CGPoint) -> CGPoint {
                CGPoint(x: (padding + point.x) * scale, y: (padding + point.y) * scale)
            }
            let ellipse = Path(ellipseIn: CGRect(
                x: padding * scale,
                y: padding * scale,
                width: Layout.blob.width * scale,
                height: Layout.blob.height * scale
            ))
            // Заливка — не сплошным цветом станции, а переходом поперёк капли в соседний
            // оттенок (`PromoStationTint.neighbor`; правка пользователя 2026-10-16). Две
            // копии под взаимными масками складываются (`plusLighter`): прозрачность капли
            // та же, меняется только тон.
            let across = Gradient(colors: [.white, .clear])
            let left = point(CGPoint(x: 0, y: Layout.blob.height / 2))
            let right = point(CGPoint(x: Layout.blob.width, y: Layout.blob.height / 2))
            let bounds = Path(CGRect(origin: .zero, size: size))
            for (tone, mask) in [(fill, across), (PromoStationTint.neighbor(of: fill), Gradient(colors: [.clear, .white]))] {
                var half = context
                half.blendMode = .plusLighter
                half.drawLayer { layer in
                    layer.fill(ellipse, with: .linearGradient(
                        VibeBlobFill.gradient(tone),
                        startPoint: point(Layout.fillStart),
                        endPoint: point(Layout.fillEnd)
                    ))
                    layer.blendMode = .destinationIn
                    layer.fill(bounds, with: .linearGradient(mask, startPoint: left, endPoint: right))
                }
            }
            // Обводка вдвое толще, срезанная по самому эллипсу, — внутренняя 1.44
            var rimContext = context
            rimContext.clip(to: ellipse)
            rimContext.stroke(ellipse, with: .linearGradient(
                Gradient(colors: [rim, rim.opacity(0)]),
                startPoint: point(Layout.rimStart),
                endPoint: point(Layout.rimEnd)
            ), lineWidth: Layout.rimWidth * 2 * scale)
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}
