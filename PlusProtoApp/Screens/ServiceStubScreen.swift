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
    }
}
#endif
