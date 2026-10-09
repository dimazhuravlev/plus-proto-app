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
    /// Как проявляется картинка, приехавшая из сети. `nil` — сразу, как было везде;
    /// выдача поиска проявляет обложки за 150 мс. Картинка из памяти встаёт без
    /// анимации в любом случае — она есть уже на первом кадре.
    let appear: Animation?
    @ViewBuilder let content: (Image) -> Content
    /// Обложка книги — сгиб у корешка поверх картинки (`BookFigure`): вместе с ней
    /// он и проявляется, а пока её нет — его нет.
    @Environment(\.bookHingeWidth) private var hingeWidth
    /// Что показать, если картинки нет вовсе: у источника нет бандленного фолбэка,
    /// а живая не загрузилась. Нужен там, где вместо картинки уместен текст —
    /// логотип проекта заменяется его названием.
    @ViewBuilder let placeholder: () -> Placeholder

    /// Загруженная картинка. Достаётся из памяти **синхронно, в `init`** — иначе уже
    /// прогретая обложка моргает плейсхолдером на каждом монтировании вью: `.task`
    /// выполняется после первого рендера, и до неё кадр рисуется пустым.
    ///
    /// Раньше это было только обещанием в комментарии, а поймалось на возврате
    /// с экрана сущности: карточка пересоздаётся, и обложка на мгновение подменялась
    /// заливкой — меньшего размера и без скруглений (запись обратного зума, 30 к/с).
    @State private var loaded: Image?

    @MainActor
    init(
        source: ArtworkSource,
        appear: Animation? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.source = source
        self.appear = appear
        self.content = content
        self.placeholder = placeholder
        let warm = source.remoteURL.flatMap { ArtworkLoader.shared.cached($0) }
        _loaded = State(initialValue: warm.map { Image(uiImage: $0) })
    }

    var body: some View {
        Group {
            if let image = loaded ?? fallback {
                content(image)
                    .overlay(alignment: .leading) {
                        if let hingeWidth {
                            BookHingeShade.gradient
                                .frame(width: hingeWidth)
                                .allowsHitTesting(false)
                        }
                    }
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
                withAnimation(appear) {
                    loaded = Image(uiImage: image)
                }
            }
        }
    }

    private var fallback: Image? {
        guard let name = source.fallbackAsset else { return nil }
        return Image(name)
    }
}

extension ResolvedArtwork where Placeholder == Color {
    /// Пока картинки нет — бледный серый скелетона: серый в проекте один
    /// (решение 2026-10-03; здесь оставался прежний white 10 %, правка 2026-10-04).
    @MainActor
    init(source: ArtworkSource, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(source: source, content: content) { PlusSkeleton.fill }
    }
}
