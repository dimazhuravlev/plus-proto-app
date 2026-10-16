import SwiftUI
import UIKit

// MARK: - Геометрия

/// Числа из макета `2079:11226` (файл витрины). Холст макета — 375, прототип живёт
/// на 402 (база формул): кавер и карточка карусели масштабируются по ширине экрана
/// (`widthScale`, `CarouselFit`), поля 16 и зазоры — как есть.
enum AlbumLayout {
    /// Кавер `736:108655`: 247×247 на 402 и `247·k` на других ширинах (k — `widthScale`),
    /// скругление 18 масштабируется вместе с ним. Шапка вокруг него — общая с книгой
    /// (`EntityCoverHeader`, `EntityCoverLayout`).
    @MainActor
    static var coverSize: CGFloat { EntityCoverLayout.referenceCover * PlusMetrics.widthScale }
    @MainActor
    static var coverRadius: CGFloat { 18 * PlusMetrics.widthScale }

    /// Поля контента. У экрана альбома они 16, а не хромовые 24: так стоит
    /// и весь контент карточки фильма (`MovieLayout.sectionSide`).
    static let side: CGFloat = EntityCoverLayout.side

    // Треклист `2079:11230`
    static let rowHeight: CGFloat = 56
    /// Слот «популярный трек» перед номером — в макете пуст, но место держит
    static let popularWidth: CGFloat = 8
    static let numberWidth: CGFloat = 16
    static let titleLeading: CGFloat = 6
    static let moreBox: CGFloat = 20
    static let badgeBox: CGFloat = 16
    static let badgeGap: CGFloat = 4
    /// Отрицательный зазор двухстрочного текстового лейбла (`mb-[-2px]` в макете)
    static let textStackGap: CGFloat = EntityTitleLayout.textStackGap

    /// Дополнительный воздух под низом ленты, сверх клиренса хрома (правка
    /// пользователя 2026-08-29): последняя карточка не должна упираться в action bar.
    static let bottomClearance: CGFloat = 48

    // Секция «Другие альбомы» `2079:11242`
    static let sectionPad: CGFloat = 8
    static let sectionHeaderTop: CGFloat = 16
    static let sectionHeaderBottom: CGFloat = 12
    static let sectionTitleGap: CGFloat = 2
    static let sectionChevronBox: CGFloat = 20
    static let cardGap: CGFloat = 8

    /// Пороги навбара — общие с книгой, от верха названия (`EntityCoverLayout`).
    @MainActor
    static var navBarThresholds: EntityNavBarThresholds {
        EntityCoverLayout.navBarThresholds(coverHeight: coverSize)
    }
}

// Прежний одноразовый градиент пилюли «Слушать» (`Gradients/Yango/Accent`) заменён
// общим акцентным стилем ДС — `accentButtonSurface()` (правка пользователя 2026-08-25).

// MARK: - Экран

/// Экран альбома по макету `2079:11226`: резиновая шапка (фон-блюр и кавер тянутся
/// за оттягом), треклист и карусель других альбомов артиста. Данные живые —
/// `/album/{id}`, `/album/{id}/tracks` и `/artist/{id}/albums` Deezer
/// (см. `AlbumDetailsStore`); пока ответ едет, шапка стоит на данных витрины.
///
/// Кнопка «Слушать» играет альбом в музыкальном плеере action bar: тот же
/// `ActionBarState.open(.music(…))`, что и у карточки витрины, — повторный вызов
/// с тем же id работает как пауза.
struct AlbumScreen: View {
    let entity: EntityRef

    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store: AlbumDetailsStore
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollPosition = ScrollPosition()

    init(entity: EntityRef) {
        self.entity = entity
        // Детали уже в кэше — стоят с первого кадра, без скелетона в строке исполнителя.
        _store = State(initialValue: AlbumDetailsStore(entity: entity))
    }

    /// Что показывать прямо сейчас: живые детали, иначе заглушка по данным витрины.
    private var details: AlbumDetails {
        store.details ?? .placeholder(
            for: entity,
            mock: entity.deezerID == nil && AlbumDetailsStore.debugID == nil
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    trackList
                    if !details.others.isEmpty {
                        othersSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .task { await store.load(entity) }
            .scrollIndicators(.hidden)
            // Хром (таббар + action bar) на этом экране виден — лента едет под ним.
            .contentMargins(
                .bottom,
                PlusChromeMetrics.contentBottomInset + AlbumLayout.bottomClearance,
                for: .scrollContent
            )
            // Зона кавера начинается от физического верха экрана, а не от safe area.
            .ignoresSafeArea(edges: .top)
            .scrollPosition($scrollPosition)
            .trackNavBarScroll(into: $scrollOffset)
            #if DEBUG
            // `-debugScrollTo <pt>`: тот же приём, что на карточке фильма, — приход
            // данных пересобирает ленту и сбрасывает позицию, поэтому попыток десять.
            .task(id: store.details == nil) {
                let offset = UserDefaults.standard.double(forKey: "debugScrollTo")
                guard offset > 0 else { return }
                for _ in 0..<10 {
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled else { return }
                    scrollPosition.scrollTo(y: offset)
                }
            }
            #endif

            // Без правого слота: кнопка поиска из навбара убрана (правка пользователя
            // 2026-08-29) — поиск живёт в action bar, и вторая точка входа сверху
            // обещала бы поиск по альбому, которого нет.
            EntityNavBar(
                title: details.title,
                artwork: entity.artwork,
                scrollOffset: scrollOffset,
                thresholds: AlbumLayout.navBarThresholds
            )
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        #if DEBUG
        // `-debugTapPlay` — нажать «Слушать»: тот же флаг, что у «Смотреть»
        // на карточке фильма и «Читать» в книге.
        //
        // Срабатывает на КАЖДОМ экране альбома: жалоба пользователя 2026-08-29
        // воспроизводится именно вторым нажатием — на альбоме, открытом из выдачи.
        .task {
            guard UserDefaults.standard.bool(forKey: "debugTapPlay") else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            togglePlayback()
        }
        #endif
    }

    // MARK: Шапка

    /// Шапка — общая с книгой (`EntityHeader`): резиновая зона кавера (фон-блюр
    /// и кавер тянутся за оттягом) и блок названия — название, исполнитель, ряд действий.
    private var header: some View {
        EntityHeader(
            artwork: entity.artwork,
            coverSize: CGSize(width: AlbumLayout.coverSize, height: AlbumLayout.coverSize),
            scrollOffset: scrollOffset,
            title: details.title,
            collectionItem: collectionItem,
            onShare: share
        ) {
            cover
        } person: {
            if !details.artist.isEmpty {
                // Строка исполнителя — переход на его экран (2026-10-04), когда
                // известен его id: детали альбома пришли.
                Button(action: openArtist) {
                    // Имя и год проявляются вместе, когда детали пришли (или не придут):
                    // до этого на их месте две полосы скелетона, место под обе строки держится.
                    EntityPersonRow(
                        picture: artistAvatar,
                        name: artistRowReady ? details.artist : nil,
                        detail: artistRowReady ? details.year : nil,
                        isDetailLoading: !artistRowReady
                    )
                    .animation(reduceMotion ? nil : EntityMotion.reveal, value: artistRowReady)
                    .contentShape(.rect)
                }
                .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                .disabled(details.artistID == nil)
            }
        } primary: {
            EntityPrimaryButton(isPlaying: isPlayingThisAlbum, action: togglePlayback)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.fillNine)
                .frame(height: PlusMetrics.hairline)
        }
    }

    /// Альбом в коллекции «Моё» — его отмечают «нравится» и «скачать» шапки.
    private var collectionItem: CollectionItem {
        .album(EntityRef(
            id: entity.id,
            title: details.title,
            subtitle: details.artist.isEmpty ? entity.subtitle : details.artist,
            artwork: entity.artwork
        ))
    }

    /// «Поделиться»: карточка шеринга из того, что экран уже знает; детали не пришли —
    /// название и обложка из `entity`, подпись пустая.
    private func share() {
        ShareState.shared.present(.album(
            title: details.title,
            artist: details.artist,
            year: details.year,
            cover: entity.artwork,
            artistPicture: details.artistPicture
        ))
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: AlbumLayout.coverRadius, style: .continuous)
        return ArtworkImage(source: entity.artwork)
            .scaledToFill()
            .frame(width: AlbumLayout.coverSize, height: AlbumLayout.coverSize)
            .clipShape(shape)
            .coverBorder(shape)
    }

    /// Детали альбома разобраны, либо их не будет: не из Deezer (мок) или загрузка упала.
    private var artistRowReady: Bool {
        store.details != nil || entity.deezerID == nil || store.failure != nil
    }

    /// Аватар исполнителя: пока детали едут — скелетон круга (моковое фото здесь было
    /// бы чужим лицом); пришли — фото, а без фото у Deezer или при ошибке сети — аватарки нет
    /// (вечный скелетон — «мёртвый» элемент).
    private var artistAvatar: EntityPersonRow.Picture {
        if let picture = details.artistPicture { return .artwork(picture) }
        return artistRowReady ? .none : .loading
    }

    private func openArtist() {
        guard let id = details.artistID else { return }
        navigation.open(.artist(EntityRef(
            id: "dz-\(id)",
            title: details.artist,
            subtitle: "",
            artwork: details.artistPicture ?? .asset("")
        )))
    }

    /// Все треки альбома подряд: дисков в списке больше нет, а плееру они и не нужны.
    private var tracks: [AlbumDetails.Track] {
        details.allTracks
    }

    /// Идентификатор трека для плеера. `open` с тем же id работает как пауза,
    /// поэтому он обязан быть уникальным на трек, а не на альбом.
    private func playerID(_ track: AlbumDetails.Track) -> String {
        nowPlaying(track).id
    }

    private func nowPlaying(_ track: AlbumDetails.Track) -> MusicNowPlaying {
        details.nowPlaying(track, albumID: entity.id, cover: entity.artwork)
    }

    /// Признак принадлежности для бара: по нему кнопка узнаёт свой альбом (`isPlayingMusic`).
    private var containerID: String { "album:\(entity.id)" }

    /// Трек этого альбома, который сейчас в плеере, — играет он или стоит на паузе.
    private var currentTrack: AlbumDetails.Track? {
        guard actionBar.isMiniPlayerVisible, let id = actionBar.music?.id else { return nil }
        return tracks.first { playerID($0) == id }
    }

    /// Играет ли сейчас этот альбом — от этого зависят глиф и подпись пилюли.
    private var isPlayingThisAlbum: Bool {
        actionBar.isPlayingMusic(from: entity.id, kind: "album")
    }

    /// Что включает пилюля: трек, который уже стоит в плеере (тогда `open` работает
    /// как пауза или продолжение), иначе первый трек альбома — правка пользователя
    /// 2026-08-29: раньше кнопка играла «альбом целиком» одной записью.
    ///
    /// Пока треки не доехали, играем альбом как прежде: кнопка не имеет права быть
    /// мёртвой те секунды, что едет ответ Deezer.
    private var playButtonTarget: MusicNowPlaying {
        // Играет наш трек, а треклист ещё не доехал, — цель сам трек из бара: тот же id,
        // и `open` ставит на паузу, а не запускает альбом заново.
        if isPlayingThisAlbum, let current = actionBar.music {
            return current
        }
        if let track = currentTrack ?? tracks.first {
            return nowPlaying(track)
        }
        return MusicNowPlaying(
            id: entity.id,
            cover: entity.artwork,
            title: details.title,
            artist: details.artist,
            year: details.year,
            artistPicture: details.artistPicture,
            containerID: containerID
        )
    }

    private func togglePlayback() {
        play(playButtonTarget)
    }

    /// Тот же вход, что у карточки витрины: `open` с тем же id — пауза/продолжение,
    /// с другим — запуск. Хаптика — как у тапа по карточке.
    private func play(_ item: MusicNowPlaying) {
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
        // Очередь — треклист альбома: конец превью переключает на следующий трек.
        actionBar.open(.music(item), queue: tracks.map(nowPlaying))
    }

    // MARK: Треклист

    /// Список идёт сразу, без строки «Диск N» (правка пользователя 2026-08-29).
    /// Поэтому диски склеены в один ряд, а номер строки — сквозной: у Deezer
    /// `track_position` считается внутри диска, и без заголовков нумерация
    /// начиналась бы заново посреди списка.
    private var trackList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                trackRow(track, number: index + 1, isFirst: index == 0)
            }
        }
    }

    private func trackRow(_ track: AlbumDetails.Track, number: Int, isFirst: Bool) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: AlbumLayout.popularWidth, height: 1)

            Text("\(number)")
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillSubtitle)
                // Колонка макетных 16pt держит один знак; двузначный номер не переносим,
                // а даём выступить из кадра симметрично — выравнивание строк цело.
                .fixedSize()
                .frame(width: AlbumLayout.numberWidth)

            VStack(alignment: .leading, spacing: AlbumLayout.textStackGap) {
                HStack(spacing: AlbumLayout.badgeGap) {
                    Text(track.title)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)

                    if track.isExplicit {
                        explicitBadge
                    }
                }

                if let subtitle = track.subtitle {
                    Text(subtitle)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                }
            }
            .padding(.leading, AlbumLayout.titleLeading)

            Spacer(minLength: AlbumLayout.badgeGap)

            // Меню трека в прототипе не спроектировано — кнопка только откликается.
            Button {} label: {
                Image("iconMore")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: AlbumLayout.moreBox, height: AlbumLayout.moreBox)
                    // Белый 60 % из макета; токена нет — оттенок живёт только здесь
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .frame(height: AlbumLayout.rowHeight)
        .padding(.horizontal, AlbumLayout.side)
        .contentShape(Rectangle())
        // Проседает строка, а черты стоят: просевшая черта короче соседних и съезжает.
        // Палец на «ещё» достаётся кнопке — строка под ней не проседает.
        .pressScale(PressMotion.rowScale)
        .overlay(alignment: .bottom) { rowDivider }
        .overlay(alignment: .top) {
            if isFirst { rowDivider }
        }
        // Тап по строке включает этот трек (правка пользователя 2026-08-29).
        // Жестом, а не кнопкой: внутри строки уже живёт своя кнопка «ещё»,
        // и вложенная пара кнопок делит нажатие непредсказуемо.
        .onTapGesture { play(nowPlaying(track)) }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.fillNine)
            .frame(height: PlusMetrics.hairline)
            .padding(.horizontal, AlbumLayout.side)
    }

    /// Бейдж explicit — белый 30 % из макета, тот же в треке и карточке карусели.
    private var explicitBadge: some View {
        Image("iconExplicit")
            .renderingMode(.template)
            .resizable()
            .frame(width: AlbumLayout.badgeBox, height: AlbumLayout.badgeBox)
            .foregroundStyle(Color.white.opacity(0.3))
    }

    // MARK: Другие альбомы

    private var othersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AlbumLayout.sectionTitleGap) {
                Text("Другие альбомы")
                    .plusHeadline(.m)
                    .foregroundStyle(Color.fillOne)

                // Правый шеврон — отзеркаленный `icon / dropleft`: своего ассета нет,
                // а глиф тот же (приём «не плодить зеркальные ассеты»).
                Image("iconDropleft")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: AlbumLayout.sectionChevronBox, height: AlbumLayout.sectionChevronBox)
                    .scaleEffect(x: -1)
                    .foregroundStyle(Color.fillSubtitle)
                    .offset(y: PlusMetrics.headerChevronDrop)
            }
            .padding(.top, AlbumLayout.sectionHeaderTop)
            .padding(.bottom, AlbumLayout.sectionHeaderBottom)
            .padding(.horizontal, AlbumLayout.side)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: AlbumLayout.cardGap) {
                    ForEach(details.others) { album in
                        otherCard(album)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, AlbumLayout.side, for: .scrollContent)
        }
        .padding(.vertical, AlbumLayout.sectionPad)
    }

    /// Карточка — общая с «Альбомами» исполнителя (`EntityAlbumCard`): обложка
    /// на скелетоне, пока едет (2026-10-04). Переход — через навигацию, а не
    /// `NavigationLink`: альбом бывает и в слое фильма (поиском из бара его экранов),
    /// а у слоя стека нет — там переход встаёт в его стопку (`AppNavigationState.open`).
    private func otherCard(_ album: AlbumDetails.OtherAlbum) -> some View {
        // Ссылка на альбом: `title` — альбом, `subtitle` — исполнитель.
        let route = EntityRoute.album(EntityRef(
            id: "dz-\(album.id)",
            title: album.title,
            subtitle: details.artist,
            artwork: album.cover
        ))
        return Button { navigation.open(route) } label: {
            EntityAlbumCard(
                cover: album.cover,
                title: album.title,
                detail: album.year,
                isExplicit: album.isExplicit
            )
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
    }
}
