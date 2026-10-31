import SwiftUI

// MARK: - Ступени и геометрия

/// Ступень карточки музыки — ДС «🫟 Mobile · Library», Cards · Music (`589:34087`): альбом
/// xSmall 80 · Small 109 · Medium 168 · Large 227, плейлист и исполнитель — те же ступени.
/// От ступени — типографика подписи и скругление обложки. Ширину задаёт карусель
/// (`CarouselFit`): «меняйте размер карусели, а не постера», — ступень от ширины не зависит.
enum MusicCardSize {
    /// Подпись Text S 13/16 — название до двух строк или название и описание.
    case xsmall, small
    /// Подпись Text M 15/20 — название и описание.
    case medium
    /// Обложка со скруглением 18, под ней аватар исполнителя 40 и две строки Text M.
    case large

    var text: PlusTextSize {
        switch self {
        case .xsmall, .small: .textS
        case .medium, .large: .textM
        }
    }

    var coverRadius: CGFloat {
        self == .large ? MusicCardLayout.largeRadius : MusicCardLayout.radius
    }
}

/// Обложка карточки: квадрат (альбом, плейлист, трек) или круг (исполнитель).
enum MusicCardShape: Hashable {
    case square, circle
}

/// Числа карточки — с инстансов ДС и экрана «Для вас» (`68:15807`).
enum MusicCardLayout {
    static let radius: CGFloat = 12
    static let largeRadius: CGFloat = 18
    /// Обложка → подпись
    static let textGap: CGFloat = 6
    /// Поле подписи справа у квадратных карточек (`pr-[8px]`)
    static let textTrailing: CGFloat = 8
    /// Название ↔ описание у Text M (`mb-[-2px]`)
    static let stackGap: CGFloat = -2
    static let avatar: CGFloat = 40
    static let avatarGap: CGFloat = 8
    static let badgeGap: CGFloat = 4

    /// Высота подписи — у карусели высота явная (`ServiceCarousel`), и считается она отсюда:
    /// у Text S — две строки (название в две или название + описание), у Text M — название
    /// и описание с наездом −2, у Large с аватаром — по аватару. У круга — имя до двух
    /// строк без наезда.
    static func captionHeight(_ size: MusicCardSize, shape: MusicCardShape = .square, showsAvatar: Bool = false) -> CGFloat {
        let line = size.text.lineHeight
        if shape == .circle { return 2 * line }
        switch size {
        case .xsmall, .small:
            return 2 * line
        case .medium:
            return 2 * line + stackGap
        case .large:
            return showsAvatar ? max(avatar, 2 * line + stackGap) : 2 * line + stackGap
        }
    }

    /// Карточка целиком — обложка, зазор и подпись.
    static func height(_ size: MusicCardSize, width: CGFloat, shape: MusicCardShape = .square, showsAvatar: Bool = false) -> CGFloat {
        width + textGap + captionHeight(size, shape: shape, showsAvatar: showsAvatar)
    }
}

/// Карусели музыки: «N целых, следующая торчит на 24» на любой ширине (правило 4 CLAUDE.md,
/// задача пользователя 2026-10-17). На 375 — ровно макетные 104 и 159.
enum MusicCarouselFit {
    static let side: CGFloat = 16
    static let gap: CGFloat = 8
    static let peek: CGFloat = 24

    /// Три целые и край четвёртой — `carousel / Music / small cards`.
    static let small = CarouselFit(designCard: designCard(whole: 3), whole: 3, side: side, gap: gap)
    /// Две целые и край третьей — `carousel / Music / medium cards`.
    static let medium = CarouselFit(designCard: designCard(whole: 2), whole: 2, side: side, gap: gap)
    /// Полторы карточки — `carousel / Music / large cards` («Новые релизы», «Альбомы»
    /// исполнителя): на 375 карточка 227, край следующей 124 — тот же на любой ширине.
    static let large = CarouselFit(designCard: 254, whole: 1, side: side, gap: gap)
    /// Ряд внутри блока «Похоже на»: поля блока и ряда — 16 + 16, три целые и край
    /// четвёртой 24 до кромки блока (40 до кромки экрана); на 375 — 93.
    static let block = CarouselFit(designCard: 102, whole: 3, side: 2 * side, gap: gap)

    private static func designCard(whole: Int) -> CGFloat {
        (PlusMetrics.designWidth - side - peek - CGFloat(whole) * gap) / CGFloat(whole)
    }
}

// MARK: - Карточка

/// Карточка музыки — одна на всё приложение (задача пользователя 2026-10-17: «максимально
/// shared components»): «Для вас» на табе Музыки, «Альбомы» и «Похожие» экрана исполнителя,
/// «Другие альбомы» альбома. Только вёрстка: нажатие и переход — у вызывающего
/// (`Button` с `PressScaleButtonStyle(.cardScale)`), здесь — источник зума на обложке.
struct MusicCard: View {
    let size: MusicCardSize
    let width: CGFloat
    var shape: MusicCardShape = .square
    /// `nil` — обложки нет: стоит заливка скелетона.
    let cover: ArtworkSource?
    let title: String
    var subtitle: String? = nil
    /// Аватар исполнителя под обложкой — только у Large (`card / text`); `nil` — без него
    /// («Альбомы» на экране самого исполнителя).
    var avatar: ArtworkSource? = nil
    var isExplicit = false
    /// Экран, который открывает карточка, — источник зум-перехода (только обложка:
    /// портлет перехода режется по её кадру).
    var zoomRoute: EntityRoute? = nil

    @Environment(\.stackZoomNamespace) private var zoom

    var body: some View {
        VStack(alignment: shape == .circle ? .center : .leading, spacing: MusicCardLayout.textGap) {
            zoomSource(coverView)
            // Подпись уходит вместе с обложкой, пока открыт экран карточки.
            caption
                .zoomSourceCaption(zoom != nil ? zoomRoute : nil)
        }
        .frame(width: width, alignment: shape == .circle ? .center : .leading)
        .contentShape(.rect)
    }

    private var clip: MusicCoverShape {
        MusicCoverShape(shape: shape, radius: size.coverRadius)
    }

    private var coverView: some View {
        PlusSkeleton.fill
            .frame(width: width, height: width)
            .overlay {
                if let cover {
                    SkeletonArtwork(source: cover)
                }
            }
            .clipShape(clip)
            .coverArtworkMissing(cover == nil)
            .coverBorder(clip)
    }

    @ViewBuilder
    private func zoomSource(_ content: some View) -> some View {
        if let zoom, let zoomRoute {
            content.matchedTransitionSource(id: zoomRoute, in: zoom)
        } else {
            content
        }
    }

    @ViewBuilder
    private var caption: some View {
        switch (shape, size) {
        case (.circle, _):
            Text(title)
                .plusText(size.text, .medium)
                .foregroundStyle(Color.fillOne)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        case (.square, .large):
            HStack(spacing: MusicCardLayout.avatarGap) {
                if let avatar {
                    PlusSkeleton.fill
                        .frame(width: MusicCardLayout.avatar, height: MusicCardLayout.avatar)
                        .overlay { SkeletonArtwork(source: avatar) }
                        .clipShape(Circle())
                        .coverBorder(Circle())
                }
                titles(titleLines: 1)
            }
            .padding(.trailing, MusicCardLayout.textTrailing)
        case (.square, _):
            titles(titleLines: subtitle == nil && size.text == .textS ? 2 : 1)
                .padding(.trailing, MusicCardLayout.textTrailing)
        }
    }

    private func titles(titleLines: Int) -> some View {
        HStack(alignment: .top, spacing: MusicCardLayout.badgeGap) {
            VStack(alignment: .leading, spacing: size.text == .textM ? MusicCardLayout.stackGap : 0) {
                Text(title)
                    .plusText(size.text, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(titleLines)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .plusText(size.text, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            if isExplicit {
                Spacer(minLength: 0)
                EntityExplicitBadge()
                    .padding(.top, 1)
            }
        }
    }
}

/// Скелетон карточки музыки — тот же габарит: обложка и полосы на месте строк подписи.
struct MusicCardSkeleton: View {
    let size: MusicCardSize
    let width: CGFloat
    var shape: MusicCardShape = .square
    var showsAvatar = false

    var body: some View {
        VStack(alignment: shape == .circle ? .center : .leading, spacing: MusicCardLayout.textGap) {
            MusicCoverShape(shape: shape, radius: size.coverRadius)
                .plusSkeleton()
                .frame(width: width, height: width)
            HStack(spacing: MusicCardLayout.avatarGap) {
                if showsAvatar {
                    Circle()
                        .fill(PlusSkeleton.fill)
                        .frame(width: MusicCardLayout.avatar, height: MusicCardLayout.avatar)
                }
                VStack(alignment: shape == .circle ? .center : .leading, spacing: 0) {
                    bar(width * (shape == .circle ? 0.6 : 0.7))
                    if shape == .square {
                        bar(width * 0.4)
                    }
                }
            }
        }
        .frame(width: width, alignment: shape == .circle ? .center : .leading)
        .accessibilityHidden(true)
    }

    private func bar(_ length: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: PlusSkeleton.textRadius, style: .continuous)
            .fill(PlusSkeleton.fill)
            .frame(width: length, height: EntitySectionLayout.skeletonBar)
            .frame(height: size.text.lineHeight)
    }
}

/// Контур обложки: круг или скруглённый квадрат — одна форма на клип, бордер и скелетон.
struct MusicCoverShape: InsettableShape {
    let shape: MusicCardShape
    let radius: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: inset, dy: inset)
        switch shape {
        case .circle:
            return Circle().path(in: frame)
        case .square:
            return RoundedRectangle(cornerRadius: max(radius - inset, 0), style: .continuous).path(in: frame)
        }
    }

    func inset(by amount: CGFloat) -> MusicCoverShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}
