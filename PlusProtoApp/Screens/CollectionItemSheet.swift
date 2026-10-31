import SwiftUI

// MARK: - Шторки записей

/// Оверфлоу записей коллекции — шторка действий (`ActionSheetOverlay`) вместо системного
/// меню везде (решение пользователя 2026-10-28). Наборы пунктов:
/// - книга — макет `type=book` (`18482:216311`);
/// - фильм в «Скачанном» — макет `type=movie` (`18487:220129`);
/// - трек — макет `17213:40281`, альбом, исполнитель, плейлист и свой плейлист — по
///   шторкам Музыки, присланным пользователем: шапка-сущность, «Моя волна на основе …»
///   и свой набор пунктов;
/// - фильм вне «Скачанного» — макета нет, пункты из соседних макетов.
///
/// Пункты показывают состояние: отмеченное «Нравится» — залитым сердцем в акценте,
/// скачанное — «Удалить из загрузок». Подключено то, у чего в прототипе есть логика
/// (отметки, экраны сущности, альбома и исполнителя, шеринг, «Моя волна»); остальные пункты только откликаются.
@MainActor
enum CollectionItemSheet {
    static func content(
        for item: CollectionItem,
        shelf: CollectionStore.Shelf?,
        collection: CollectionStore,
        navigation: AppNavigationState,
        actionBar: ActionBarState
    ) -> ActionSheetContent {
        let context = Context(item: item, shelf: shelf, collection: collection, navigation: navigation, actionBar: actionBar)
        switch item.kind {
        case .book: return context.book
        case .movie: return shelf == .downloads ? context.downloadedMovie : context.movie
        case .track: return context.track
        case .album: return context.album
        case .artist: return context.artist
        case .playlist: return MyPlaylists.isOwn(item) ? context.ownPlaylist : context.playlist
        }
    }

    @MainActor
    private struct Context {
        let item: CollectionItem
        let shelf: CollectionStore.Shelf?
        let collection: CollectionStore
        let navigation: AppNavigationState
        let actionBar: ActionBarState

        // MARK: Книга и кино

        /// Книга: «О книге», «Поделиться», «Скачать», «Оглавление», «Поиск по книге»,
        /// «Уже прочитано» и отдельным островком «Удалить».
        var book: ActionSheetContent {
            ActionSheetContent(groups: [
                [
                    ActionSheetItem(icon: "iconBook", title: "О книге", action: openEntity),
                    share(.book(title: item.title, author: item.subtitle, cover: item.artwork, aspect: item.aspect)),
                    download,
                    ActionSheetItem(icon: "iconList", title: "Оглавление"),
                    ActionSheetItem(icon: "iconSearch", title: "Поиск по книге"),
                    ActionSheetItem(icon: "iconComplain", title: "Уже прочитано"),
                ],
                [ActionSheetItem(icon: "iconDelete", title: "Удалить", action: removeFromShelf)],
            ])
        }

        /// Скачанный фильм или сериал: «О фильме» и «Удалить из загрузок».
        var downloadedMovie: ActionSheetContent {
            ActionSheetContent(groups: [[
                ActionSheetItem(icon: "iconTrailerOutline", title: "О фильме", action: openEntity),
                download,
            ]])
        }

        /// Фильм в «Любимом» и «Покупках» — макета нет: «О фильме» и загрузка из макета
        /// скачанного фильма, «Удалить» отдельным островком — как у книги.
        var movie: ActionSheetContent {
            ActionSheetContent(groups: [
                [ActionSheetItem(icon: "iconTrailerOutline", title: "О фильме", action: openEntity), download],
                [ActionSheetItem(icon: "iconDelete", title: "Удалить", action: removeFromShelf)],
            ])
        }

        // MARK: Музыка

        /// Трек — макет `17213:40281`.
        var track: ActionSheetContent {
            ActionSheetContent(
                header: header(),
                notes: notes,
                vibe: vibe,
                groups: [
                    [
                        like,
                        ActionSheetItem(icon: "iconAdd", title: "Добавить в плейлист"),
                        download,
                        playNext,
                        share(.album(title: item.title, artist: item.subtitle, year: nil, cover: item.artwork, artistPicture: nil)),
                        ActionSheetItem(icon: "iconArtist", title: "Посмотреть исполнителя", action: openTrackArtist),
                        ActionSheetItem(icon: "iconAlbum", title: "Посмотреть альбом", action: openEntity),
                        ActionSheetItem(icon: "iconCircleInfo", title: "О треке"),
                    ],
                    [ActionSheetItem(icon: "iconLoveNo", title: "Не рекомендовать")],
                ]
            )
        }

        var album: ActionSheetContent {
            ActionSheetContent(
                header: header(),
                notes: notes,
                vibe: vibe,
                groups: [[
                    like,
                    playNext,
                    share(.album(title: item.title, artist: item.subtitle, year: nil, cover: item.artwork, artistPicture: nil)),
                ]]
            )
        }

        var artist: ActionSheetContent {
            ActionSheetContent(
                header: header(isCircle: true),
                vibe: vibe,
                groups: [[like, share(.artist(name: item.title, photo: item.artwork))]]
            )
        }

        var playlist: ActionSheetContent {
            ActionSheetContent(
                header: header(),
                vibe: vibe,
                groups: [[
                    like,
                    playNext,
                    share(.playlist(title: item.title, owner: item.subtitle, cover: item.artwork)),
                ]]
            )
        }

        /// Свой плейлист: без «Нравится», удалить его можно. Само удаление прототип
        /// не делает — стартовый набор (`MyPlaylists`).
        var ownPlaylist: ActionSheetContent {
            ActionSheetContent(
                header: header(),
                vibe: vibe,
                groups: [[
                    playNext,
                    share(.playlist(title: item.title, owner: "", cover: item.artwork)),
                    ActionSheetItem(icon: "iconDelete", title: "Удалить плейлист"),
                ]]
            )
        }

        // MARK: Общие части

        /// Шапка: обложка, название и серым — исполнитель, владелец или число треков.
        private func header(isCircle: Bool = false) -> ActionSheetHeader {
            ActionSheetHeader(
                artwork: item.artwork,
                isCircle: isCircle,
                title: item.title,
                details: isCircle ? [] : [item.subtitle]
            )
        }

        /// 18+ — пометкой под шапкой, как в макете трека. Других пометок (иноагент)
        /// нет данных — нет и строки.
        private var notes: [String] {
            item.isExplicit == true ? ["Возрастное ограничение 18+"] : []
        }

        /// «Моя волна на основе …» включает «Мою волну».
        private var vibe: ActionSheetVibe {
            let actionBar = actionBar
            return ActionSheetVibe(caption: "Моя волна на основе", title: item.title) {
                actionBar.openMyVibe()
            }
        }

        /// «Нравится» — залитое сердце в акценте у отмеченного, тап снимает отметку.
        private var like: ActionSheetItem {
            let item = item, collection = collection
            let isLiked = collection.isFavorite(item.id)
            return ActionSheetItem(
                icon: isLiked ? "iconLiked" : "iconLove",
                title: "Нравится",
                iconColor: isLiked ? .accentPrimary : .fillOne
            ) {
                collection.setFavorite(item, !isLiked)
            }
        }

        /// «Скачать» или, у скачанного, «Удалить из загрузок».
        private var download: ActionSheetItem {
            let item = item, collection = collection
            let isDownloaded = collection.isDownloaded(item.id)
            return ActionSheetItem(
                icon: isDownloaded ? "iconDelete" : "iconDownload",
                title: isDownloaded ? "Удалить из загрузок" : "Скачать"
            ) {
                collection.setDownloaded(item, !isDownloaded)
            }
        }

        /// Очередь «следующим» прототип не ведёт — пункт только откликается.
        private var playNext: ActionSheetItem {
            ActionSheetItem(icon: "iconNextInQueue", title: "Играть следующим")
        }

        private func share(_ entity: ShareableEntity) -> ActionSheetItem {
            ActionSheetItem(icon: "iconShare", title: "Поделиться") {
                ShareState.shared.present(entity)
            }
        }

        /// Экран сущности — тот же переход, что тап по карточке; у трека — его альбом.
        /// Без экрана (моки) — без действия.
        private var openEntity: (@MainActor () -> Void)? {
            guard let route = item.route else { return nil }
            let navigation = navigation
            return { navigation.open(route) }
        }

        /// Исполнитель трека: в записи его нет — он приходит из трека Deezer (один запрос
        /// на тап; поиск по имени находит тёзок). Экран открывается, когда ответ пришёл;
        /// трек не из Deezer — без действия.
        private var openTrackArtist: (@MainActor () -> Void)? {
            guard let trackID = Self.deezerTrackID(item) else { return nil }
            let navigation = navigation
            return {
                Task { @MainActor in
                    guard let artist = try? await DeezerService.shared.freshTrack(id: trackID).artist else { return }
                    let picture = (artist.pictureBig ?? artist.pictureMedium).flatMap(URL.init(string:))
                    navigation.open(.artist(EntityRef(
                        id: "dz-\(artist.id)",
                        title: artist.name,
                        subtitle: "",
                        artwork: picture.map { .remote($0) } ?? .asset("")
                    )))
                }
            }
        }

        /// Id трека Deezer — из ключа записи (`track:dz-<id>`) или хвоста id плеера (`…-t<id>`).
        private static func deezerTrackID(_ item: CollectionItem) -> Int? {
            if item.id.hasPrefix("track:dz-"), let id = Int(item.id.dropFirst("track:dz-".count)) { return id }
            guard let playerID = item.playable?.id,
                  let marker = playerID.range(of: "-t", options: .backwards) else { return nil }
            return Int(playerID[marker.upperBound...])
        }

        /// «Удалить» снимает отметку той полки, где запись показана: «Любимое» — «нравится»,
        /// «Скачанное» — загрузку. В «Читаю», «Прочитано» и «Покупках» отметки нет — пункт
        /// без действия.
        private var removeFromShelf: (@MainActor () -> Void)? {
            let item = item, collection = collection
            switch shelf {
            case .favorites: return { collection.setFavorite(item, false) }
            case .downloads: return { collection.setDownloaded(item, false) }
            case nil: return nil
            }
        }
    }
}

extension MyPlaylists {
    /// Свой плейлист из стартового набора — у него своя шторка.
    static func isOwn(_ item: CollectionItem) -> Bool {
        all.contains { "playlist:playlist-\($0.entityID)" == item.id }
    }
}

// MARK: - Откуда открывается

extension View {
    /// Шторка записи по долгому нажатию. `shelf` — полка, где запись показана (`nil` —
    /// список без отметок: «Читаю», «Прочитано», «Покупки»).
    func collectionItemActions(_ item: CollectionItem, shelf: CollectionStore.Shelf?) -> some View {
        modifier(CollectionItemActions(item: item, shelf: shelf))
    }
}

private struct CollectionItemActions: ViewModifier {
    let item: CollectionItem
    let shelf: CollectionStore.Shelf?

    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar

    func body(content: Content) -> some View {
        content.actionSheetOnHold {
            CollectionItemSheet.content(for: item, shelf: shelf, collection: collection, navigation: navigation, actionBar: actionBar)
        }
    }
}

/// «Ещё» строки записи — её шторка.
struct CollectionItemMoreButton: View {
    let item: CollectionItem
    let shelf: CollectionStore.Shelf?

    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation
    @Environment(ActionBarState.self) private var actionBar

    var body: some View {
        ActionSheetMoreButton {
            CollectionItemSheet.content(for: item, shelf: shelf, collection: collection, navigation: navigation, actionBar: actionBar)
        }
    }
}
