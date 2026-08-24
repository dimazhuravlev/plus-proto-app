import SwiftUI

/// Роутер экранов сущностей. Один вход на все три типа: путь навигации хранит
/// `EntityRoute`, и он же служит `sourceID` зум-перехода.
struct EntityScreen: View {
    let route: EntityRoute

    var body: some View {
        switch route {
        case .movie(let ref): MovieScreen(entity: ref)
        case .book(let ref): BookScreen(entity: ref)
        case .album(let ref): AlbumScreen(entity: ref)
        }
    }
}

/// Общая заглушка экрана сущности: обложка на всю ширину, заголовок, подзаголовок.
///
/// Содержимого пока нет по решению пользователя — сейчас проверяется сам переход.
/// Экран фильма будет собран по `docs/research/figma-moviecard.md`.
struct EntityStubScreen: View {
    let entity: EntityRef
    let kind: String
    /// Круглая обложка у альбома, скруглённый прямоугольник у остальных.
    var roundArtwork = false
    /// Пропорция обложки: у постера 2:3, у книги 2:3, у альбома квадрат.
    var artworkAspect: CGFloat = 2.0 / 3.0

    /// Прокрутка для рампы навбара.
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Поле у обложки одно — общее у всего блока. Своё вдобавок к нему
                // отодвигало её от текста на вторые 16pt.
                artwork
                    .padding(.top, EntityStubLayout.artworkTop)

                Text(kind.uppercased())
                    .plusTextS()
                    .foregroundStyle(Color.fillSubtitle)
                    .padding(.top, EntityStubLayout.kindTop)

                Text(entity.title)
                    .plusTitleL()
                    .foregroundStyle(Color.fillOne)
                    .padding(.top, EntityStubLayout.titleTop)

                if !entity.subtitle.isEmpty {
                    Text(entity.subtitle)
                        .plusTextM()
                        .foregroundStyle(Color.fillSubtitle)
                        .padding(.top, EntityStubLayout.subtitleTop)
                }

                Text("Экран сущности пока не спроектирован — проверяется переход.")
                    .plusTextM()
                    .foregroundStyle(Color.fillSubtitle)
                    .padding(.top, EntityStubLayout.noteTop)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PlusMetrics.screenMargin)
        }
        .scrollIndicators(.hidden)
        // Лента едет под хромом, как на витрине.
        .contentMargins(.bottom, PlusChromeMetrics.contentBottomInset, for: .scrollContent)
        .trackNavBarScroll(into: $scrollOffset)
        .background(Color.black.ignoresSafeArea())
        // Верх экрана освобождён под навбар: он висит оверлеем и контент не поджимает.
        .safeAreaPadding(.top, EntityNavBarGeometry.barHeight)
        .overlay(alignment: .top) {
            EntityNavBar(
                title: entity.title,
                artwork: entity.artwork,
                isArtworkCircular: roundArtwork,
                scrollOffset: scrollOffset,
                // Бар стоит целиком, а не приезжает по скроллу. Рампа по умолчанию
                // рассчитана на экран, где под баром яркая шапка: там кнопка «назад»
                // читается и без подложки. Здесь под ней чёрный фон, заливка кнопки —
                // белый 10 %, и до первых 120pt скролла экран выглядит вовсе без
                // навбара. Так же приколот бар на заглушках сервисов.
                thresholds: .pinned
            )
        }
        // Системный бар выключен: на пуше он рисовал бы свой back поверх нашего.
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Кадр задаёт распорка, а картинка его заполняет.
    ///
    /// Наоборот — `ArtworkImage().scaledToFill().aspectRatio(…)` — не работает:
    /// `scaledToFill` уже зафиксировал пропорцию **картинки**, и второй `aspectRatio`
    /// поверх неё считает не от макетных 2:3, а от неё же. В ленте, где высота ничем
    /// не ограничена, обложка книги от этого раздувалась: замер по экрану — 268×530pt
    /// (пропорция 0.51) вместо 338×507 (0.667). Та же ловушка уже ловилась на кавере
    /// фильма и на видеокарточках.
    @ViewBuilder
    private var artwork: some View {
        let shape = roundArtwork
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous))

        Color.clear
            // Оба размера заданы числом, и это не перестраховка. `aspectRatio(.fit)`
            // в ленте бесполезен: высота там ничем не ограничена, предложение по ней
            // приходит пустым, и пропорция считается от ширины — обложка книги
            // вырастала в 370×555, весь экран под одну картинку. `maxHeight` поверх
            // этого лишь подрезает высоту, оставляя ширину прежней: 370×320,
            // то есть уже не 2:3 (замер обоих состояний на симуляторе).
            .frame(
                width: EntityStubLayout.artworkHeight * artworkAspect,
                height: EntityStubLayout.artworkHeight
            )
            .overlay {
                ArtworkImage(source: entity.artwork)
                    .scaledToFill()
            }
            .clipShape(shape)
            .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }
}

private enum EntityStubLayout {
    /// Высота обложки. Макета у этого экрана нет, число выбрано так, чтобы обложка,
    /// название и подпись помещались на первый экран целиком: 874 минус безопасная
    /// зона, навбар, отступ сверху, текстовый блок и клиренс под хром.
    static let artworkHeight: CGFloat = 320
    static let artworkTop: CGFloat = 72
    static let kindTop: CGFloat = 24
    static let titleTop: CGFloat = 4
    static let subtitleTop: CGFloat = 2
    static let noteTop: CGFloat = 24
}

struct BookScreen: View {
    let entity: EntityRef

    var body: some View {
        EntityStubScreen(entity: entity, kind: "Книга")
    }
}
