import SwiftUI

/// Общие секции экранов сущностей — альбома, книги и персоны: заголовок секции,
/// карточки каруселей и строка трека. Числа сняты с экрана альбома (`2079:11226`)
/// и полной выдачи поиска — макет экрана персоны (`2455:32136`) условный, и на нём
/// стоят ровно эти компоненты (задача пользователя 2026-10-04).
enum EntityMotion {
    /// Скелетоны сменяются контентом за 300 мс — кроссфейд на месте, и раскладка
    /// под ним доезжает той же кривой (правило 2026-10-04, экран книги).
    static let reveal: Animation = .easeInOut(duration: 0.3)
}

enum EntitySectionLayout {
    static let side: CGFloat = EntityCoverLayout.side
    static let sectionPad: CGFloat = 8
    static let headerTop: CGFloat = 16
    static let headerBottom: CGFloat = 12
    /// Строка заголовка — 28, как у заголовков выдачи (Headline M при 100 %)
    static let headerLine: CGFloat = 28
    static let titleGap: CGFloat = 2
    static let chevronBox: CGFloat = 20
    static let cardGap: CGFloat = 8
    /// Карточка альбома — 159 (`2079:11242`)
    static let albumCardWidth: CGFloat = 159
    static let cardTextGap: CGFloat = 6
    static let cardTextTrailing: CGFloat = 8
    static let badgeBox: CGFloat = 16
    static let badgeGap: CGFloat = 4
    /// Отрицательный зазор двухстрочного текстового лейбла (`mb-[-2px]` в макете)
    static let textStackGap: CGFloat = -2
    /// Карточка исполнителя — круг 109, ширина колонки карусели выдачи (`regular`)
    static let personCardWidth: CGFloat = 109
    /// Скелетоны — полосы 12 по центрам строк Text M
    static let skeletonBar: CGFloat = 12
    static let skeletonHeaderWidth: CGFloat = 140
    static let skeletonHeaderBar: CGFloat = 16
}

/// Заголовок секции — `header / static`: Headline M и шеврон сразу за текстом.
/// Полного списка за ним в прототипе нет — заголовок не нажимается, как «Другие
/// альбомы». У плоских списков (фильмы режиссёра, книги писателя — список и есть
/// весь раздел) шеврона нет: вести некуда.
struct EntitySectionHeader: View {
    let title: String
    var showsChevron = true

    var body: some View {
        HStack(spacing: EntitySectionLayout.titleGap) {
            Text(title)
                .plusHeadline(.m)
                .foregroundStyle(Color.fillOne)

            if showsChevron {
                // Правый шеврон — отзеркаленный `icon / dropleft`: своего ассета нет.
                Image("iconDropleft")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: EntitySectionLayout.chevronBox, height: EntitySectionLayout.chevronBox)
                    .scaleEffect(x: -1)
                    .foregroundStyle(Color.fillSubtitle)
                    .offset(y: PlusMetrics.headerChevronDrop)
            }
        }
        .frame(height: EntitySectionLayout.headerLine)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, EntitySectionLayout.headerTop)
        .padding(.bottom, EntitySectionLayout.headerBottom)
        .padding(.horizontal, EntitySectionLayout.side)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Скелетон заголовка секции — полоса в строке 28 с теми же полями.
struct EntitySectionHeaderSkeleton: View {
    var body: some View {
        Rectangle()
            .fill(PlusSkeleton.fill)
            .frame(width: EntitySectionLayout.skeletonHeaderWidth, height: EntitySectionLayout.skeletonHeaderBar)
            .frame(height: EntitySectionLayout.headerLine)
            .padding(.top, EntitySectionLayout.headerTop)
            .padding(.bottom, EntitySectionLayout.headerBottom)
            .padding(.horizontal, EntitySectionLayout.side)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }
}

/// Карточка альбома в карусели — `2079:11242`: квадратная обложка 159, название
/// в строку, под ним год, бейдж explicit справа.
struct EntityAlbumCard: View {
    let cover: ArtworkSource?
    let title: String
    let detail: String?
    var isExplicit = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous)
        VStack(alignment: .leading, spacing: EntitySectionLayout.cardTextGap) {
            PlusSkeleton.fill
                .frame(width: EntitySectionLayout.albumCardWidth, height: EntitySectionLayout.albumCardWidth)
                .overlay {
                    if let cover {
                        ArtworkImage(source: cover).scaledToFill()
                    }
                }
                .clipShape(shape)
                .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }

            HStack(alignment: .top, spacing: EntitySectionLayout.badgeGap) {
                VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                    Text(title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)

                    if let detail {
                        Text(detail)
                            .plusText(.textM, .medium)
                            .foregroundStyle(Color.fillSubtitle)
                    }
                }

                if isExplicit {
                    Spacer(minLength: 0)
                    EntityExplicitBadge()
                        .padding(.top, 1)
                }
            }
            .padding(.trailing, EntitySectionLayout.cardTextTrailing)
        }
        .frame(width: EntitySectionLayout.albumCardWidth, alignment: .leading)
        .contentShape(.rect)
    }
}

/// Скелетон карточки альбома — того же габарита.
struct EntityAlbumCardSkeleton: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous)
        VStack(alignment: .leading, spacing: EntitySectionLayout.cardTextGap) {
            shape
                .plusSkeleton()
                .frame(width: EntitySectionLayout.albumCardWidth, height: EntitySectionLayout.albumCardWidth)
            EntitySkeletonLines(widths: [EntitySectionLayout.albumCardWidth * 0.7, EntitySectionLayout.albumCardWidth * 0.3])
        }
        .frame(width: EntitySectionLayout.albumCardWidth, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// Карточка исполнителя — круг 109 и имя по центру (как исполнитель в карусели
/// выдачи, только колонки `regular`).
struct EntityPersonCard: View {
    let photo: ArtworkSource?
    let name: String

    var body: some View {
        VStack(spacing: EntitySectionLayout.cardTextGap) {
            PlusSkeleton.fill
                .frame(width: EntitySectionLayout.personCardWidth, height: EntitySectionLayout.personCardWidth)
                .overlay {
                    if let photo {
                        ArtworkImage(source: photo).scaledToFill()
                    }
                }
                .clipShape(Circle())

            Text(name)
                .plusText(.textS, .medium)
                .foregroundStyle(Color.fillOne)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: EntitySectionLayout.personCardWidth)
        .contentShape(.rect)
    }
}

/// Скелетон карточки исполнителя.
struct EntityPersonCardSkeleton: View {
    var body: some View {
        VStack(spacing: EntitySectionLayout.cardTextGap) {
            Circle()
                .fill(PlusSkeleton.fill)
                .frame(width: EntitySectionLayout.personCardWidth, height: EntitySectionLayout.personCardWidth)
            Rectangle()
                .fill(PlusSkeleton.fill)
                .frame(width: EntitySectionLayout.personCardWidth * 0.6, height: EntitySectionLayout.skeletonBar)
                .frame(height: PlusTextSize.textS.lineHeight)
        }
        .frame(width: EntitySectionLayout.personCardWidth)
        .accessibilityHidden(true)
    }
}

/// Строка трека с обложкой — «Популярные треки» исполнителя (`opened playlist`
/// макета): обложка 48, название с бейджем explicit, исполнитель, «ещё».
/// Тап по строке включает трек — как в треклисте альбома.
struct EntityTrackRow: View {
    let cover: ArtworkSource?
    let title: String
    let artist: String
    var isExplicit = false
    /// Разделитель под строкой — между строками колонки, у последней его нет.
    var showsDivider = true

    static let height: CGFloat = 64
    static let coverSize: CGFloat = 48

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        HStack(spacing: 12) {
            PlusSkeleton.fill
                .frame(width: Self.coverSize, height: Self.coverSize)
                .overlay {
                    if let cover {
                        ArtworkImage(source: cover).scaledToFill()
                    }
                }
                .clipShape(shape)
                .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }

            VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                HStack(spacing: EntitySectionLayout.badgeGap) {
                    Text(title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)
                    if isExplicit {
                        EntityExplicitBadge()
                    }
                }
                Text(artist)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Меню трека в прототипе не спроектировано — кнопка только откликается.
            Button {} label: {
                Image("iconMore")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    // Белый 60 % из макета, как в треклисте альбома
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .frame(height: Self.height)
        .overlay(alignment: .bottom) { if showsDivider { divider } }
        .contentShape(.rect)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.fillNine)
            .frame(height: PlusMetrics.hairline)
    }
}

/// Скелетон строки трека.
struct EntityTrackRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .plusSkeleton()
                .frame(width: EntityTrackRow.coverSize, height: EntityTrackRow.coverSize)
            EntitySkeletonLines(widths: [150, 90])
            Spacer(minLength: 0)
        }
        .frame(height: EntityTrackRow.height)
        .accessibilityHidden(true)
    }
}

/// Полосы скелетона на месте строк Text M — по центрам строк.
struct EntitySkeletonLines: View {
    let widths: [CGFloat]

    var body: some View {
        let inset = (PlusTextSize.textM.lineHeight - EntitySectionLayout.skeletonBar) / 2
        VStack(alignment: .leading, spacing: 2 * inset) {
            ForEach(widths.indices, id: \.self) { index in
                Rectangle()
                    .fill(PlusSkeleton.fill)
                    .frame(width: widths[index], height: EntitySectionLayout.skeletonBar)
            }
        }
        .padding(.vertical, inset)
    }
}

/// Бейдж explicit — белый 30 % из макета, тот же в треке и в карточке карусели.
struct EntityExplicitBadge: View {
    var body: some View {
        Image("iconExplicit")
            .renderingMode(.template)
            .resizable()
            .frame(width: EntitySectionLayout.badgeBox, height: EntitySectionLayout.badgeBox)
            .foregroundStyle(Color.white.opacity(0.3))
    }
}
