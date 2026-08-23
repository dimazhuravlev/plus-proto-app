import SwiftUI

/// Заглушка сервисного таба — внутренние разделы сервисов пока не проектируем.
struct ServiceStubScreen: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(tab.title)
                    .plusHeadline()
                    .foregroundStyle(Color.fillSix)

                #if DEBUG
                // Проверка каркаса: пуш живёт в стеке своего таба и переживает переключение
                // табов. Удалить, когда у сервисных табов появится содержимое.
                NavigationLink(value: ServiceStubRoute.detail(tab)) {
                    Text("Проверить стек")
                        .plusTextM()
                        .foregroundStyle(Color.plusAccent)
                }
                #endif
            }
        }
        .overlay(alignment: .top) {
            // «Пустой» вариант: сущности у заглушки нет, скролла тоже — поэтому
            // название раздела и подложка стоят на месте (`.pinned`).
            // На корне стека `dismiss()` — no-op: кнопка здесь стоит стендом,
            // рабочей она становится на пуше (`ServiceStubDetailScreen`).
            EntityNavBar(title: tab.title, thresholds: .pinned)
        }
        // Системный бар выключен: сверху стоит свой (приём `NavBar` MusicPlayer).
        .toolbar(.hidden, for: .navigationBar)
        #if DEBUG
        .navigationDestination(for: ServiceStubRoute.self) { route in
            switch route {
            case .detail(let tab):
                ServiceStubDetailScreen(tab: tab)
            }
        }
        #endif
    }
}

#if DEBUG
enum ServiceStubRoute: Hashable {
    case detail(AppTab)
}

private struct ServiceStubDetailScreen: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Пуш в стеке «\(tab.title)»")
                .plusTextM()
                .foregroundStyle(Color.fillOne)
        }
        .overlay(alignment: .top) {
            EntityNavBar(title: tab.title, thresholds: .pinned)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
#endif
