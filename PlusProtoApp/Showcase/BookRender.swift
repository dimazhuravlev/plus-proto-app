import SwiftUI

/// Объёмная книга из плоской обложки — макет `isometric book` (`2004:10746`).
///
/// Слои макета: обложка, повёрнутая на −9.47°; под ней блок страниц — тонкий
/// параллелограмм со ступенчатым серым градиентом (полосы страниц) и тенью; слева
/// боковина корешка в цвете обложки; по левой кромке обложки — притенённый сгиб
/// переплёта; под всем — ореол из той же обложки.
///
/// **Обложка любых пропорций вписывается в бокс макета, а не режется под него**
/// (жалоба пользователя 2026-10-03: обложки нестандартного формата ломали вёрстку).
/// Книга принимает пропорции своей обложки и стоит нижним левым углом — корешком —
/// там же, где книга макета: квадратная обложка даёт книгу ниже, узкая — уже, а кадр
/// карточки не меняется никогда. Толщина рисуется от фактической стороны обложки,
/// поэтому повторяет её размер сама.
struct BookRender: View {
    let cover: ArtworkSource
    let glowOpacity: Double

    /// Лицевая сторона макета — `Технофеодализм 1` в `2004:10749`: бокс, в который
    /// вписывается обложка любых пропорций.
    static let face = CGSize(width: 157.86, height: 226.09)
    static let rotation = Angle.degrees(-9.47)
    /// Толщина книги в осях обложки: блок страниц уходит на 7.87 вниз, боковина
    /// корешка — на 2.63 влево. Снято с векторов `2004:10748` и `2004:10750`: их
    /// кромки сдвинуты от кромок обложки на (−1.3, +8.2) по экрану.
    static let thickness = CGVector(dx: -2.63, dy: 7.87)

    /// Кадр миниатюры — AABB повёрнутой книги вместе с толщиной, в координатах от
    /// центра обложки. В него рендер помещается целиком, значит портлет зум-перехода
    /// ничего у него не срежет.
    static let bounds: CGRect = {
        let halfWidth: CGFloat = face.width / 2
        let halfHeight: CGFloat = face.height / 2
        let cosine = CGFloat(cos(rotation.radians))
        let sine = CGFloat(sin(rotation.radians))
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity
        var minY = CGFloat.infinity, maxY = -CGFloat.infinity
        // Углы обложки и те же углы, сдвинутые на толщину.
        for shift in [CGVector.zero, thickness] {
            for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)] {
                let x: CGFloat = CGFloat(sx) * halfWidth + shift.dx
                let y: CGFloat = CGFloat(sy) * halfHeight + shift.dy
                let rotatedX: CGFloat = x * cosine - y * sine
                let rotatedY: CGFloat = x * sine + y * cosine
                minX = min(minX, rotatedX)
                maxX = max(maxX, rotatedX)
                minY = min(minY, rotatedY)
                maxY = max(maxY, rotatedY)
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }()

    var body: some View {
        ResolvedArtwork(source: cover) { image in
            ZStack {
                // Ореол — та же обложка в блюре. Снаружи миниатюры, а не внутри неё:
                // зум-переход показывает источник портлетом, обрезанным по кадру
                // источника, и ореол внутри срезался бы вместе с ним (жалоба 2026-08-29).
                glow(image)
                    .allowsHitTesting(false)
                    // Вторая копия той же обложки — VoiceOver не должен называть её дважды.
                    .accessibilityHidden(true)

                placed(book(image))
                    .showcaseThumbnail()
            }
        } placeholder: {
            // Пока обложки нет, книги нет вовсе — серая плашка во весь кадр
            // читалась бы прямоугольником на месте наклонной книги.
            Color.clear
        }
        .frame(width: Self.bounds.width, height: Self.bounds.height)
    }

    // MARK: Слои

    /// Ставит повёрнутый бокс обложки в кадр так, чтобы книга с толщиной легла в него
    /// целиком: центр обложки — в точке `−bounds.origin` от левого верхнего угла кадра.
    private func placed(_ content: some View) -> some View {
        content
            .frame(width: Self.face.width, height: Self.face.height, alignment: .bottomLeading)
            .rotationEffect(Self.rotation)
            .offset(x: -Self.bounds.midX, y: -Self.bounds.midY)
            .frame(width: Self.bounds.width, height: Self.bounds.height)
    }

    /// Обложка в своих пропорциях, а под ней — толщина книги, нарисованная от неё же.
    private func book(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .background {
                BookThickness(image: image, thickness: Self.thickness)
            }
            .overlay(alignment: .leading) {
                BookHinge.gradient
                    .frame(width: BookHinge.width)
                    .allowsHitTesting(false)
            }
            .coverBorder(Rectangle())
    }

    /// Ореол макета — `ambilight bg`: обложка в блюре 28.
    ///
    /// Запекается растром (`drawingGroup`) — живой блюр пересчитывался бы на каждом
    /// кадре скролла. Растр режется по кадру вью, поэтому под блюр отведено прозрачное
    /// поле: без него ореол обрывался прямоугольником по невращённой рамке обложки —
    /// это и был тёмный квадрат за книгой.
    private func glow(_ image: Image) -> some View {
        let spill = PlusMetrics.ambilightBlur * 2
        return placed(image.resizable().aspectRatio(contentMode: .fit))
            .padding(spill)
            .blur(radius: PlusMetrics.ambilightBlur)
            .drawingGroup()
            .padding(-spill)
            .opacity(glowOpacity)
    }
}

// MARK: - Толщина

/// Блок страниц и боковина корешка за обложкой. Рисуется в фоне обложки, поэтому
/// знает её фактический размер; холст шире обложки на толщину и поля под тень —
/// рисунок выходит за её кадр.
private struct BookThickness: View {
    let image: Image
    let thickness: CGVector

    /// Поле холста под тень блока страниц.
    private static let margin: CGFloat = 12

    /// Блок страниц `2004:10748`: 18 полос от #E0E0E0 до #777777 — линии страниц.
    /// Градиент идёт поперёк блока и начинается на 1.15pt выше его верха, а тянется
    /// на 14.7 — в самом блоке видны полосы примерно с 2-й по 11-ю, как в макете.
    private static let pageShades: [Double] = [
        0xE0, 0xDA, 0xD4, 0xCD, 0xC7, 0xC1, 0xBB, 0xB5, 0xAF,
        0xA8, 0xA2, 0x9C, 0x96, 0x90, 0x8A, 0x84, 0x7D, 0x77,
    ]
    private static let pageGradientLead: CGFloat = 1.15
    private static let pageGradientLength: CGFloat = 14.7
    /// Тень блока страниц: dy 4, блюр 8, чёрный 20 %.
    private static let pageShadow = (radius: CGFloat(4), y: CGFloat(4), opacity: 0.2)
    /// Боковина корешка — обложка, притемнённая от 72 % яркости сверху до 48 % снизу:
    /// так синий макета (#2BB6E6) уходит в его #2084A4 → #13586F.
    private static let spineShade = (top: 0.28, bottom: 0.52)

    var body: some View {
        let lead = -thickness.dx + Self.margin
        Canvas { context, size in
            let face = CGRect(
                x: lead,
                y: Self.margin,
                width: size.width - lead - Self.margin,
                height: size.height - thickness.dy - 2 * Self.margin
            )
            drawSpine(in: &context, face: face)
            drawPages(in: &context, face: face)
        }
        .padding(EdgeInsets(
            top: -Self.margin,
            leading: -lead,
            bottom: -(thickness.dy + Self.margin),
            trailing: -Self.margin
        ))
        .allowsHitTesting(false)
    }

    /// Боковина — параллелограмм от левой кромки обложки, залитый самой обложкой:
    /// цвет корешка совпадает с любой обложкой без отдельного замера.
    private func drawSpine(in context: inout GraphicsContext, face: CGRect) {
        let e = thickness
        var spine = Path()
        spine.move(to: CGPoint(x: face.minX, y: face.minY))
        spine.addLine(to: CGPoint(x: face.minX + e.dx, y: face.minY + e.dy))
        spine.addLine(to: CGPoint(x: face.minX + e.dx, y: face.maxY + e.dy))
        spine.addLine(to: CGPoint(x: face.minX, y: face.maxY))
        spine.closeSubpath()

        context.drawLayer { layer in
            layer.clip(to: spine)
            // Обложка растянута на ширину боковины — на 2.6pt из 158, глазу не видно.
            layer.draw(image, in: CGRect(
                x: face.minX + e.dx,
                y: face.minY,
                width: face.width - e.dx,
                height: face.height + e.dy
            ))
            layer.fill(spine, with: .linearGradient(
                Gradient(colors: [
                    .black.opacity(Self.spineShade.top),
                    .black.opacity(Self.spineShade.bottom),
                ]),
                startPoint: CGPoint(x: face.minX, y: face.minY),
                endPoint: CGPoint(x: face.minX, y: face.maxY + e.dy)
            ))
        }
    }

    /// Блок страниц — параллелограмм от нижней кромки обложки.
    private func drawPages(in context: inout GraphicsContext, face: CGRect) {
        let e = thickness
        var pages = Path()
        pages.move(to: CGPoint(x: face.minX, y: face.maxY))
        pages.addLine(to: CGPoint(x: face.maxX, y: face.maxY))
        pages.addLine(to: CGPoint(x: face.maxX + e.dx, y: face.maxY + e.dy))
        pages.addLine(to: CGPoint(x: face.minX + e.dx, y: face.maxY + e.dy))
        pages.closeSubpath()

        let count = Double(Self.pageShades.count)
        var stops: [Gradient.Stop] = []
        for (index, shade) in Self.pageShades.enumerated() {
            let color = Color(white: shade / 255)
            stops.append(.init(color: color, location: Double(index) / count))
            stops.append(.init(color: color, location: Double(index + 1) / count))
        }
        let top = face.maxY - Self.pageGradientLead

        context.drawLayer { layer in
            layer.addFilter(.shadow(
                color: .black.opacity(Self.pageShadow.opacity),
                radius: Self.pageShadow.radius,
                x: 0,
                y: Self.pageShadow.y
            ))
            layer.fill(pages, with: .linearGradient(
                Gradient(stops: stops),
                startPoint: CGPoint(x: face.midX, y: top),
                endPoint: CGPoint(x: face.midX, y: top + Self.pageGradientLength)
            ))
        }
    }
}

// MARK: - Сгиб переплёта

/// Притенённый сгиб у корешка — полоска `2004:10751` над левой кромкой обложки:
/// тонкий блик у самой кромки, тень с пиком в 3pt от неё и спад к 10-му пункту.
private enum BookHinge {
    static let width: CGFloat = 10.19
    static let gradient = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.04), location: 0),
            .init(color: .black.opacity(0.08), location: 0.1),
            .init(color: .black.opacity(0.27), location: 0.3),
            .init(color: .black.opacity(0.24), location: 0.4),
            .init(color: .black.opacity(0.17), location: 0.5),
            .init(color: .black.opacity(0.10), location: 0.6),
            .init(color: .black.opacity(0.06), location: 0.7),
            .init(color: .black.opacity(0.035), location: 0.8),
            .init(color: .clear, location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
