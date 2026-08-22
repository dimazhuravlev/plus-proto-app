import SwiftUI

/// Витрина «Плюс» — кросс-сервисная лента. Пока каркас, наполняется на Этапе 5.
struct ShowcaseScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ATOMS-CATALOG: временная вставка этапа 1 — удалить блоком целиком на этапе 5
            #if DEBUG
            if UserDefaults.standard.string(forKey: "debugActionBar") == nil {
                AtomsCatalogScreen()
            } else {
                ShowcaseScrollProbe()
            }
            #else
            ShowcaseScrollProbe()
            #endif
        }
    }
}

/// ВРЕМЕННОЕ (удалить на Этапе 5 вместе с ATOMS-CATALOG): цветные блоки вместо карточек.
/// Нужны, чтобы проверить скролл и то, как контент уходит под нижний хром:
/// лента едет под таббар, а в покое из-под него выходит благодаря
/// `contentMargins(.bottom, PlusChromeMetrics.contentBottomInset)` в `AppRootView`.
private struct ShowcaseScrollProbe: View {
    /// Блоки разной высоты — так заметнее, где именно контент уходит под скрим.
    private let blocks: [(color: Color, height: CGFloat, title: String)] = [
        (Color(red: 0.85, green: 0.28, blue: 0.35), 220, "Кино"),
        (Color(red: 0.30, green: 0.55, blue: 0.90), 300, "Музыка"),
        (Color(red: 0.25, green: 0.70, blue: 0.55), 180, "Книги"),
        (Color(red: 0.95, green: 0.65, blue: 0.20), 260, "Моя Волна"),
        (Color(red: 0.60, green: 0.35, blue: 0.85), 240, "Продолжить смотреть"),
        (Color(red: 0.90, green: 0.45, blue: 0.65), 200, "Продолжить читать"),
        (Color(red: 0.35, green: 0.75, blue: 0.85), 280, "Подборка"),
        (Color(red: 0.55, green: 0.60, blue: 0.30), 220, "Последний блок"),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Text("Витрина Плюс")
                    .plusHeadline()
                    .foregroundStyle(Color.fillOne)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    RoundedRectangle(cornerRadius: PlusRadius.card, style: .continuous)
                        .fill(block.color)
                        .frame(height: block.height)
                        .overlay(alignment: .topLeading) {
                            Text("\(index + 1). \(block.title)")
                                .plusTextM()
                                .foregroundStyle(.black.opacity(0.7))
                                .padding(12)
                        }
                }
            }
            .padding(.horizontal, PlusMetrics.screenMargin)
        }
    }
}
