import SwiftUI
import UIKit

@main
struct PlusProtoAppApp: App {
    init() {
        FontManager.registerFonts()
        UIWindow.appearance().backgroundColor = .black
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Композиционный корень: здесь живут глобальные состояния и фиксированный хром.
struct AppRootView: View {
    @State private var activeTab: AppTab = .plus

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Контент таба. Переключение мгновенное — анимируется только таббар.
            switch activeTab {
            case .plus:
                ShowcaseScreen()
            case .music, .kinopoisk, .books, .alisa:
                ServiceStubScreen(tab: activeTab)
            }
        }
    }
}

/// Пять сервисов супераппа. Порядок — как в макете (слева направо).
enum AppTab: Int, CaseIterable, Identifiable {
    case plus, music, kinopoisk, books, alisa

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .plus: "Плюс"
        case .music: "Музыка"
        case .kinopoisk: "Кинопоиск"
        case .books: "Книги"
        case .alisa: "Алиса"
        }
    }
}

/// Заглушка сервисного таба — внутренние разделы сервисов пока не проектируем.
struct ServiceStubScreen: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text(tab.title)
                .plusHeadline()
                .foregroundStyle(Color.fillSix)
        }
    }
}

/// Витрина «Плюс» — кросс-сервисная лента. Пока каркас, наполняется на этапе 5.
struct ShowcaseScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Витрина Плюс")
                .plusHeadline()
                .foregroundStyle(Color.fillOne)
        }
    }
}
