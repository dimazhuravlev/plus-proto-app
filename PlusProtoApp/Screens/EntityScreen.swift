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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                artwork
                    .padding(.horizontal, PlusMetrics.screenMargin)
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
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var artwork: some View {
        let shape = roundArtwork
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous))

        ArtworkImage(source: entity.artwork)
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .aspectRatio(artworkAspect, contentMode: .fit)
            .clipShape(shape)
            .overlay { shape.stroke(Color.fillNine, lineWidth: PlusMetrics.hairline) }
    }
}

private enum EntityStubLayout {
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

struct AlbumScreen: View {
    let entity: EntityRef

    var body: some View {
        EntityStubScreen(entity: entity, kind: "Альбом", roundArtwork: true, artworkAspect: 1)
    }
}
