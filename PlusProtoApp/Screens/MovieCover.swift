import SwiftUI

// MARK: - Логотип тайтла

/// Геометрия логотипа из `figma-moviecard.md` §2.2 (секция «Логотипы» `3826:37555`).
enum MovieLogoLayout {
    /// Бокс логотипа в шапке: left 20 / top 63 (высота статус-бара)
    static let leading: CGFloat = 20
    static let top: CGFloat = 63
    /// Квадратным лого считается при пропорции меньше 1.2 — тогда бокс 88×88
    static let squareRatio: CGFloat = 1.2
    static let squareBox = CGSize(width: 88, height: 88)
    /// Длинное лого — 188×64
    static let longBox = CGSize(width: 188, height: 64)
}

/// Логотип тайтла в шапке карточки — PNG с альфой из Кинопоиска (`logo.url`).
///
/// Второй половины правила макета («лого нет — текстовое название») здесь нет
/// намеренно: у нас название в этом случае занимает слот лида, как было до логотипов.
/// Рисовать его ещё и в шапке значило бы показать название дважды.
///
/// Натуральный размер картинки нужен, чтобы выбрать бокс (квадратный или длинный),
/// поэтому логотип грузится напрямую через `ArtworkLoader`, а не через `ArtworkImage`:
/// тот отдаёт готовый `Image` и размеров не показывает. Читать размер отрисованной вью
/// нельзя — от него зависит её же раскладка (DECISIONS).
struct MovieTitleLogo: View {
    let url: URL
    let title: String

    @State private var image: Image?
    @State private var natural: CGSize?

    var body: some View {
        // Бокс держится распоркой, а не самой картинкой. Не украшательство: `.task`
        // на пустом теле не выполняется вовсе — вью, у которой нечего рисовать, SwiftUI
        // не создаёт, и логотип, ждущий загрузки внутри собственной задачи, не грузится
        // никогда. На этом уже потерян один заход.
        Color.clear
            .frame(width: box.width, height: box.height)
            .overlay(alignment: .bottomLeading) {
                // Пока логотип едет — пусто: подменять его чем-то, а через полсекунды
                // картинкой, значит дёргать шапку на каждом входе.
                if let image {
                    image
                        .resizable()
                        .frame(width: drawn.width, height: drawn.height)
                        .accessibilityLabel(title)
                }
            }
            .task(id: url) { await load() }
    }

    /// Бокс по пропорции логотипа. До загрузки — длинный: почти все логотипы тайтлов
    /// это широкие начертания названия.
    private var box: CGSize {
        guard let natural, natural.height > 0 else { return MovieLogoLayout.longBox }
        let ratio = natural.width / natural.height
        return ratio < MovieLogoLayout.squareRatio ? MovieLogoLayout.squareBox : MovieLogoLayout.longBox
    }

    /// Размер самой картинки в боксе. Считаем сами, а не `scaledToFit`: тот оставляет
    /// вью размером с бокс, и картинка внутри него оказывается по центру — а в макете
    /// логотип прижат к низу бокса (VStack `justify=MAX`).
    private var drawn: CGSize {
        guard let natural, natural.width > 0, natural.height > 0 else { return box }
        let scale = min(box.width / natural.width, box.height / natural.height)
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }

    private func load() async {
        if let hit = ArtworkLoader.shared.cached(url) {
            image = Image(uiImage: hit)
            natural = hit.size
            return
        }
        image = nil
        natural = nil
        guard let loaded = await ArtworkLoader.shared.image(for: url) else { return }
        image = Image(uiImage: loaded)
        natural = loaded.size
    }
}

// MARK: - Кавер с трейлером

/// Кавер карточки тайтла: постер, поверх которого автоматически запускается
/// зацикленный беззвучный ролик (макет §5.4 — «зацикливаем воспроизведение трейлера»).
///
/// Настоящий трейлер Кинопоиска сюда не доезжает: API отдаёт не файл, а страницу своего
/// плеера, и подписанный поток внутри неё закрыт для сторонних клиентов (см.
/// `KinopoiskVideo`). Поэтому движущаяся картинка — забандленный клип, а из API живут
/// имя ролика и его кадр. Как только `trailer.stream` окажется непустым, играть будет он:
/// ветка одна, мёртвого кода нет.
struct MovieTrailerCover: View {
    /// Постер сущности: с него же собран зум-переход с витрины, подменять нельзя.
    let poster: ArtworkSource
    let trailer: MovieTrailer?

    @State private var playback = LoopingVideoPlayback()
    @State private var isVideoReady = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            ArtworkImage(source: poster)
                .scaledToFill()

            if reduceMotion {
                // Движение выключено — вместо ролика его собственный кадр из API.
                if let frame = trailer?.poster {
                    ArtworkImage(source: .remote(frame))
                        .scaledToFill()
                }
            } else {
                LoopingVideoLayer(player: playback.queue) { isVideoReady = true }
                    .opacity(isVideoReady ? 1 : 0)
                    // Постер уступает место видео мягко: жёсткая подмена читается щелчком.
                    .animation(.easeInOut(duration: MovieCoverMotion.videoFadeIn), value: isVideoReady)
                    .allowsHitTesting(false)
            }
        }
        .task(id: trailer?.stream) { start() }
        .onDisappear { playback.pause() }
        // Экран ушёл в фон — клип обязан встать, иначе он крутится вхолостую.
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? start() : playback.pause()
        }
    }

    private func start() {
        guard !reduceMotion else { return }
        if let stream = trailer?.stream {
            playback.start(url: stream)
        } else {
            playback.start(bundled: ShowcaseSeeds.trailerClip)
        }
    }
}

enum MovieCoverMotion {
    /// Проявление видео поверх постера
    static let videoFadeIn: Double = 0.4
}
