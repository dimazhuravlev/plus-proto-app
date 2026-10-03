import SwiftUI
import UIKit
import VariableBlur

/// Геометрия нижнего хрома. Все числа — из спек: figma-tabbar §2/§7, figma-screen1 §4.
enum PlusChromeMetrics {
    /// Ряд табов: padding-top 4 + кнопки 62 (figma-tabbar §2)
    static let tabsRowHeight: CGFloat = 66
    static let tabsRowTopPadding: CGFloat = 4

    /// Зазор между нижней кромкой action bar (y 2084) и фреймом таббара (y 2088) — figma-screen1 §4
    static let actionBarToTabsGap: CGFloat = 4

    /// Сколько хром занимает над safe area: 60 + 4 + 66. На iPhone с home indicator 34pt
    /// это те самые 164pt от низа экрана, которые в figma-screen1 §4 должна очистить лента.
    static var contentBottomInset: CGFloat {
        PlusMetrics.actionBarHeight + actionBarToTabsGap + tabsRowHeight
    }

    /// Радиус прогрессивного блюра под нижним хромом — общий у таббара и панели кнопок
    /// карточки тайтла. В Figma слой блюра есть, но выставлен в 0; прежняя десятка была
    /// взята из `BottomBarV2` MusicPlayer, 8 — правка пользователя 2026-08-25.
    static let underlayBlurRadius: CGFloat = 8

    /// Отступ от клавиатуры до низа action bar при фокусе поиска (`2021:11248`).
    static let focusKeyboardGap: CGFloat = 12

    /// На сколько опускается бар в просмотре выдачи без клавиатуры: таббара там нет,
    /// и бар встаёт на его место — низом на нижнюю безопасную зону, где стоят низы
    /// кнопок табов (правка пользователя 2026-10-03).
    static var browsingDrop: CGFloat {
        tabsRowHeight + actionBarToTabsGap
    }

    /// Высота слоя блюра — **ниже градиента**: размытие должно начинаться примерно
    /// с середины action bar, иначе лента мылится ещё до того, как заедет под хром.
    /// Считается от физического низа: safe area + ряд табов + зазор + половина бара.
    static var underlayBlurHeight: CGFloat {
        bottomSafeArea + tabsRowHeight + actionBarToTabsGap + PlusMetrics.actionBarHeight / 2
    }

    /// Нижняя безопасная зона — блюр отмеряется от физического низа экрана,
    /// а высота home indicator зависит от устройства.
    static var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0
    }

    // MARK: - Верхний скрим

    /// Затемнения у скрима нет — только блюр. В макете под навбаром витрины градиент
    /// `overlay bg` (`2004:10781`, figma-screen1 §4: 72pt, чёрный 50 % → прозрачный),
    /// пользователь сперва ослабил его до 25 %, затем убрал совсем (2026-10-03).
    ///
    /// Два слоя блюра разной высоты и радиуса — приём `TopNavBarBackground` из MusicPlayer:
    /// слабый и высокий даёт мягкий заход, сильный и низкий — плотность у самого верха.
    /// Выше 72pt не поднимаемся: в MusicPlayer блюр перекрывал градиент, но там под ним
    /// был только скролл, а здесь на 72pt начинается заголовок витрины — более высокий
    /// слой мылил бы его в покое.
    static let topScrimBlurSoft: (radius: CGFloat, height: CGFloat) = (4, 72)
    static let topScrimBlurStrong: (radius: CGFloat, height: CGFloat) = (14, 54)
}

/// Мягкий уход клавиатуры, который запускаем мы сами (`KeyboardObserver.dismissSmoothly`).
///
/// Система на скролле (`scrollDismissesKeyboard`) и SwiftUI на снятии фокуса убирают
/// клавиатуру рывком — путь ~0.37s, но перегружен в начало: половина за 66 мс,
/// 91 % за 166 мс (замер 2026-10-03), — и нотификация о таком уходе приходит с нулевой
/// длительностью. Снятый внутри `UIView.animate` фокус клавиатура слушается и уезжает
/// заданной анимацией (проверено покадрово 2026-10-03), а нотификация по-прежнему
/// рапортует ноль — поэтому бару ту же кривую отдаём сами.
enum KeyboardDismissMotion {
    /// Длительность ухода: вдвое дольше системного, но всё ещё в пределах UI-перехода.
    static let duration: TimeInterval = 0.4
    /// Кривая бара — `UIView.AnimationOptions.curveEaseInOut` в кубических
    /// коэффициентах UIKit: бар едет ровно так же, как клавиатура под ним.
    static let bar: Animation = .timingCurve(0.42, 0, 0.58, 1, duration: duration)
}

enum BottomChromeMotion {
    /// Таббар, уходя, ещё и проседает: бар опускается на его место, и встречное
    /// движение читается как «уступил место», а не как два слоя друг в друге.
    static let tabBarHideOffset: CGFloat = 16
}

enum TopScrimMotion {
    /// Скрим уходит и возвращается вместе с пушем экрана со своим навбаром —
    /// коротким фейдом под зум-переход, а не щелчком на первом кадре.
    static let fade: Animation = .easeInOut(duration: 0.25)
}

/// Верхний скрим: лента уезжает под статус-бар, поэтому его надо размыть.
/// Отдельный слой поверх контента, вне `NavigationStack` — как и нижний хром.
/// Виден только на витрине: у экранов со своим навбаром блюр — его подложка.
struct TopScrim: View {
    var body: some View {
        ZStack(alignment: .top) {
            VariableBlurView(
                maxBlurRadius: PlusChromeMetrics.topScrimBlurSoft.radius,
                direction: .blurredTopClearBottom
            )
            .frame(height: PlusChromeMetrics.topScrimBlurSoft.height)

            VariableBlurView(
                maxBlurRadius: PlusChromeMetrics.topScrimBlurStrong.radius,
                direction: .blurredTopClearBottom
            )
            .frame(height: PlusChromeMetrics.topScrimBlurStrong.height)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .top)
    }
}

/// Фиксированный нижний хром. Живёт в ZStack корня, **вне** `NavigationStack` — внутри
/// он ездил бы вместе с пушами.
struct BottomChrome: View {
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(SearchState.self) private var search

    var body: some View {
        VStack(spacing: PlusChromeMetrics.actionBarToTabsGap) {
            // Поднимается только бар. Таббар остаётся на своём месте и уходит
            // под клавиатуру — гасить его не нужно (решение пользователя 2026-08-23);
            // исключение — выдача поиска, см. `isTabBarHidden`.
            // Подъём уехал ВНУТРЬ бара: он обязан висеть на общем предке обеих зон
            // под той же единственной анимацией, что и ширины зон и уезд плеера.
            ActionBarView(raise: raise)

            TabBarView()
                .opacity(isTabBarHidden ? 0 : 1)
                .offset(y: isTabBarHidden ? BottomChromeMotion.tabBarHideOffset : 0)
                // Той же кривой, что едет бар: таббар уходит, пока бар опускается
                // на его место, и возвращается, пока бар поднимается обратно.
                .animation(keyboard.motion ?? ActionBarMotion.morph, value: isTabBarHidden)
                .allowsHitTesting(!actionBar.isSearchFocused && !isTabBarHidden)
        }
        // Системный подъём над клавиатурой выключен: SwiftUI поднял бы весь хром
        // вместе с таббаром, да ещё и сложился бы с нашим сдвигом — бар улетал вдвое выше.
        //
        // Отдать подъём системной безопасной зоне пробовали (2026-08-23): таббар и бар
        // разнесли по разным слоям, зону погасили только у таббара. Бар при этом улетел
        // выше экрана и пропал — сдвиг сложился вдвое ровно так, как описано выше.
        // Синхрон с клавиатурой добираем её собственной кривой, см. `KeyboardObserver`.
        .ignoresSafeArea(.keyboard)
    }

    /// Таббара нет, пока открыт поиск: внизу только бар (правка пользователя
    /// 2026-10-03). В фокусе он гаснет под клавиатурой — поэтому, когда клавиатуру
    /// опускают в просмотр, под ней уже пусто и мелькать нечему. С пустым полем — так
    /// же: на экране «Искали недавно», и его просмотр без клавиатуры — тот же, что
    /// у выдачи (прежде таббар с пустым запросом стоял под клавиатурой, 2026-08-23).
    private var isTabBarHidden: Bool {
        search.isBrowsing || actionBar.isSearchFocused
    }

    /// Просмотр выдачи — или вот-вот он: клавиатура уже уехала, а фокус ещё не снят.
    /// UIKit сообщает об уходе клавиатуры раньше, чем SwiftUI снимает фокус, и без
    /// этого бар на кадр брал раскладку режима с плеером и тут же разворачивался
    /// обратно. Уход в карточку (отметка) сюда не попадает; выход из поиска — тоже:
    /// «Назад» и затемнение снимают фокус в `actionBar` раньше, чем уходит клавиатура.
    ///
    /// Только пока клавиатура **уезжает** (`motion` есть, а `isUp` уже нет): на подъёме
    /// окно то же — фокус есть, клавиатуры ещё нет, — и свежий фокус пустого поля
    /// сперва опускал бар к месту таббара, а потом поднимал над клавиатурой (ревью
    /// 2026-10-03). Прежде это окно закрывал непустой запрос — с «Искали недавно»
    /// его нет.
    private var isBrowsingLayout: Bool {
        search.isBrowsing
            || (actionBar.isSearchFocused && !search.isSuspended && keyboard.motion != nil)
    }

    /// Единственный источник фокусной геометрии бара: и подъём, и ширины зон, и уезд
    /// плеера считаются отсюда, из ОДНОГО предиката. Драйвер — состояние клавиатуры,
    /// а не флаг фокуса: так оба края перехода (подъём и опускание) начинаются ровно
    /// тогда, когда трогается клавиатура, и всё меняется одним апдейтом.
    ///
    /// Подъём: низ бара встаёт на 12pt над клавиатурой (`2021:11248`).
    /// В просмотре выдачи без клавиатуры раскладка та же, фокусная: поле во всю ширину
    /// бара, плееров и чипов нет — они возвращаются, только когда из поиска выходят
    /// (правка пользователя 2026-10-03). Бар при этом не над клавиатурой, а на месте
    /// таббара — той же её кривой, если она как раз уезжает: одно движение, без
    /// остановки на обычной высоте. Переход «просмотр ↔ фокус» меняет только высоту.
    private var raise: ActionBarRaise {
        guard keyboard.isUp else {
            // Вне поиска — обычная раскладка, но **кривой клавиатуры**, если она как раз
            // уходит: на «Назад» она уезжает мягким уходом (0.4s ease-in-out), а морф
            // режимов с быстрым стартом обгонял её, и бар нырял под клавиатуру
            // (проверка навигации 2026-10-03). Клавиатура стоит — `motion` пустой, и бар
            // едет своим морфом, как прежде.
            guard isBrowsingLayout else {
                return ActionBarRaise(isRaised: false, lift: 0, motion: keyboard.motion)
            }
            return ActionBarRaise(isRaised: true, lift: PlusChromeMetrics.browsingDrop, motion: keyboard.motion)
        }
        let barBottomFromScreenBottom = PlusChromeMetrics.bottomSafeArea
            + PlusChromeMetrics.tabsRowHeight
            + PlusChromeMetrics.actionBarToTabsGap
        // min(0,) обязателен: с аппаратной клавиатурой overlap == 0 (или 55pt панели
        // шорткатов) — бар не должен уезжать ВНИЗ.
        let lift = min(0, -(keyboard.overlap + PlusChromeMetrics.focusKeyboardGap - barBottomFromScreenBottom))
        // Кривую отдаём бару вместе с геометрией: он обязан ехать тем же движением,
        // что и клавиатура.
        return ActionBarRaise(isRaised: true, lift: lift, motion: keyboard.motion)
    }
}

/// Подложка нижнего хрома: прогрессивный блюр под 16-стоповым градиентом, высота 210,
/// уходит под home indicator (figma-tabbar §7). Накрывает и таббар, и action bar —
/// поэтому это отдельный слой, а не фон ряда табов.
///
/// Живёт не внутри `BottomChrome`, а слоем в `AppRootView`: хром висит в
/// `overlay(alignment: .bottom)`, а тот прижат к границе safe area и `ignoresSafeArea`
/// изнутри наружу не пробивает — подложка обрезалась, и в зоне home indicator контент
/// оставался неприкрытым.
///
/// В Figma у подложки есть слой `backdrop-blur`, выставленный в 0 — размытие заложено,
/// но не настроено. Берём приём из MusicPlayer (`BottomBarV2.chromeBackground`):
/// `VariableBlurView` размывает по нарастающей к низу, поэтому у полосы нет видимой
/// кромки, с которой резко начинается размытие.
struct TabBarUnderlay: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            VariableBlurView(
                maxBlurRadius: PlusChromeMetrics.underlayBlurRadius,
                direction: .blurredBottomClearTop
            )
            .frame(height: PlusChromeMetrics.underlayBlurHeight)

            PlusGradient.tabBarUnderlay
                .frame(height: PlusMetrics.bottomUnderlayHeight)
        }
        .allowsHitTesting(false)
    }
}

/// Клавиатура: насколько она перекрывает экран снизу. Хром при фокусе поиска встаёт
/// над ней, поэтому нужна **полная** высота перекрытия от нижней кромки экрана,
/// а не остаток над safe area — отступ до бара отмеряется от верха клавиатуры.
@Observable
final class KeyboardObserver {
    /// Кривая и длительность текущего движения клавиатуры. `nil` — она стоит,
    /// и бар едет своим морфом режимов.
    ///
    /// Нужна, потому что клавиатура анимируется **своей** кривой, а не той, что
    /// мы выберем. Пока бар ехал `.smooth(0.32)` против её ~0.25, она уходила вверх
    /// быстрее и на мгновение накрывала бар собой. Совпасть можно только одним
    /// способом — взять её собственные длительность и кривую из нотификации.
    private(set) var motion: Animation?

    private(set) var overlap: CGFloat = 0
    /// Клавиатура на экране. Отдельный флаг, а не `overlap > 0`: с аппаратной
    /// клавиатурой (⌘K в симуляторе) overlap равен нулю или высоте панели шорткатов,
    /// а раскладка бара обязана раскрыться — иначе не появится крест и фокус нечем снять.
    /// Меняется в том же `withAnimation`, что и `overlap`: обе величины приходят во вью
    /// одним апдейтом.
    private(set) var isUp = false
    private var observers: [NSObjectProtocol] = []
    /// Снимает `motion` после того, как клавиатура доехала.
    private var settle: Task<Void, Never>?
    /// Длительность последнего настоящего движения клавиатуры — для уходов, которые
    /// приходят с нулём (см. `drive`). До первого подъёма — системные 0.25.
    private var lastDuration: Double = 0.25
    /// Меньше этого — не длительность, а «без анимации» из нотификации.
    private static let minReportedDuration: Double = 0.05
    /// Ближайший уход клавиатуры запустили мы (`dismissSmoothly`) и знаем его кривую.
    @ObservationIgnored private var isOwnDismissPending = false

    /// Убрать клавиатуру мягко — `KeyboardDismissMotion` вместо резкого системного ухода.
    /// Фокус снимается через цепочку респондеров, и SwiftUI сбрасывает `FocusState` сам:
    /// дальше всё как при любом снятом фокусе (просмотр выдачи — в баре).
    @MainActor
    func dismissSmoothly() {
        let resign = {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        guard isUp else {
            resign()
            return
        }
        isOwnDismissPending = true
        UIView.animate(
            withDuration: KeyboardDismissMotion.duration,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: { _ = resign() },
            // Нотификации об уходе приходят синхронно внутри `resign`, так что к концу
            // анимации отметка своё отработала. Сброс здесь — на случай, когда ухода
            // не случилось (аппаратная клавиатура, гонка с ещё идущим подъёмом): иначе
            // залипшая отметка отдала бы нашу кривую следующему, системному уходу.
            completion: { [weak self] _ in self?.isOwnDismissPending = false }
        )
    }

    init() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard
                    let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                else { return }
                let screenHeight = UIScreen.main.bounds.height
                let next = max(0, screenHeight - frame.origin.y)
                self?.drive(overlap: next, up: true, from: note)
            }
        )
        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                // Обратный переход обязан совпасть с кривой клавиатуры так же, как прямой.
                self?.drive(overlap: 0, up: false, from: note)
            }
        )
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        settle?.cancel()
    }

    /// Публикует новое состояние клавиатуры **вместе с её собственной кривой**.
    ///
    /// Порядок важен: `motion` выставляется ДО `withAnimation`, иначе бар успеет
    /// пересобрать `body` со старой кривой и уедет по ней.
    @MainActor
    private func drive(overlap next: CGFloat, up: Bool, from note: Notification) {
        let info = note.userInfo
        let reported = info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        // Уход, снятый программно (фокус снимает SwiftUI), приходит с нулевой
        // длительностью, хотя клавиатура уезжает обычной анимацией (замер 2026-10-03:
        // подъём рапортует 0.383, уход — 0). С нулём бар доезжал за минимальные 0.12
        // и нырял под клавиатуру — тогда берём длительность её последнего движения.
        if reported >= Self.minReportedDuration { lastDuration = reported }
        let rawCurve = info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
        // Свой уход (`dismissSmoothly`): кривую знаем сами — нотификация о нём врёт.
        // Он приходит двумя нотификациями — сменой кадра и уходом; отметка гаснет на второй.
        let isOwnDismiss = isOwnDismissPending && next == 0
        if isOwnDismiss, !up { isOwnDismissPending = false }
        let duration = isOwnDismiss
            ? KeyboardDismissMotion.duration
            : (reported >= Self.minReportedDuration ? reported : lastDuration)
        let curve = isOwnDismiss
            ? KeyboardDismissMotion.bar
            : Self.animation(curve: rawCurve, duration: duration, leads: up)

        motion = curve
        withAnimation(curve) {
            overlap = next
            isUp = up
        }

        // Кривую держим ровно на время движения: дальше бар обязан вернуться
        // к своему морфу режимов, иначе смена music↔book поедет по клавиатурной.
        settle?.cancel()
        settle = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.motion = nil
        }
    }

    /// Фора, которую бар отыгрывает у собственной задержки.
    ///
    /// Клавиатуру двигает UIKit прямо в момент нотификации, а SwiftUI применяет наше
    /// состояние следующим проходом рендера — бар трогается на кадр-полтора позже.
    /// Догнать это кривой нельзя: замер записи показал, что на первых кадрах перехода
    /// клавиатура успевала накрыть бар собой. Поэтому бар едет **той же** кривой, но
    /// на длительность одного-двух кадров короче — фазы совпадают, и он оказывается
    /// не ниже клавиатуры, а чуть выше. Ошибка в эту сторону не видна: бар просто
    /// приходит на место раньше, а не выныривает из-под клавиатуры.
    /// 30мс — это 2–4 кадра в зависимости от частоты дисплея, то есть число
    /// подобрано, а не выведено. Ошибка в большую сторону безопасна: бар просто
    /// приходит на место чуть раньше клавиатуры, и это не видно. Ошибка в меньшую
    /// видна сразу — клавиатура накрывает бар. Уточнять покадровым замером на
    /// 60Гц-устройстве, если появится.
    private static let commitLatency: Double = 0.03

    /// Кривая анимации клавиатуры по сырому значению из нотификации.
    ///
    /// Системная клавиатура присылает **7** — приватную кривую, которой нет среди
    /// публичных `UIView.AnimationCurve`. Её общепринятая аппроксимация в кубических
    /// коэффициентах — `(0.38, 0.7, 0.125, 1.0)`: резкий старт и долгое торможение.
    /// Остальные значения — стандартные CSS-эквиваленты ease-in-out / in / out / linear.
    ///
    /// Фора (`commitLatency`) — только пока клавиатура на экране и бар обязан от неё
    /// не отстать (`leads`). На уходе форы нет: бар трогается на кадр позже и едет
    /// полную длительность — то есть чуть отстаёт и остаётся над клавиатурой. С форой
    /// он её обгонял и на пару кадров нырял под неё, когда ехал на место таббара
    /// в просмотр выдачи: ход 314 против её 336 (замер записи 2026-10-03).
    private static func animation(curve raw: Int?, duration rawDuration: Double, leads: Bool) -> Animation {
        let duration = max(0.12, rawDuration - (leads ? commitLatency : 0))
        return switch raw {
        case 0: .timingCurve(0.42, 0, 0.58, 1, duration: duration)
        case 1: .timingCurve(0.42, 0, 1, 1, duration: duration)
        case 2: .timingCurve(0, 0, 0.58, 1, duration: duration)
        case 3: .linear(duration: duration)
        default: .timingCurve(0.38, 0.7, 0.125, 1, duration: duration)
        }
    }

}
