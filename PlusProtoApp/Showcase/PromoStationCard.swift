import SwiftUI
import UIKit

/// Числа карточки станции «Моей волны» в промо «Главной» — макет `2688:26198` (задача 65).
/// Кадр 208×249 на 402; вся геометрия умножается на `ShowcasePromoLayout.scale`, шрифты — нет.
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
}

/// Карточка станции в промо «Главной»: капля цвета станции, над ней иллюстрация агента,
/// в капле — «Моя волна» и название станции. Пару ✕/✓ кладёт слайдер — оверлеем
/// на `PromoStationLayout.pairOrigin` (`ShowcasePromo.card`); подписи под карточкой нет.
///
/// Кадр — распорка 208×249: кнопке и касаниям — ровно он, капля уходит за него фоном.
/// Смена по ✕ — на каждом слое по отдельности (`showcaseSwappable`), масштаб — от его центра.
struct PromoStationCard: View {
    let title: String
    let station: VibePromoStation

    private typealias Layout = PromoStationLayout

    var body: some View {
        let scale = ShowcasePromoLayout.scale
        Color.clear
            .frame(width: Layout.frame.width * scale, height: Layout.frame.height * scale)
            .background(alignment: .topLeading) {
                PromoStationPetal(station: station)
            }
            .overlay(alignment: .topLeading) {
                Image(station.asset)
                    .resizable()
                    .frame(width: Layout.art.width * scale, height: Layout.art.height * scale)
                    .frame(width: Layout.artBox * scale, height: Layout.artBox * scale)
                    .showcaseSwappable()
                    .offset(x: Layout.artOrigin.x * scale, y: Layout.artOrigin.y * scale)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topLeading) {
                VStack(spacing: Layout.textGap * scale) {
                    Text(title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)
                    Text(station.name)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(Layout.nameLines)
                }
                .multilineTextAlignment(.center)
                .frame(width: Layout.textWidth * scale)
                .showcaseSwappable()
                .offset(x: Layout.textLeading * scale, y: Layout.textTop * scale)
            }
            .contentShape(.rect)
    }
}

/// Капля станции — растр, посчитанный один раз на цвет: живой прогрессивный блюр
/// пересчитывался бы у каждой копии круга. В растре капля не повёрнута — поворот и место
/// задаёт трансформ вью, он ничего не стоит.
struct PromoStationPetal: View {
    let station: VibePromoStation

    private typealias Layout = PromoStationLayout

    var body: some View {
        let scale = ShowcasePromoLayout.scale
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
    static func prewarm(_ blocks: [ShowcaseBlock]) {
        for case .vibe(let vibe) in blocks {
            guard let station = vibe.station else { continue }
            _ = PromoPetalCache.image(for: station)
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
            scale: ShowcasePromoLayout.scale
        ))
        renderer.scale = displayScale
        guard let image = renderer.uiImage else { return nil }
        // Растр готов к показу сразу, а не на первой отрисовке.
        let prepared = image.preparingForDisplay() ?? image
        images[key] = prepared
        return prepared
    }

    /// Масштаб экрана — со сцены; без неё (самый ранний кадр) — 3, как у iPhone проекта.
    private static var displayScale: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.traitCollection.displayScale ?? 3
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
        return Canvas { [fill, rim, scale] context, _ in
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
            context.fill(ellipse, with: .linearGradient(
                VibeBlobFill.gradient(fill),
                startPoint: point(Layout.fillStart),
                endPoint: point(Layout.fillEnd)
            ))
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
