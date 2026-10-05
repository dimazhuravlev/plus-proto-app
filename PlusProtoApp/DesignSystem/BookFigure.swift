import SwiftUI

/// Книга в небольшой проекции — макет `2311:25096`: обложка своих пропорций (ширина
/// по ней, обложка не режется), за ней выглядывает блок страниц, у корешка —
/// притенённый сгиб, бордер обложки — только сверху, справа и снизу.
///
/// Один рисунок на все размеры: карточка выдачи поиска (обложка 128), экран книги
/// (324) и карусель «Книги писателя». Числа сняты на эталонной высоте 128 и растут
/// пропорционально высоте обложки — большая книга выглядит ровно так же, как
/// маленькая (задача пользователя 2026-10-04: «кавер как в карточке поиска, только
/// большой»). Хайрлайн бордера от размера не зависит.
struct BookFigureGeometry {
    let coverHeight: CGFloat

    /// Высота обложки, на которой сняты числа макета
    static let referenceHeight: CGFloat = 128
    /// Пропорции, пока своих нет, — постер 2:3.
    static let defaultAspect: CGFloat = 2.0 / 3.0
    /// Крайние пропорции: дальше обложка уже режется — иначе альбомный скан
    /// растянул бы книгу на пол-экрана, а узкий сжал бы её в столбик.
    static let aspectRange: ClosedRange<CGFloat> = 0.55...1.0
    static let pagesFill = Color.white.opacity(0.15)

    private var scale: CGFloat { coverHeight / Self.referenceHeight }

    /// Блок страниц выглядывает из-за обложки на 2 сверху и на 2 справа (на эталоне).
    /// Справа было 3, как в макете; на большой книге лишний пункт рос до ~2.5 и выступ
    /// читался кривым — правый теперь равен верхнему (правка пользователя 2026-10-04).
    var pagesTop: CGFloat { 2 * scale }
    var pagesRight: CGFloat { pagesTop }
    /// Сколько подложки книга забирает в свою ширину — `pr-[2px]` макета: теперь это
    /// весь правый выступ, в зазор до соседа ничего не уходит.
    var pagesInset: CGFloat { pagesRight }
    var coverRadius: CGFloat { 8 * scale }
    /// Скругление серой подложки — 10, у обложки 8 (правка пользователя 2026-10-03).
    var pagesRadius: CGFloat { 10 * scale }
    /// Скошенный верх корешка у подложки: 4.1 % её ширины по горизонтали, 1.93 вниз.
    var spineBevel: CGSize { CGSize(width: 0.0406, height: 1.93 * scale) }
    var hingeWidth: CGFloat { 10 * scale }

    /// Ширина обложки — по её пропорциям в допустимых пределах.
    func coverWidth(aspect: CGFloat?) -> CGFloat {
        let range = Self.aspectRange
        let clamped = min(max(aspect ?? Self.defaultAspect, range.lowerBound), range.upperBound)
        return (coverHeight * clamped).rounded()
    }

    /// Кадр книги: обложка и выступы подложки — сверху и справа.
    func frameSize(coverWidth: CGFloat) -> CGSize {
        CGSize(width: coverWidth + pagesInset, height: coverHeight + pagesTop)
    }

    /// Книга по ширине кадра — для сетки выдачи, где задана колонка, а высота свободна
    /// (макет `2479:24822`). Обратная задача к карусели: там высота обложки дана,
    /// а ширина идёт от пропорций. Кадр = обложка × пропорции + выступ 2 × масштаб,
    /// отсюда высота; ширина обложки — остаток колонки за выступом, кадр ровно `width`.
    static func fitting(width: CGFloat, aspect: CGFloat?) -> (geometry: BookFigureGeometry, coverWidth: CGFloat) {
        let clamped = min(max(aspect ?? defaultAspect, aspectRange.lowerBound), aspectRange.upperBound)
        let height = (width / (clamped + 2 / referenceHeight)).rounded()
        let geometry = BookFigureGeometry(coverHeight: height)
        return (geometry, width - geometry.pagesInset)
    }
}

/// Книга целиком. Обложку подставляет вызывающий — у скелетона на её месте только
/// заливка `PlusSkeleton`.
struct BookFigure<Cover: View>: View {
    let geometry: BookFigureGeometry
    let coverWidth: CGFloat
    @ViewBuilder var cover: Cover

    /// Скелетон — книга без обложки (`EmptyView` на её месте). Каждый слой рисунка
    /// у него вполсилы: подложка, заливка обложки, кромки и сгиб ложатся друг на друга,
    /// и книга выходила заметно ярче остальных скелетонов (правка пользователя
    /// 2026-10-04, все размеры).
    private var layerOpacity: Double { Cover.self == EmptyView.self ? 0.5 : 1 }

    var body: some View {
        let coverShape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: geometry.coverRadius,
            topTrailingRadius: geometry.coverRadius,
            style: .continuous
        )
        let pages = BookPagesShape(radius: geometry.pagesRadius, bevel: geometry.spineBevel)
        let frame = geometry.frameSize(coverWidth: coverWidth)

        ZStack(alignment: .topLeading) {
            pages
                .fill(BookFigureGeometry.pagesFill.opacity(layerOpacity))
                .overlay { pages.stroke(PlusSkeleton.fill.opacity(layerOpacity), lineWidth: PlusMetrics.hairline) }
                .frame(
                    width: coverWidth + geometry.pagesRight,
                    height: geometry.coverHeight + geometry.pagesTop
                )

            PlusSkeleton.fill.opacity(layerOpacity)
                .overlay { cover }
                .frame(width: coverWidth, height: geometry.coverHeight)
                .clipShape(coverShape)
                .overlay {
                    // Бордер обложки (`CoverBorder`) — только сверху, справа и снизу:
                    // слева корешок. Контур сам отступает внутрь на полтолщины.
                    BookCoverEdge(radius: geometry.coverRadius)
                        .stroke(CoverBorder.color.opacity(layerOpacity), lineWidth: CoverBorder.width)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .leading) {
                    BookHingeShade.gradient
                        .frame(width: geometry.hingeWidth)
                        .opacity(layerOpacity)
                        .allowsHitTesting(false)
                }
                .padding(.top, geometry.pagesTop)
        }
        // Кадр книги — вместе с правым выступом подложки (`frameSize`).
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
    }
}

// MARK: - Формы

/// Блок страниц за обложкой — `bg` макета `2311:25096`: правые углы скруглены
/// сильнее обложки, левый верхний скошен — это верх корешка, видный в проекции.
private struct BookPagesShape: Shape {
    let radius: CGFloat
    /// Скос: доля ширины по горизонтали и пункты по вертикали.
    let bevel: CGSize

    func path(in rect: CGRect) -> Path {
        let body = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: radius,
            topTrailingRadius: radius,
            style: .continuous
        ).path(in: rect)
        var corner = Path()
        corner.move(to: CGPoint(x: rect.minX, y: rect.minY))
        corner.addLine(to: CGPoint(x: rect.minX + rect.width * bevel.width, y: rect.minY))
        corner.addLine(to: CGPoint(x: rect.minX, y: rect.minY + bevel.height))
        corner.closeSubpath()
        return body.subtracting(corner)
    }
}

/// Бордер обложки на трёх сторонах — сверху, справа и снизу: слева корешок,
/// и кромки там нет (макет `2311:25096`). Линия внутри кадра, как `border` макета.
private struct BookCoverEdge: Shape {
    let radius: CGFloat
    var lineWidth: CGFloat = CoverBorder.width

    func path(in rect: CGRect) -> Path {
        let inset = lineWidth / 2
        let top = rect.minY + inset
        let bottom = rect.maxY - inset
        let right = rect.maxX - inset
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: top))
        path.addArc(
            tangent1End: CGPoint(x: right, y: top),
            tangent2End: CGPoint(x: right, y: bottom),
            radius: radius - inset
        )
        path.addArc(
            tangent1End: CGPoint(x: right, y: bottom),
            tangent2End: CGPoint(x: rect.minX, y: bottom),
            radius: radius - inset
        )
        path.addLine(to: CGPoint(x: rect.minX, y: bottom))
        return path
    }
}

/// Притенённый сгиб у корешка — полоска `Rectangle 240661877` макета, снятая
/// по пикселям: блик у самой кромки, тень с пиком 15 % в 3/10 ширины от неё, спад
/// к краю полоски. Мягче, чем у объёмной книги витрины: книга почти анфас.
private enum BookHingeShade {
    static let gradient = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.02), location: 0.05),
            .init(color: .white.opacity(0.03), location: 0.15),
            .init(color: .black.opacity(0.11), location: 0.25),
            .init(color: .black.opacity(0.15), location: 0.35),
            .init(color: .black.opacity(0.13), location: 0.45),
            .init(color: .black.opacity(0.11), location: 0.55),
            .init(color: .black.opacity(0.08), location: 0.65),
            .init(color: .black.opacity(0.06), location: 0.75),
            .init(color: .black.opacity(0.035), location: 0.85),
            .init(color: .clear, location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
