import SwiftUI

/// Витрина «Плюс» — кросс-сервисная лента. Пока каркас, наполняется на Этапе 5.
struct ShowcaseScreen: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Витрина Плюс")
                .plusHeadline()
                .foregroundStyle(Color.fillOne)

            // ATOMS-CATALOG: временная вставка этапа 1 — удалить блоком целиком на этапе 5
            #if DEBUG
            if UserDefaults.standard.string(forKey: "debugActionBar") == nil {
                AtomsCatalogScreen()
            }
            #endif
        }
    }
}
