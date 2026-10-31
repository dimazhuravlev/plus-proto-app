import SwiftUI

/// Онбординг порядка блоков «Моего» (задача пользователя 2026-10-29): белая подсказка
/// под кнопкой «Изменить порядок» — один раз, при первом входе на экран. Не гаснет
/// от скролла; тап по ней — то же, что тап по кнопке (вход в режим порядка), и после
/// тапа по любой из двух она уходит. Уход с экрана тоже снимает её: показ уже засчитан.
///
/// Факт показа лежит на диске — в следующих запусках подсказки нет. Переключатель
/// дебаг-меню «каждую сессию» показывает её заново на каждом холодном запуске.
/// Состояние — вне экрана: корень таба размонтируется на каждом переключении.
@MainActor
@Observable
final class CollectionReorderHint {
    static let shared = CollectionReorderHint()

    /// Подсказку уже показывали — на диске, переживает перезапуск.
    static let shownKey = "collectionReorderHintShown"
    /// Переключатель дебаг-меню: показывать в каждой сессии, а не один раз.
    static let everySessionKey = "collectionReorderHintEverySession"

    /// Ждёт показа → на экране → снята. Три состояния, а не флаг: появляется подсказка
    /// подъёмом, а уходит уменьшением с блюром — у «до» и «после» свой вид.
    enum Phase {
        case waiting, shown, dismissed
    }

    private(set) var phase: Phase = .waiting
    /// Показана в этом процессе — режим «каждую сессию» второй раз за запуск её не зовёт.
    @ObservationIgnored private var shownThisSession = false

    private init() {
        #if DEBUG
        // `-debugResetCollection 1` — подсказка снова не показана, как на первом запуске.
        if UserDefaults.standard.bool(forKey: "debugResetCollection") {
            UserDefaults.standard.removeObject(forKey: Self.shownKey)
        }
        #endif
    }

    /// Пора ли показать: в этом запуске ещё не было, и либо режим «каждую сессию»,
    /// либо её не показывали никогда.
    var isDue: Bool {
        guard !shownThisSession else { return false }
        return UserDefaults.standard.bool(forKey: Self.everySessionKey)
            || !UserDefaults.standard.bool(forKey: Self.shownKey)
    }

    /// Показ засчитывается сразу — и в этом запуске, и на диске.
    func present() {
        guard isDue else { return }
        shownThisSession = true
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        phase = .shown
    }

    func dismiss() {
        guard phase == .shown else { return }
        phase = .dismissed
    }

    /// Экран ушёл: подсказка снимается без анимации — на возврате её место пустое,
    /// а не догасающее.
    func dismissInstantly() {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { dismiss() }
    }
}

/// Числа подсказки — `hint` `18751:265838` файла «ЯПС · Mobile · Current State»
/// (основная подсказка ДС, хвостик сверху по центру). Кнопка на кадре 375 — 263…303 ×
/// 62…102, подсказка — 204…362 с 105: ровно по центру кнопки, на 3 ниже её кадра.
enum CollectionReorderHintLayout {
    /// Ширина макета: текст 126 и поля 16 — фраза в две строки.
    static let width: CGFloat = 158
    static let padding: CGFloat = 16
    static let radius: CGFloat = 12
    /// Хвостик `hint / corner` — 24 × 9 над верхней кромкой.
    static let corner = CGSize(width: 24, height: 9)
    /// От низа кадра кнопки до верха подсказки.
    static let gap: CGFloat = 3
    /// Тени макета `0 4 24` чёрным 12 % и `0 12 32` чёрным 16 % (радиус SwiftUI —
    /// половина блюра Фигмы).
    static let nearShadowOpacity: Double = 0.12
    static let nearShadowRadius: CGFloat = 12
    static let nearShadowY: CGFloat = 4
    static let farShadowOpacity: Double = 0.16
    static let farShadowRadius: CGFloat = 16
    static let farShadowY: CGFloat = 12
}

enum CollectionReorderHintMotion {
    /// Пауза после входа на экран: подсказка проявляется на уже стоящем экране,
    /// а не вместе с ним — так её замечают.
    static let delay: Duration = .milliseconds(500)
    /// Подъём на 4 снизу вверх вместе с проявлением (просьба пользователя 2026-10-29).
    static let rise: CGFloat = 4
    /// Появление — неспешное ease-in-out: сильный ease-out (0.23, 1, 0.32, 1, 0.3 с)
    /// проявлял подсказку почти целиком за первые кадры, и она возникала рывком
    /// (жалоба пользователя 2026-10-29).
    static let appear: Animation = .easeInOut(duration: 0.4)
    /// Уход — прозрачность, уменьшение к хвостику и блюр одной кривой (просьба
    /// пользователя 2026-10-29); чуть быстрее появления — это ответ на тап.
    static let disappear: Animation = .easeInOut(duration: 0.3)
    static let dismissedScale: CGFloat = 0.9
    static let dismissedBlur: CGFloat = 8
    /// Reduce Motion: только прозрачность, без сдвига, масштаба и блюра.
    static let reducedFade: Animation = .easeInOut(duration: 0.2)
}

/// Сама подсказка. Всегда в дереве — меняются прозрачность, сдвиг, масштаб и блюр:
/// появление и уход — анимацией модификаторов, без вставки вью.
struct CollectionReorderHintBubble: View {
    let phase: CollectionReorderHint.Phase
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias L = CollectionReorderHintLayout
    private typealias M = CollectionReorderHintMotion

    var body: some View {
        Button(action: action) {
            Text("Наведите здесь свой порядок")
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillInverted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(L.padding)
                .frame(width: L.width)
                .fixedSize(horizontal: false, vertical: true)
                // Тени — каждая на своей копии подложки: вторая `.shadow` поверх первой
                // отбросила бы тень и от тени.
                .background {
                    ZStack {
                        surface
                            .shadow(color: .black.opacity(L.nearShadowOpacity), radius: L.nearShadowRadius, y: L.nearShadowY)
                        surface
                            .shadow(color: .black.opacity(L.farShadowOpacity), radius: L.farShadowRadius, y: L.farShadowY)
                    }
                }
                .contentShape(.rect(cornerRadius: L.radius, style: .continuous))
                // Гаснет целиком: без группы белые копии подложки просвечивали бы
                // друг через друга, пока прозрачность не дошла до края.
                .compositingGroup()
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
        // Уменьшается к хвостику — к кнопке, на которую указывает.
        .scaleEffect(isDismissed && !reduceMotion ? M.dismissedScale : 1, anchor: .top)
        .blur(radius: isDismissed && !reduceMotion ? M.dismissedBlur : 0)
        .opacity(isShown ? 1 : 0)
        .offset(y: phase == .waiting && !reduceMotion ? M.rise : 0)
        .animation(animation, value: phase)
        .allowsHitTesting(isShown)
        .accessibilityHidden(!isShown)
    }

    private var isShown: Bool { phase == .shown }
    private var isDismissed: Bool { phase == .dismissed }

    private var animation: Animation? {
        if reduceMotion { return M.reducedFade }
        switch phase {
        case .waiting: return nil
        case .shown: return M.appear
        case .dismissed: return M.disappear
        }
    }

    /// Белая плашка с хвостиком — одной группой: тень хвостика не ложится на плашку.
    private var surface: some View {
        RoundedRectangle(cornerRadius: L.radius, style: .continuous)
            .fill(Color.surfaceInverted)
            .overlay(alignment: .top) {
                // Ассет хвостика смотрит вниз — в макете он повёрнут на 180°.
                Image("iconHintCorner")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(Color.surfaceInverted)
                    .frame(width: L.corner.width, height: L.corner.height)
                    .rotationEffect(.degrees(180))
                    .offset(y: -L.corner.height)
                // Высота SVG — ровно 9: экспорт Фигмы давал 9.00016, каталог растрировал
                // его в 28 px на @3x вместо 27, и между хвостиком и плашкой шла чёрная
                // полоса в пиксель (жалоба пользователя 2026-10-29).
            }
            .compositingGroup()
    }
}
