import SwiftUI

/// Полки после большой карусели. Геометрия снята с дочерних инстансов Figma
/// 331:45286: поля 16, зазор 8, две целые карточки и фиксированный край третьей.
struct HomeShelves: View {
    let feed: ShowcaseFeed
    @Environment(CinemaCatalog.self) private var cinema
    @Environment(BooksHomeCatalog.self) private var books
    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar

    private var movies: [HomeShelfItem] {
        guard APIKeysCheck.isKinopoiskConfigured else { return HomeShelfSamples.movies }
        let live = cinema.rows.flatMap(\.titles).filter { !$0.id.hasPrefix("mock") }
        guard !live.isEmpty else { return HomeShelfSamples.movies }
        var seen = Set<String>()
        return live.filter { seen.insert($0.id).inserted }.compactMap { movie in
            movie.poster.map { HomeShelfItem(id: movie.id, title: movie.title, subtitle: "", artwork: $0, route: movie.route) }
        }
    }
    private var bookItems: [HomeShelfItem] {
        guard APIKeysCheck.isKinopoiskConfigured else { return HomeShelfSamples.books }
        let live = books.rows.flatMap(\.books).filter { !$0.id.hasPrefix("mock") }
        guard !live.isEmpty else { return HomeShelfSamples.books }
        var seen = Set<String>()
        return live.filter { seen.insert($0.id).inserted }.map {
            HomeShelfItem(id: $0.id, title: $0.title, subtitle: $0.author, artwork: $0.cover, route: $0.route)
        }
    }
    private var artists: [HomeShelfItem] {
        guard APIKeysCheck.isKinopoiskConfigured else { return HomeShelfSamples.artists }
        let live = feed.promo.compactMap { block -> HomeShelfItem? in
            guard case .artist(let artist) = block else { return nil }
            return HomeShelfItem(id: block.id, title: artist.name, subtitle: "", artwork: artist.picture, route: artist.route)
        }
        return live.isEmpty ? HomeShelfSamples.artists : live
    }
    private var tracks: [MusicNowPlaying] {
        guard APIKeysCheck.isKinopoiskConfigured else { return HomeShelfSamples.tracks + Array(MyVibeTracks.all.prefix(3)) }
        let live = collection.items(.track, on: .favorites).compactMap(\.playable)
        return live.isEmpty ? HomeShelfSamples.tracks : live
    }

    var body: some View {
        VStack(spacing: 1) {
            posterShelf("Кино для вас", items: movies, width: movieWidth, tab: .kinopoisk)
            favorites
            artistShelf
            posterShelf("Книги для вас", items: bookItems, width: bookWidth, tab: .books, rounded: true, sectionPadding: 16)
            rankedShelf("Топ кино за месяц", items: Array(movies.prefix(2)))
            musicShelf
            rankedShelf("Топ кино за месяц", items: Array(movies.reversed().prefix(2)))
        }
    }

    private var movieWidth: CGFloat { (PlusMetrics.screenWidth - 16 - 16 - 47) / 2 }
    private var bookWidth: CGFloat { (PlusMetrics.screenWidth - 16 - 16 - 64) / 2 }
    private var artistWidth: CGFloat { bookWidth }

    private func header(_ title: String, tab: AppTab? = nil, ranked: Bool = false) -> some View {
        Group {
            if let tab {
                Button { navigation.select(tab) } label: { headerTitle(title, hasAction: true, ranked: ranked) }
                    .buttonStyle(.plain)
            } else {
                headerTitle(title, hasAction: false, ranked: ranked)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func headerTitle(_ title: String, hasAction: Bool, ranked: Bool) -> some View {
        HStack(spacing: ranked ? 4 : 2) {
            if ranked { Image("shelfTopIcon").resizable().frame(width: 16, height: 16) }
            Text(title).plusHeadline(.s)
                .foregroundStyle(ranked ? Color(red: 226 / 255, green: 188 / 255, blue: 232 / 255) : .fillOne)
                .lineLimit(1)
            if hasAction && !ranked { Image("shelfChevron").resizable().frame(width: 20, height: 20) }
            Spacer(minLength: 0)
        }
    }

    private func posterShelf(_ title: String, items: [HomeShelfItem], width: CGFloat, tab: AppTab, rounded: Bool = false, sectionPadding: CGFloat = 8) -> some View {
        VStack(spacing: 0) {
            header(title, tab: tab)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(items) { item in
                        Button { navigation.open(item.route) } label: {
                            poster(item, width: width, rounded: rounded)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, sectionPadding)
    }

    private func poster(_ item: HomeShelfItem, width: CGFloat, rounded: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.frame(width: width, height: width * 1.5)
                .overlay { ArtworkImage(source: item.artwork).scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: rounded ? 12 : 0))
                .overlay(alignment: .topLeading) {
                    if let rating = item.rating {
                        Text(rating).plusText(.textS, .semibold)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 20)
                            .background(Color(red: 59 / 255, green: 179 / 255, blue: 59 / 255))
                            .padding(6)
                    }
                }
            Text(item.title).plusText(.textS, .medium).foregroundStyle(Color.fillOne)
                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
        }
        .frame(width: width, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
    }

    private var favorites: some View {
        VStack(spacing: 0) {
            header("Моё избранное")
            HStack(spacing: 8) {
                favorite("Кино", icon: "shelfFavoriteMovie", glow: "shelfGlowMovie", kind: .movie, size: CGSize(width: 243.422, height: 143))
                favorite("Музыка", icon: "shelfFavoriteMusic", glow: "shelfGlowMusic", kind: .track, size: CGSize(width: 240.033, height: 121.817))
                favorite("Книги", icon: "shelfFavoriteBook", glow: "shelfGlowBook", kind: .book, size: CGSize(width: 220.755, height: 143.446))
            }
            .padding(.horizontal, 16)
        }.padding(.vertical, 8)
    }

    private func favorite(_ title: String, icon: String, glow: String, kind: CollectionItem.Kind, size: CGSize) -> some View {
        Button { navigation.push(CollectionListRoute(source: .shelf(kind, .favorites), title: title)) } label: {
            Color.clear.frame(maxWidth: .infinity).frame(height: 94)
                .glassSurface(
                    RoundedRectangle(cornerRadius: 32),
                    blur: 20, fill: .fillNine,
                    border: Color.white.opacity(0.1), borderWidth: 1
                )
                .overlay(alignment: .top) {
                    let isMovie = kind == .movie
                    let isMusic = kind == .track
                    let centerY: CGFloat = isMovie ? 100.658 : (isMusic ? 102.602 : 95.028)
                    Image(glow).resizable().frame(width: size.width, height: size.height)
                        .scaleEffect(x: 1, y: -1)
                        .rotationEffect(.degrees(isMovie ? -172.59 : (isMusic ? 177.24 : 178.9)))
                        .offset(x: isMovie ? 3.155 : (isMusic ? 6.014 : 10.907), y: centerY - size.height / 2)
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 12) {
                        Image(icon).resizable().frame(width: 24, height: 24)
                        Text(title).plusText(.textS, .medium).foregroundStyle(Color.fillOne)
                    }.padding(.top, 19)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay { RoundedRectangle(cornerRadius: 32).strokeBorder(Color.white.opacity(0.1), lineWidth: 1) }
        }.buttonStyle(.plain)
    }

    private var artistShelf: some View {
        VStack(spacing: 0) {
            header("Музыка для вас", tab: .music)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(artists) { item in
                        Button { navigation.open(item.route) } label: {
                            VStack(spacing: 8) {
                                Color.clear.frame(width: artistWidth, height: artistWidth)
                                    .overlay { ArtworkImage(source: item.artwork).scaledToFill() }
                                    .clipShape(Circle())
                                    .overlay { Circle().strokeBorder(Color.fillNine, lineWidth: 1) }
                                Text(item.title).plusText(.textS, .medium).foregroundStyle(Color.fillOne)
                                    .lineLimit(1).frame(width: artistWidth)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }.scrollIndicators(.hidden)
        }.padding(.vertical, 16)
    }

    private func rankedShelf(_ title: String, items: [HomeShelfItem]) -> some View {
        VStack(spacing: 0) {
            header(title, tab: .kinopoisk, ranked: true)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button { navigation.open(item.route) } label: {
                            poster(item, width: movieWidth)
                                .overlay(alignment: .topLeading) {
                                    Image(index == 0 ? "shelfRank1" : "shelfRank2")
                                        .resizable().frame(width: 79.2, height: 158.4)
                                        .offset(x: -53, y: movieWidth * 1.5 / 2 - 1 - 158.4 / 2)
                                }
                                .padding(.leading, 48)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16)
            }.scrollIndicators(.hidden)
        }.padding(.vertical, 8)
    }

    private var musicShelf: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button { if let first = tracks.first { actionBar.open(.music(first)) } } label: {
                    Image("shelfMusicPlay").resizable().frame(width: 24, height: 24)
                        .padding(12).secondaryButtonSurface(Circle())
                }.buttonStyle(.plain).accessibilityLabel("Слушать популярную музыку")
                // Keep the local two-line design while adopting the renamed font family.
                VStack(alignment: .leading, spacing: 32 - (UIFont(name: PlusFont.display, size: 32) ?? .systemFont(ofSize: 32)).lineHeight) {
                    ForEach(["Популярная", "музыка"], id: \.self) { line in
                        Text(line).font(.custom(PlusFont.display, size: 32)).tracking(0.48)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                    .foregroundStyle(Color.fillOne)
                    .frame(height: 64)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, 16)
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(0..<max(1, (tracks.count + 2) / 3), id: \.self) { column in
                        VStack(spacing: 0) {
                            ForEach(Array(tracks.dropFirst(column * 3).prefix(3).enumerated()), id: \.element.id) { index, track in
                                Button { actionBar.open(.music(track)) } label: {
                                    HStack(spacing: 12) {
                                        Color.clear.frame(width: 48, height: 48)
                                            .overlay { ArtworkImage(source: track.cover).scaledToFill() }
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        VStack(alignment: .leading, spacing: -2) {
                                            Text(track.title).foregroundStyle(Color.fillOne).lineLimit(1)
                                            Text(track.artist.isEmpty ? "Description" : track.artist).foregroundStyle(Color.fillSubtitle).lineLimit(1)
                                        }.plusText(.textM, .medium)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, index == 1 ? 8 : 4)
                                    .overlay(alignment: .bottom) {
                                        if index < 2 { Image("shelfMusicDivider").resizable().frame(width: 271, height: 0.5) }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }.frame(width: 271).padding(.horizontal, 16)
                    }
                }
            }.scrollIndicators(.hidden)
        }
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.fillNine))
        .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(Color.fillNine, lineWidth: 0.66) }
        .padding(16)
    }
}
