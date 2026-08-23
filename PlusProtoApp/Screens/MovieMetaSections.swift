import SwiftUI

// MARK: - Актёры

/// `2101:22652` — 393×287.5: шапка 52 + карусель 219.5 (`padding-x 16`, gap 8).
/// Карточка 109 шириной: фото 2:3 + gap 8 + двухстрочная подпись.
///
/// В макете подпись всегда двухстрочная (имя / роль), у нас роль приходит не у всех
/// персон — карточка без роли остаётся с одной строкой, а высоту держит контейнер.
struct MovieCastSection: View {
    let cast: [MovieCastMember]

    private enum Layout {
        static let cardWidth: CGFloat = 109
        static let photoAspect: CGFloat = 2.0 / 3.0
        static let gap: CGFloat = 8
        static let captionGap: CGFloat = 8
        /// Две строки по 16 + зазор: карточки без роли не должны укорачивать ряд
        static let captionHeight: CGFloat = 36
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MovieSectionHeader(title: "Актёры")

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Layout.gap) {
                    ForEach(cast) { person in
                        card(person)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, MovieLayout.sectionSide, for: .scrollContent)
        }
    }

    private func card(_ person: MovieCastMember) -> some View {
        VStack(alignment: .leading, spacing: Layout.captionGap) {
            photo(person)

            VStack(alignment: .leading, spacing: 0) {
                Text(person.name)
                    .plusMovieCaption()
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)

                if let role = person.role, !role.isEmpty {
                    Text(role)
                        .plusMovieCaption()
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .frame(height: Layout.captionHeight, alignment: .top)
        }
        .frame(width: Layout.cardWidth, alignment: .leading)
    }

    @ViewBuilder
    private func photo(_ person: MovieCastMember) -> some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous)

        Color.buttonsSecondary
            .frame(width: Layout.cardWidth)
            .frame(height: Layout.cardWidth / Layout.photoAspect)
            .overlay {
                if let photo = person.photo {
                    // Без бандленного фолбэка: чужое лицо на месте актёра — ложь о контенте.
                    ArtworkImage(source: .remote(photo)).scaledToFill()
                }
            }
            .clipShape(shape)
    }
}

// MARK: - Похожее

/// `2104:22862` «You Might Also Like» — сетка 3×N: постер 2:3, подпись 18pt.
/// Ширина карточки считается от ширины холста прототипа (402), а не от замера вью:
/// читать размер вью, от которого зависит её же раскладка, запрещено (DECISIONS).
struct MovieSimilarSection: View {
    let titles: [MovieSimilarTitle]

    private enum Layout {
        static let columns = 3
        static let columnGap: CGFloat = 6
        static let rowGap: CGFloat = 8
        static let posterAspect: CGFloat = 2.0 / 3.0
        static let captionGap: CGFloat = 6
        /// Две строки подписи по 18: у части тайтлов название в одну строку, и без
        /// фиксированной высоты годы в ряду встают на разной высоте.
        static let titleHeight: CGFloat = 36

        static var cardWidth: CGFloat {
            let available = PlusMetrics.designWidth - MovieLayout.sectionSide * 2
            return (available - columnGap * CGFloat(columns - 1)) / CGFloat(columns)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MovieSectionHeader(title: "Похожее")

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(Layout.cardWidth), spacing: Layout.columnGap, alignment: .top),
                    count: Layout.columns
                ),
                alignment: .leading,
                spacing: Layout.rowGap
            ) {
                ForEach(titles) { title in
                    card(title)
                }
            }
            .padding(.horizontal, MovieLayout.sectionSide)
        }
    }

    private func card(_ title: MovieSimilarTitle) -> some View {
        let shape = RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous)

        return VStack(alignment: .leading, spacing: Layout.captionGap) {
            Color.buttonsSecondary
                .frame(width: Layout.cardWidth)
                .frame(height: Layout.cardWidth / Layout.posterAspect)
                .overlay {
                    if let poster = title.poster {
                        ArtworkImage(source: .remote(poster)).scaledToFill()
                    }
                }
                .clipShape(shape)

            VStack(alignment: .leading, spacing: 0) {
                Text(title.title)
                    .plusMovieCaption()
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(2)
                    .frame(height: Layout.titleHeight, alignment: .top)

                if let year = title.year {
                    Text(year)
                        .plusMovieCaption()
                        .foregroundStyle(Color.fillSubtitle)
                }
            }
        }
        .frame(width: Layout.cardWidth, alignment: .leading)
    }
}
