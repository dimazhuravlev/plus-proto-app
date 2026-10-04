import SwiftUI

/// Витрина «Плюс» — главный экран супераппа.
struct ShowcaseScreen: View {
    /// Каталог живёт в корне приложения, а не здесь: витрина размонтируется
    /// на каждом переключении таба, и вместе с её `@State` пропадала бы вся лента —
    /// на возврате собирался бы другой фильм, другой альбом и другие книги, да ещё
    /// и новыми запросами (задача 2026-08-27: контент не должен перезагружаться).
    @Environment(ShowcaseCatalog.self) private var catalog
    /// Namespace зум-перехода — общий с выдачей поиска, из корня: экран, открытый
    /// из выдачи, разворачивается из её карточки и сворачивается обратно в неё.
    /// Свой — только запасной, если корня нет (превью).
    @Environment(\.stackZoomNamespace) private var stackZoom
    @Namespace private var ownZoom
    private var zoom: Namespace.ID { stackZoom ?? ownZoom }

    #if DEBUG
    @Environment(AppNavigationState.self) private var navigation
    @MainActor private static var didDebugPerson = false
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ShowcaseFeedView(feed: catalog.feed, zoom: zoom, prepareReplacement: catalog.prepareReplacement)
        }
        #if DEBUG
        // `-debugPerson <artist|director|writer>` — открыть экран персоны: The Weeknd,
        // Альфред Хичкок (персона Кинопоиска известна) или Михаил Булгаков (по имени,
        // без фото — его экран ищет сам). Тапнуть по выдаче из шелла нечем. Раз за запуск.
        .task {
            guard let role = UserDefaults.standard.string(forKey: "debugPerson"), !Self.didDebugPerson else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, !Self.didDebugPerson else { return }
            Self.didDebugPerson = true
            switch role {
            case "artist":
                navigation.open(.artist(EntityRef(
                    id: "dz-4050205",
                    title: "The Weeknd",
                    subtitle: "",
                    artwork: .remote(URL(string: "https://cdn-images.dzcdn.net/images/artist/581693b4724a7fcfa754455101e13a44/1000x1000-000000-80-0-0.jpg")!)
                )))
            case "director":
                navigation.open(.director(EntityRef(id: "kp-156444", title: "Альфред Хичкок", subtitle: "", artwork: .asset(""))))
            case "writer":
                navigation.open(.writer(EntityRef(id: "name-Михаил Булгаков", title: "Михаил Булгаков", subtitle: "", artwork: .asset(""))))
            default:
                break
            }
        }
        #endif
        // Куда ведут карточки — экраны сущностей и слой фильма — объявлено на корне
        // стека каждого таба (`EntityDestinations`), а не здесь: поиск открывается
        // на любом табе, и его карточки обязаны открываться везде.
        // Загрузку витрины держит корень (`AppRootView`): пока она идёт, на экране
        // стоит заставка, а этот экран за своё время жизни не отвечает — его
        // размонтирует переключение таба.
    }
}
