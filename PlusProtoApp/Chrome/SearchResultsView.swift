import SwiftUI

/// Выдача кросс-сервисного поиска — карусели по макету `2118:17378`: секция на домен,
/// внутри горизонтальная лента карточек.
///
/// Карточек два вида, и это не украшательство, а форма самого контента: у музыки
/// обложка квадратная (у исполнителя — круглая), у кино и книг постер 2:3. Ширина
/// колонки одна на оба вида — 109, поэтому ленты разных секций стоят по одной сетке.
///
/// Слой живёт **между затемнением и action bar**: расфокусивающий тап по затемнению
/// остаётся рабочим вокруг выдачи, а бар с полем ввода рисуется поверх и не перекрыт.
struct SearchResultsView: View {
    @Environment(SearchState.self) private var search
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard

    private enum Layout {
        /// Ширина колонки карусели (макет: контейнер 109 при шаге 117)
        static let card: CGFloat = 109
        static let cardGap: CGFloat = 8
        static let side = PlusMetrics.screenMargin
        /// Обложка → подписи
        static let coverGap: CGFloat = 6
        /// Постер кино и книги — 2:3 (макет: 109 × 163.5)
        static let posterAspect: CGFloat = 109.0 / 163.5
        static let coverRadius = PlusRadius.movieChip
        /// Поля секции: сверху 16 и снизу 12 у заголовка, плюс 8 у самой секции
        static let sectionVertical: CGFloat = 8
        static let headerTop: CGFloat = 16
        static let headerBottom: CGFloat = 12
        /// Зазор «заголовок ↔ шеврон» из макета
        static let headerGap: CGFloat = 2
        static let chevronBox: CGFloat = 20
        /// Зазор между низом выдачи и верхом поднятого бара
        static let barGap: CGFloat = 12
        static let skeletonCards = 4
        /// Правое поле подписи: в макете текст уже колонки на 8
        static let labelTrailing: CGFloat = 8
    }

    var body: some View {
        // Выдача живёт только с поднятой клавиатурой — тем же признаком, что и
        // затемнение под ней (`SearchOverlay`), иначе слои разъезжались бы.
        if keyboard.isUp && search.isActive {
            content
                .transition(.opacity)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                carousel("Музыка", domain: search.music)
                carousel("Кино", domain: search.movies)
                carousel("Книги", domain: search.books)

                if search.isEmptyResult {
                    Text("Ничего не нашлось")
                        .plusTextS()
                        .foregroundStyle(Color.fillSubtitle)
                        .padding(.horizontal, Layout.side)
                        .padding(.vertical, Layout.headerTop)
                }
            }
        }
        .scrollIndicators(.hidden)
        // Клавиатура прячется свайпом по выдаче — привычный жест для длинных списков.
        .scrollDismissesKeyboard(.interactively)
        // Поджимаем **кадр** списка, а не его содержимое: с `safeAreaPadding` строки
        // продолжали рисоваться под баром и клавиатурой и просвечивали сквозь стекло.
        // Сверху — ровно безопасная зона: фиксированное число съедало бы из
        // и без того коротких ~250pt лишнюю строку.
        .safeAreaPadding(.top)
        .padding(.bottom, keyboard.overlap + PlusMetrics.actionBarHeight + Layout.barGap)
    }

    // MARK: Секция

    @ViewBuilder
    private func carousel(_ title: String, domain: SearchState.Domain) -> some View {
        if domain.isLoading || !domain.hits.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header(title)

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Layout.cardGap) {
                        if domain.hits.isEmpty {
                            // Скелетон повторяет форму карточек своей секции, иначе
                            // приход выдачи перекладывал бы ленту.
                            ForEach(0..<Layout.skeletonCards, id: \.self) { _ in
                                skeletonCard(isPoster: title != "Музыка")
                            }
                        } else {
                            ForEach(domain.hits) { hit in card(hit) }
                        }
                    }
                    .padding(.horizontal, Layout.side)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.vertical, Layout.sectionVertical)
        }
    }

    /// Заголовок секции с шевроном — `header / static` из макета: 24/28 и глиф 20
    /// сразу за текстом, а не у правого края.
    private func header(_ title: String) -> some View {
        HStack(spacing: Layout.headerGap) {
            Text(title)
                .plusMovieSection()
                .foregroundStyle(Color.fillOne)

            // Правый шеврон — отзеркаленный `icon / dropleft`: своего ассета нет,
            // а глиф тот же (приём «не плодить зеркальные ассеты»).
            Image("iconDropleft")
                .renderingMode(.template)
                .resizable()
                .frame(width: Layout.chevronBox, height: Layout.chevronBox)
                .scaleEffect(x: -1)
                .foregroundStyle(Color.fillSubtitle)
        }
        .padding(.top, Layout.headerTop)
        .padding(.bottom, Layout.headerBottom)
        .padding(.horizontal, Layout.side)
    }

    // MARK: Карточка

    @ViewBuilder
    private func card(_ hit: SearchHit) -> some View {
        if let route = hit.route {
            Button {
                // Поиск закрывается вместе с открытием: возвращаться в выдачу
                // поверх открытого экрана пользователю незачем.
                actionBar.isSearchFocused = false
                navigation.open(route)
            } label: {
                cardBody(hit)
            }
            .buttonStyle(PressScaleButtonStyle())
        } else {
            cardBody(hit)
        }
    }

    private func cardBody(_ hit: SearchHit) -> some View {
        // Исполнитель по макету центрирован — и обложка кругом, и подпись по центру.
        let isArtist = hit.kind.isRoundArtwork

        return VStack(alignment: isArtist ? .center : .leading, spacing: Layout.coverGap) {
            cover(hit)

            VStack(alignment: isArtist ? .center : .leading, spacing: 0) {
                Text(hit.title)
                    .plusTextS()
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(2)
                    .multilineTextAlignment(isArtist ? .center : .leading)

                if !hit.subtitle.isEmpty {
                    Text(hit.subtitle)
                        .plusTextS()
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: isArtist ? .center : .leading)
            // В макете подпись уже колонки: длинное название обрывается раньше
            // правого края карточки.
            .padding(.trailing, isArtist ? 0 : Layout.labelTrailing)
        }
        .frame(width: Layout.card)
        .contentShape(.rect)
    }

    private func cover(_ hit: SearchHit) -> some View {
        let shape: AnyShape = hit.kind.isRoundArtwork
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: Layout.coverRadius, style: .continuous))

        return Color.buttonsSecondary
            .frame(width: Layout.card)
            .frame(height: coverHeight(hit.kind))
            .overlay {
                if let source = hit.artwork {
                    ArtworkImage(source: source).scaledToFill()
                }
            }
            .clipShape(shape)
            .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }

    /// Квадрат у музыки, постер 2:3 у кино и книг.
    private func coverHeight(_ kind: SearchHit.Kind) -> CGFloat {
        switch kind {
        case .track, .album, .artist: Layout.card
        case .movie, .book: Layout.card / Layout.posterAspect
        }
    }

    private func skeletonCard(isPoster: Bool) -> some View {
        VStack(alignment: .leading, spacing: Layout.coverGap) {
            RoundedRectangle(cornerRadius: Layout.coverRadius, style: .continuous)
                .fill(Color.fillNine)
                .frame(width: Layout.card)
                .frame(height: isPoster ? Layout.card / Layout.posterAspect : Layout.card)

            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(Color.fillNine).frame(width: 88, height: 12)
                Rectangle().fill(Color.fillNine).frame(width: 60, height: 12)
            }
        }
        .frame(width: Layout.card)
        .accessibilityLabel("Загрузка")
    }
}
