import SwiftUI
import UIKit

/// Карточка книги — `card / book` ДС «🫟 Платформа · Мобайл» (`8423:59895`, задача
/// пользователя 2026-10-30): обложка своих пропорций без блока страниц, скруглены только
/// правые углы (слева корешок), бордер Fill/Nine 0.67 внутрь по всему контуру, поверх
/// картинки — белый 8 % «разницей», у левой кромки — притенённый корешок.
///
/// Один рисунок на все места — карусели, списки, промо витрин, экран книги, выдача:
/// важна конструкция, а не ступени ДС (слова пользователя). Высота — от места («как
/// у постера того же размера»), ширина — от пропорций обложки. Скругление и корешок
/// сняты на трёх ступенях ДС — xsmall 114 (8 и 12), medium 159 (12 и 16), large 192
/// (12 и 20); между ними — по прямой, за крайними — пропорционально высоте: большая
/// книга выглядит так же, как маленькая. Хайрлайн бордера от размера не зависит.
struct BookFigureGeometry {
    let coverHeight: CGFloat

    /// Пропорции, пока своих нет, — 2:3, как у постера.
    static let defaultAspect: CGFloat = 2.0 / 3.0
    /// Пропорции книг ДС — от 3:5 до 3:4: дальше обложка режется, иначе альбомный скан
    /// растянул бы книгу, а узкий сжал бы её в столбик.
    static let aspectRange: ClosedRange<CGFloat> = (3.0 / 5.0)...(3.0 / 4.0)

    /// Ступени ДС: высота → скругление правых углов и ширина корешка.
    private static let steps: [(height: CGFloat, radius: CGFloat, spine: CGFloat)] = [
        (114, 8, 12),
        (159, 12, 16),
        (192, 12, 20),
    ]

    var coverRadius: CGFloat { Self.stepped(coverHeight, \.radius) - radiusTrim }
    /// Корешок — полоса притенения у левой кромки (`spine`).
    var spineWidth: CGFloat { Self.stepped(coverHeight, \.spine) }
    /// На сколько скругление меньше общего — где карточка подгоняется к соседям другого
    /// вида (промо «Главной», `ShowcasePromoLayout.book`). Ноль везде, кроме них.
    var radiusTrim: CGFloat = 0
    /// Бордер обложки (`CoverBorder`). Свой — у рисунков, которые потом ужимаются целиком
    /// (ряд ПП): там толщина задаётся с поправкой на масштаб.
    var borderWidth: CGFloat = CoverBorder.width

    /// Та же книга со скруглением своего макета — чип бара, навбар читалки: там число
    /// задано местом, а не ступенью ДС.
    func cornerRadius(_ radius: CGFloat) -> BookFigureGeometry {
        var geometry = self
        geometry.radiusTrim = Self.stepped(coverHeight, \.radius) - radius
        return geometry
    }

    /// Ширина обложки — по её пропорциям в допустимых пределах.
    func coverWidth(aspect: CGFloat?) -> CGFloat {
        (coverHeight * Self.clamped(aspect)).rounded()
    }

    /// Кадр книги — ровно обложка.
    func frameSize(coverWidth: CGFloat) -> CGSize {
        CGSize(width: coverWidth, height: coverHeight)
    }

    /// Книга по ширине кадра — для сетки выдачи, где задана колонка, а высота свободна:
    /// обратная задача к карусели, где высота дана, а ширина идёт от пропорций.
    static func fitting(width: CGFloat, aspect: CGFloat?) -> (geometry: BookFigureGeometry, coverWidth: CGFloat) {
        let height = (width / clamped(aspect)).rounded()
        return (BookFigureGeometry(coverHeight: height), width)
    }

    static func clamped(_ aspect: CGFloat?) -> CGFloat {
        min(max(aspect ?? defaultAspect, aspectRange.lowerBound), aspectRange.upperBound)
    }

    /// Величина ступени на любой высоте: между ступенями — по прямой, за крайними —
    /// пропорционально высоте.
    private static func stepped(_ height: CGFloat, _ value: KeyPath<(height: CGFloat, radius: CGFloat, spine: CGFloat), CGFloat>) -> CGFloat {
        guard let first = steps.first, let last = steps.last else { return 0 }
        if height <= first.height { return first[keyPath: value] * height / first.height }
        if height >= last.height { return last[keyPath: value] * height / last.height }
        for (lower, upper) in zip(steps, steps.dropFirst()) where height <= upper.height {
            let t = (height - lower.height) / (upper.height - lower.height)
            return lower[keyPath: value] + (upper[keyPath: value] - lower[keyPath: value]) * t
        }
        return last[keyPath: value]
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
/// заливка `PlusSkeleton` в форме книги. Бордер, корешок и «разницу» рисует сама
/// загруженная картинка (`ResolvedArtwork`): они проявляются вместе с ней, а у скелетона
/// их нет (правки пользователя 2026-10-09 и 2026-10-30).
struct BookFigure<Cover: View>: View {
    let geometry: BookFigureGeometry
    let coverWidth: CGFloat
    @ViewBuilder var cover: Cover

    var body: some View {
        let decor = BookCoverDecor(
            radius: geometry.coverRadius,
            spineWidth: geometry.spineWidth,
            borderWidth: geometry.borderWidth
        )
        PlusSkeleton.fill
            .overlay { cover.environment(\.bookCoverDecor, decor) }
            .frame(width: coverWidth, height: geometry.coverHeight)
            .clipShape(BookCoverShape(radius: geometry.coverRadius))
    }
}

// MARK: - Аудиокнига

/// Аудиокнига среди книг — вариант `card / book` (макет `18352:41986` файла «ЯПС · Mobile ·
/// Current State», 2026-10-31): квадрат высотой книги ряда, скруглены все четыре угла — тем же
/// радиусом, что правые углы книги этой высоты (на 114 — 8), бордер Fill/Nine 0.67 внутрь.
/// Ни корешка, ни тона «разницей»: это не книга в проекции, а квадратная обложка. Бордер
/// встаёт вместе с картинкой (`coverBorder`), у скелетона его нет.
struct AudiobookFigure<Cover: View>: View {
    let geometry: BookFigureGeometry
    @ViewBuilder var cover: Cover

    /// Сторона квадрата — высота книги ряда.
    var side: CGFloat { geometry.coverHeight }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: geometry.coverRadius, style: .continuous)
        PlusSkeleton.fill
            .overlay { cover }
            .frame(width: side, height: side)
            .clipShape(shape)
            .coverBorder(shape)
    }
}

// MARK: - Форма обложки

/// Форма обложки книги: правые углы скруглены (сглаживание 60 % — `.continuous`),
/// левые прямые.
struct BookCoverShape: InsettableShape {
    let radius: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: max(0, radius - inset),
            topTrailingRadius: max(0, radius - inset),
            style: .continuous
        )
        .path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> BookCoverShape {
        BookCoverShape(radius: radius, inset: inset + amount)
    }
}

// MARK: - Корешок

/// Что загруженная обложка книги рисует поверх себя: бордер по контуру, тон и корешок.
struct BookCoverDecor {
    let radius: CGFloat
    let spineWidth: CGFloat
    let borderWidth: CGFloat
}

extension EnvironmentValues {
    /// Отделка обложки — `BookFigure` ставит её своей обложке, а рисует сама загруженная
    /// картинка (`ResolvedArtwork`). `nil` — не книга.
    @Entry var bookCoverDecor: BookCoverDecor? = nil
}

/// Корешок и тон обложки — `spine` и заливки `cover` компонента `card / book`.
enum BookSpine {
    /// Притенение у корешка: прозрачное у кромки, чёрный 16 % на 34.6 % ширины полосы,
    /// 8 % на 70 %, прозрачное у её края (градиент ноды идёт справа налево, доли
    /// пересчитаны от корешка: 1 − t).
    static let gradient = LinearGradient(
        stops: [
            .init(color: .black.opacity(0), location: 0),
            .init(color: .black.opacity(0.16), location: 1 - 0.6538),
            .init(color: .black.opacity(0.08), location: 1 - 0.3),
            .init(color: .black.opacity(0), location: 1),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    /// Вторая заливка обложки — белый 8 % «разницей»: гасит самые светлые и тёмные
    /// места картинки, и обложки разной яркости ложатся в один тон.
    static let toneOpacity: Double = 0.08
}
