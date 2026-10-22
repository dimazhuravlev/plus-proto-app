import SwiftUI
import UIKit

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
    static let pagesFill = Color.fillEight

    private var scale: CGFloat { coverHeight / Self.referenceHeight }

    /// Блок страниц выглядывает из-за обложки на 2 сверху и на 2 справа (на эталоне).
    /// Справа было 3, как в макете; на большой книге лишний пункт рос до ~2.5 и выступ
    /// читался кривым — правый теперь равен верхнему (правка пользователя 2026-10-04).
    var pagesTop: CGFloat { 2 * scale }
    var pagesRight: CGFloat { pagesTop }
    /// Сколько подложки книга забирает в свою ширину — `pr-[2px]` макета: теперь это
    /// весь правый выступ, в зазор до соседа ничего не уходит.
    var pagesInset: CGFloat { pagesRight }
    var coverRadius: CGFloat { 8 * scale - radiusTrim }
    /// Скругление серой подложки — 10, у обложки 8 (правка пользователя 2026-10-03).
    var pagesRadius: CGFloat { 10 * scale - radiusTrim }
    /// На сколько скругления обложки и подложки меньше общих — поровну у обеих.
    /// Ноль везде, кроме промо «Главной» (`ShowcasePromoLayout.book`).
    var radiusTrim: CGFloat = 0
    /// Скошенный верх корешка у подложки: 4.1 % её ширины по горизонтали, 1.93 вниз.
    /// Бордер обложки (`CoverBorder`). Свой — у рисунков, которые потом ужимаются целиком
    /// (ряд ПП): там толщина задаётся с поправкой на масштаб.
    var borderWidth: CGFloat = CoverBorder.width
    var spineBevel: CGSize { CGSize(width: 0.0406, height: 1.93 * scale) }
    /// Сгиб у корешка (`line` компонента `book card small`, `2440:27634`) — 11.76 % ширины
    /// книги (10 на книге 85, 8.47 на 72): в макете он тянется вместе с ней (`SCALE`).
    func hingeWidth(coverWidth: CGFloat) -> CGFloat {
        frameSize(coverWidth: coverWidth).width * Self.hingeShare
    }

    static let hingeShare: CGFloat = 10 / 85

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

/// Пропорции обложки книги — по самой картинке. Одна логика на все карточки, которым
/// пропорций не дали данные (экран книги, ряд ПП «Главной»): высота у них задана, ширина
/// идёт от обложки (`BookFigureGeometry.coverWidth(aspect:)`), как у остальных книг.
enum BookCoverAspect {
    /// Из кэша — синхронно, на первом кадре. `nil` — картинка ещё не в памяти;
    /// `.some(nil)` — картинки нет вовсе, книга встаёт с пропорциями по умолчанию.
    @MainActor
    static func cached(of source: ArtworkSource) -> CGFloat?? {
        if let url = source.remoteURL {
            return ArtworkLoader.shared.cached(url).map { .some(of($0)) }
        }
        return .some(source.fallbackAsset.flatMap { UIImage(named: $0) }.map(of))
    }

    /// С загрузкой. Не загрузилась — `nil`: книга встанет с пропорциями по умолчанию,
    /// а на обложке будет заглушка `ArtworkImage`.
    static func load(of source: ArtworkSource) async -> CGFloat? {
        if let url = source.remoteURL, let image = await ArtworkLoader.shared.image(for: url) {
            return of(image)
        }
        return await MainActor.run { source.fallbackAsset.flatMap { UIImage(named: $0) }.map(of) }
    }

    static func of(_ image: UIImage) -> CGFloat {
        image.size.width / max(image.size.height, 1)
    }
}

/// Книга целиком. Обложку подставляет вызывающий — у скелетона на её месте только
/// заливка `PlusSkeleton`.
struct BookFigure<Cover: View>: View {
    let geometry: BookFigureGeometry
    let coverWidth: CGFloat
    /// Id книги (`gb-…`) — у начатой на обложке бейдж с прочитанной долей
    /// (`BookProgressBadge`, задача пользователя 2026-10-20). `nil` — бейджа нет
    /// (скелетоны, шапка экрана книги, карточка шеринга).
    var readingID: String? = nil
    @ViewBuilder var cover: Cover

    /// Опционально: в окне поверх всего (шеринг) окружения корня нет.
    @Environment(ActionBarState.self) private var actionBar: ActionBarState?

    private var readingProgress: Double? {
        readingID.flatMap { actionBar?.readingHistory.readingProgress(for: $0) }
    }

    /// Скелетон — книга без обложки (`EmptyView` на её месте). Каждый слой рисунка
    /// у него вполсилы: подложка, заливка обложки, кромки и сгиб ложатся друг на друга,
    /// и книга выходила заметно ярче остальных скелетонов (правка пользователя
    /// 2026-10-04, все размеры).
    private var layerOpacity: Double { Cover.self == EmptyView.self ? 0.5 : 1 }

    var body: some View {
        let pages = BookPagesShape(radius: geometry.pagesRadius, bevel: geometry.spineBevel)
        let frame = geometry.frameSize(coverWidth: coverWidth)

        ZStack(alignment: .topLeading) {
            pages
                .fill(BookFigureGeometry.pagesFill.opacity(layerOpacity))
                // Под полупрозрачной подложкой — размытие фона, как у стеклянных блоков
                // (правка пользователя 2026-10-09).
                .background {
                    BackdropBlurView(radius: PlusMetrics.buttonBlur)
                        .clipShape(pages)
                        .allowsHitTesting(false)
                }
                // Бордер внутрь, как в макете (`back cover`: Fill/Nine 0.67 inside) и как все
                // бордеры проекта: обводка вдвое толще по кромке, срезанная самой формой.
                .overlay {
                    pages
                        .stroke(CoverBorder.color.opacity(layerOpacity), lineWidth: 2 * CoverBorder.width)
                        .clipShape(pages)
                }
                .frame(
                    width: coverWidth + geometry.pagesRight,
                    height: geometry.coverHeight + geometry.pagesTop
                )

            PlusSkeleton.fill.opacity(layerOpacity)
                // Сгиб у корешка рисует сама картинка (`ResolvedArtwork`): проявляется
                // вместе с обложкой, а у скелетона его нет (правка пользователя 2026-10-09).
                .overlay { cover.environment(\.bookHingeWidth, geometry.hingeWidth(coverWidth: coverWidth)) }
                .frame(width: coverWidth, height: geometry.coverHeight)
                .bookCoverShape(
                    radius: geometry.coverRadius,
                    borderWidth: geometry.borderWidth,
                    borderOpacity: layerOpacity
                )
                .overlay(alignment: .topLeading) {
                    if let readingProgress {
                        BookProgressBadge(progress: readingProgress)
                            .padding(BookProgressBadge.inset)
                    }
                }
                .padding(.top, geometry.pagesTop)
        }
        // Кадр книги — вместе с правым выступом подложки (`frameSize`).
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
    }
}

// MARK: - Бейдж прогресса

/// Прочитанная доля на обложке начатой книги — `nameplates` `2880:78062`: белая плашка
/// 18 r6 с полями 4 по бокам и лёгкой тенью, «38%» Text XS Semibold чёрным; стоит
/// в 4 от верхнего левого угла обложки. Размер постоянный у карточек всех размеров:
/// текст не масштабируем.
struct BookProgressBadge: View {
    let progress: Double

    static let inset: CGFloat = 4

    private enum Layout {
        static let height: CGFloat = 18
        static let side: CGFloat = 4
        static let radius: CGFloat = 6
        /// Тень макета — y 1, блюр 4 (в коде вдвое меньше)
        static let shadowRadius: CGFloat = 2
        static let shadowOffset: CGFloat = 1
        static let shadowOpacity: Double = 0.1
    }

    /// Не меньше 1 % и не больше 99 %: начатая и недочитанная.
    private var percent: Int {
        min(max(Int((progress * 100).rounded()), 1), 99)
    }

    var body: some View {
        Text("\(percent)%")
            .plusText(.textXS, .semibold)
            .foregroundStyle(Color.fillInverted)
            .padding(.horizontal, Layout.side)
            .frame(height: Layout.height)
            .background(Color.fillOne, in: RoundedRectangle(cornerRadius: Layout.radius, style: .continuous))
            .shadow(color: .black.opacity(Layout.shadowOpacity), radius: Layout.shadowRadius, y: Layout.shadowOffset)
            .accessibilityLabel("Прочитано \(percent)%")
    }
}

// MARK: - Форма обложки

extension View {
    /// Обложка книги как у всех книг приложения: скруглены только правые углы, слева
    /// корешок; бордер (`CoverBorder`) — сверху, справа и снизу. Без блока страниц —
    /// для мелких обложек вне `BookFigure` (навбар читалки; правка пользователя 2026-10-16).
    func bookCoverShape(
        radius: CGFloat,
        borderWidth: CGFloat = CoverBorder.width,
        borderOpacity: Double = 1
    ) -> some View {
        clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: radius,
            topTrailingRadius: radius,
            style: .continuous
        ))
        .overlay {
            // Контур сам отступает внутрь на полтолщины.
            BookCoverEdge(radius: radius, lineWidth: borderWidth)
                .stroke(CoverBorder.color.opacity(borderOpacity), lineWidth: borderWidth)
                .allowsHitTesting(false)
        }
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
struct BookCoverEdge: Shape {
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

/// Притенённый сгиб у корешка — `line` компонента `book card small` (`2440:27634`):
/// линейный градиент от корешка — прозрачный у кромки, чёрный 16 % на 34.6 % ширины,
/// 8 % на 67.8 %, прозрачный у края полоски. Мягче, чем у объёмной книги витрины:
/// книга почти анфас.
extension EnvironmentValues {
    /// Ширина сгиба у корешка — `BookFigure` ставит её своей обложке, а сгиб рисует сама
    /// загруженная картинка (`ResolvedArtwork`). `nil` — не книга, сгиба нет.
    @Entry var bookHingeWidth: CGFloat? = nil
}

enum BookHingeShade {
    /// Стопы макета: у него градиент идёт от края полоски к корешку (матрица
    /// `[[-1, 0, 1], …]`), здесь — от корешка, доли пересчитаны (1 − t).
    static let gradient = LinearGradient(
        stops: [
            .init(color: .white.opacity(0), location: 0),
            .init(color: .black.opacity(0.16), location: 0.3462),
            .init(color: .black.opacity(0.08), location: 0.6779),
            .init(color: .white.opacity(0), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
