import SwiftUI

/// Картинка контента: из бандла или из API. Источник различаем здесь, чтобы вёрстка
/// карточек не зависела от того, приехали живые данные или нет (приём `Track`
/// из MusicPlayer: имя ассета + опциональный URL).
struct ArtworkImage: View {
    let source: ArtworkSource

    var body: some View {
        ResolvedArtwork(source: source) { image in
            image.resizable()
        }
    }
}

/// Разрешает `ArtworkSource` в готовый `Image` и отдаёт его билдеру. Нужен там, где вью
/// строит из картинки что-то ещё — `AmbilightArtwork` запекает из неё ореол, а `ArtworkImage`
/// отдал бы уже собранное вью.
///
/// Пока живая картинка не загрузилась, рисуется бандленный фолбэк источника: без него
/// витрина мигала бы дырами на каждом холодном старте, а без сети осталась бы пустой.
struct ResolvedArtwork<Content: View, Placeholder: View>: View {
    let source: ArtworkSource
    @ViewBuilder let content: (Image) -> Content
    /// Что показать, если картинки нет вовсе: у источника нет бандленного фолбэка,
    /// а живая не загрузилась. Нужен там, где вместо картинки уместен текст —
    /// логотип проекта заменяется его названием.
    @ViewBuilder let placeholder: () -> Placeholder

    /// Загруженная картинка. Инициализируется синхронно из памяти — иначе уже
    /// прогретая обложка всё равно моргала бы фолбэком один кадр.
    @State private var loaded: Image?

    var body: some View {
        Group {
            if let image = loaded ?? fallback {
                content(image)
            } else {
                placeholder()
            }
        }
        .task(id: source.remoteURL) {
            guard let url = source.remoteURL else {
                loaded = nil
                return
            }
            if let hit = ArtworkLoader.shared.cached(url) {
                loaded = Image(uiImage: hit)
                return
            }
            loaded = nil
            if let image = await ArtworkLoader.shared.image(for: url) {
                loaded = Image(uiImage: image)
            }
        }
    }

    private var fallback: Image? {
        guard let name = source.fallbackAsset else { return nil }
        return Image(name)
    }
}

extension ResolvedArtwork where Placeholder == Color {
    init(source: ArtworkSource, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(source: source, content: content) { Color.buttonsPrimary }
    }
}
