import SwiftUI

/// Единая выдача кросс-сервисного поиска: один список, три секции в фиксированном
/// порядке — музыка, кино, книги.
///
/// Слой живёт **между затемнением и action bar**: расфокусивающий тап по затемнению
/// остаётся рабочим вокруг выдачи, а бар с полем ввода рисуется поверх и не перекрыт.
///
/// Пока домен не ответил, его секция — скелетон из трёх плашек: выдача не должна
/// прыгать по мере того, как приходят разные API. Ответил пусто — секции нет вовсе.
struct SearchResultsView: View {
    @Environment(SearchState.self) private var search
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard

    private enum Layout {
        static let rowHeight: CGFloat = 56
        static let artwork: CGFloat = 48
        static let artworkRadius: CGFloat = 8
        static let rowGap: CGFloat = 12
        static let sectionGap: CGFloat = 20
        static let side = PlusMetrics.screenMargin
        static let headerBottom: CGFloat = 8
        /// Зазор между низом выдачи и верхом поднятого бара
        static let barGap: CGFloat = 12
        static let skeletonRows = 3
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
            VStack(alignment: .leading, spacing: Layout.sectionGap) {
                section("Музыка", domain: search.music)
                section("Кино", domain: search.movies)
                section("Книги", domain: search.books)

                if search.isEmptyResult {
                    Text("Ничего не нашлось")
                        .plusTextS()
                        .foregroundStyle(Color.fillSubtitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Layout.side)
                }
            }
            .padding(.vertical, Layout.sectionGap)
        }
        .scrollIndicators(.hidden)
        // Клавиатура прячется свайпом по выдаче — привычный жест для длинных списков.
        .scrollDismissesKeyboard(.interactively)
        // Поджимаем **кадр** списка, а не его содержимое: с `safeAreaPadding` строки
        // продолжали рисоваться под баром и клавиатурой и просвечивали сквозь стекло.
        // Сверху — ровно безопасная зона: фиксированное число съедало бы из
        // и без того коротких ~250pt лишнюю строку, а без отступа первая строка
        // уезжала под статус-бар.
        .safeAreaPadding(.top)
        .padding(.bottom, keyboard.overlap + PlusMetrics.actionBarHeight + Layout.barGap)
    }

    @ViewBuilder
    private func section(_ title: String, domain: SearchState.Domain) -> some View {
        if domain.isLoading || !domain.hits.isEmpty {
            VStack(alignment: .leading, spacing: Layout.headerBottom) {
                Text(title)
                    .plusMovieCaption()
                    .foregroundStyle(Color.fillSubtitle)
                    .padding(.horizontal, Layout.side)

                VStack(spacing: Layout.rowGap) {
                    if domain.hits.isEmpty {
                        ForEach(0..<Layout.skeletonRows, id: \.self) { _ in skeletonRow }
                    } else {
                        ForEach(domain.hits) { hit in row(hit) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ hit: SearchHit) -> some View {
        if let route = hit.route {
            Button {
                // Поиск закрывается вместе с открытием: возвращаться в выдачу
                // поверх открытого экрана пользователю незачем.
                actionBar.isSearchFocused = false
                navigation.open(route)
            } label: {
                rowBody(hit)
            }
            .buttonStyle(PressScaleButtonStyle())
        } else {
            rowBody(hit)
        }
    }

    private func rowBody(_ hit: SearchHit) -> some View {
        HStack(spacing: Layout.rowGap) {
            artwork(hit)

            VStack(alignment: .leading, spacing: 0) {
                Text(hit.title)
                    .plusTextS()
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                if !hit.subtitle.isEmpty {
                    Text(hit.subtitle)
                        .plusTextS()
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: Layout.rowHeight)
        .padding(.horizontal, Layout.side)
        .contentShape(.rect)
    }

    @ViewBuilder
    private func artwork(_ hit: SearchHit) -> some View {
        let shape: AnyShape = hit.kind.isRoundArtwork
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: Layout.artworkRadius, style: .continuous))

        Color.buttonsSecondary
            .frame(width: Layout.artwork, height: Layout.artwork)
            .overlay {
                if let source = hit.artwork {
                    ArtworkImage(source: source).scaledToFill()
                }
            }
            .clipShape(shape)
            .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }

    /// Плашка вместо строки: та же высота, чтобы приход настоящих строк не сдвигал
    /// список. Цвет — общий с скелетоном карточки тайтла.
    private var skeletonRow: some View {
        HStack(spacing: Layout.rowGap) {
            RoundedRectangle(cornerRadius: Layout.artworkRadius, style: .continuous)
                .fill(Color.fillNine)
                .frame(width: Layout.artwork, height: Layout.artwork)

            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(Color.fillNine).frame(width: 180, height: 14)
                Rectangle().fill(Color.fillNine).frame(width: 110, height: 12)
            }

            Spacer(minLength: 0)
        }
        .frame(height: Layout.rowHeight)
        .padding(.horizontal, Layout.side)
        .accessibilityLabel("Загрузка")
    }
}
