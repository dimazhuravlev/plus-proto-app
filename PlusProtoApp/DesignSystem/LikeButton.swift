import SwiftUI

/// Сердце «нравится» — одно поведение везде, как в мини-плеере (правка пользователя
/// 2026-10-04): контур ↔ залитое сменяются кросс-попом — прозрачность и масштаб 0.4
/// той же пружиной, что play/pause бара (`ActionBarMotion.iconSwap`). Цвета у мест
/// свои (в строках выдачи контур приглушён), движение — общее.
struct LikeGlyph: View {
    let isLiked: Bool
    let box: CGFloat
    var offColor: Color = .fillOne
    var onColor: Color = .fillOne

    var body: some View {
        ZStack {
            glyph("iconLove")
                .foregroundStyle(offColor)
                .opacity(isLiked ? 0 : 1)
                .scaleEffect(isLiked ? ActionBarMotion.iconSwapScale : 1)
            glyph("iconLiked")
                .foregroundStyle(onColor)
                .opacity(isLiked ? 1 : 0)
                .scaleEffect(isLiked ? 1 : ActionBarMotion.iconSwapScale)
        }
        .animation(ActionBarMotion.iconSwap, value: isLiked)
    }

    private func glyph(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: box, height: box)
    }
}

/// play ↔ pause — одно движение везде, где глиф меняется на месте (правка пользователя
/// 2026-10-05: в карточке трека сетки он подменялся без анимации): плееры, бар, кнопки
/// экранов, карточки. Цвет задаёт место — `foregroundStyle` снаружи.
struct PlayPauseGlyph: View {
    let isPlaying: Bool
    let box: CGFloat

    var body: some View {
        ZStack {
            glyph("iconPlay")
                .opacity(isPlaying ? 0 : 1)
                .scaleEffect(isPlaying ? ActionBarMotion.iconSwapScale : 1)
            glyph("iconPause")
                .opacity(isPlaying ? 1 : 0)
                .scaleEffect(isPlaying ? 1 : ActionBarMotion.iconSwapScale)
        }
        .animation(ActionBarMotion.iconSwap, value: isPlaying)
    }

    private func glyph(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: box, height: box)
    }
}

/// «Нравится» — `PlusButton` secondary M, только иконка — ряд действий экранов альбома, книги и персоны.
/// Отмечает сущность в «Любимом» коллекции «Моё» (2026-10-04). Без записи коллекции
/// (сущность ей неизвестна) — отметка на время экрана, как было прежде.
/// Хаптик — как у лайка мини-плеера.
struct LikeGlassButton: View {
    var item: CollectionItem? = nil

    @Environment(CollectionStore.self) private var collection
    @State private var isLikedLocally = false

    private var isLiked: Bool {
        item.map { collection.isFavorite($0.id) } ?? isLikedLocally
    }

    var body: some View {
        PlusButton(
            type: .secondary,
            size: .m,
            accessibilityTitle: isLiked ? "Убрать из любимых" : "Нравится"
        ) {
            if let item {
                collection.toggleFavorite(item)
            } else {
                isLikedLocally.toggle()
            }
        } icon: {
            LikeGlyph(isLiked: isLiked, box: PlusButtonSize.m.iconBox)
        }
    }
}

/// Закладка «Позже» — контур с плюсом ↔ залитая, тем же кросс-попом, что сердце:
/// тайтл в «Любимом» коллекции «Моё» (2026-10-04).
struct BookmarkGlyph: View {
    let isSaved: Bool
    let box: CGFloat
    /// Контур — тише в строках выдачи поиска (Fill/Five, макет `19184:22008`).
    var offColor: Color = .fillOne
    /// Контур с плюсом — у «Позже»; в строках выдачи поиска — простой (`iconBookmarkPlain`).
    var offIcon = "iconBookmark"

    var body: some View {
        ZStack {
            glyph(offIcon, color: offColor)
                .opacity(isSaved ? 0 : 1)
                .scaleEffect(isSaved ? ActionBarMotion.iconSwapScale : 1)
            glyph("iconBookmarkFilled", color: .fillOne)
                .opacity(isSaved ? 1 : 0)
                .scaleEffect(isSaved ? 1 : ActionBarMotion.iconSwapScale)
        }
        .animation(ActionBarMotion.iconSwap, value: isSaved)
    }

    private func glyph(_ name: String, color: Color) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: box, height: box)
            .foregroundStyle(color)
    }
}

/// «+» книги в выдаче поиска — в «Буду читать» коллекции; добавленная — галочка, тем же
/// кросс-попом, что закладка (решение пользователя 2026-10-31, макет `19191:22495`).
struct AddGlyph: View {
    let isAdded: Bool
    let box: CGFloat
    var offColor: Color = .fillOne

    var body: some View {
        ZStack {
            glyph("iconAdd", color: offColor)
                .opacity(isAdded ? 0 : 1)
                .scaleEffect(isAdded ? ActionBarMotion.iconSwapScale : 1)
            glyph("iconDone", color: .fillOne)
                .opacity(isAdded ? 1 : 0)
                .scaleEffect(isAdded ? 1 : ActionBarMotion.iconSwapScale)
        }
        .animation(ActionBarMotion.iconSwap, value: isAdded)
    }

    private func glyph(_ name: String, color: Color) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: box, height: box)
            .foregroundStyle(color)
    }
}

/// Значок «скачать» — одно поведение для круглых кнопок экранов (альбом, книга,
/// фильм): скачанное — фиолетовая галочка (`#A332FF`, макет `2455:32137`, правка
/// пользователя 2026-10-06; прежде — та же стрелка фиолетовым), смена — тем же
/// кросс-попом, что у сердца.
struct DownloadGlyph: View {
    let isDownloaded: Bool
    let box: CGFloat
    var offColor: Color = .fillOne

    var body: some View {
        ZStack {
            glyph("iconDownload", color: offColor)
                .opacity(isDownloaded ? 0 : 1)
                .scaleEffect(isDownloaded ? ActionBarMotion.iconSwapScale : 1)
            glyph("iconDone", color: Color.accentPrimary)
                .opacity(isDownloaded ? 1 : 0)
                .scaleEffect(isDownloaded ? 1 : ActionBarMotion.iconSwapScale)
        }
        .animation(ActionBarMotion.iconSwap, value: isDownloaded)
    }

    private func glyph(_ name: String, color: Color) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: box, height: box)
            .foregroundStyle(color)
    }
}

/// «Скачать» — `PlusButton` secondary M, только иконка — ряд действий экранов альбома и книги: отмечает
/// сущность в «Скачанном» коллекции «Моё». Скачивания в прототипе нет — отметка
/// мгновенная, хаптик — как у сердца.
struct DownloadGlassButton: View {
    let item: CollectionItem

    @Environment(CollectionStore.self) private var collection

    var body: some View {
        let isDownloaded = collection.isDownloaded(item.id)
        PlusButton(
            type: .secondary,
            size: .m,
            accessibilityTitle: isDownloaded ? "Удалить из скачанного" : "Скачать"
        ) {
            collection.toggleDownload(item)
        } icon: {
            DownloadGlyph(isDownloaded: isDownloaded, box: PlusButtonSize.m.iconBox)
        }
    }
}
