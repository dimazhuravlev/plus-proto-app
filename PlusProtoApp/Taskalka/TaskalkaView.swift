import SwiftUI

/// Таскалка — экспериментальный UI пустого поиска (задача пользователя 2026-10-31, флаг
/// `TaskalkaDebug`): вместо «Искали недавно» и рекомендаций — поле настроения.
///
/// **Что это.** Когда не знаешь, что искать, — а с пустым полем поиска так почти всегда, —
/// вместо набора текста настроение задаётся пальцем. Поле — соты из 17 настроений: сверху движ, снизу чилл,
/// слева мрак, справа свет (`TaskalkaMood`). Палец дописывает фразу
/// «Хочется чего-нибудь …»; отпустил — выбор сделан, снизу выезжает подборка трёх сервисов:
/// плейлист этого настроения, кино и книги (`TaskalkaSheet`).
///
/// **Флоу.** Касание опускает клавиатуру — поле стоит во всю высоту до бара всегда и под
/// клавиатурой просто было скрыто (правка пользователя 2026-10-31), так что ничего под
/// пальцем не переезжает. Ведение — точки под пальцем набухают до предела цветом настроения (шара нет),
/// слово и подпись сменяются через блюр, хаптика — тиками по точкам и «туком» на смене
/// слова. Отпускание — точки опадают вполовину, подборка выезжает. Назад к полю — свайп
/// шторки вниз или тап по фразе; место выбора остаётся, новое касание перетекает к пальцу.
/// Закрытый поиск начинает с чистого поля.
struct TaskalkaView: View {
    let open: (EntityRoute) -> Void

    @Environment(ActionBarState.self) private var actionBar
    @Environment(SearchState.self) private var search
    @Environment(KeyboardObserver.self) private var keyboard

    #if DEBUG
    @MainActor private static var didDebugPick = false
    #endif

    var body: some View {
        ZStack(alignment: .top) {
            TaskalkaCard()
                .padding(.horizontal, TaskalkaLayout.side)
                .padding(.top, TaskalkaLayout.top)
                .padding(.bottom, TaskalkaLayout.bottomInset)

            TaskalkaSheet(open: open)
                .padding(.top, TaskalkaLayout.top + TaskalkaLayout.headerHeight)
        }
        // Фокус в поле поиска при открытой подборке — человек пошёл искать словами:
        // шторка уезжает, пока поднимается клавиатура (правка пользователя 2026-11-01).
        // Без своей хаптики — это не жест по шторке.
        .onChange(of: actionBar.isSearchFocused) { _, focused in
            if focused { TaskalkaSession.shared.closeSheet(haptic: false) }
        }
        .onDisappear {
            // Слой ушёл, а поиск открыт — набран запрос, Таскалка вернётся с ним же.
            // Закрыт — следующий поиск с чистого поля.
            let isSearchOpen = actionBar.isSearchFocused || search.isBrowsing || search.isSuspended
            if !isSearchOpen { TaskalkaSession.shared.reset() }
        }
        #if DEBUG
        // `-debugTaskalkaPick <tense|energetic|joyful|mysterious|curious|romantic|sad|calm|cozy>` —
        // выбрать настроение без пальца, как отпускание в центре его зоны: клавиатура
        // уходит, подборка выезжает. Один раз за запуск.
        .task {
            guard let raw = UserDefaults.standard.string(forKey: "debugTaskalkaPick"),
                  let id = TaskalkaMood.ID(rawValue: raw),
                  !Self.didDebugPick
            else { return }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, !Self.didDebugPick else { return }
            Self.didDebugPick = true
            if actionBar.isSearchFocused { keyboard.dismissSmoothly() }
            TaskalkaSession.shared.choose(.with(id))
        }
        #endif
    }
}
