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

    /// Хром опущен на 4 pt ниже границы safe area: низы табов ближе к home indicator,
    /// бар едет следом (правка пользователя 2026-10-16).
    static let chromeDrop: CGFloat = 4

    /// Где стоит низ хрома (низ ряда табов) от физического низа экрана. Все расчёты
    /// по нижнему хрому — от этой точки, а не от safe area.
    static var chromeBottom: CGFloat {
        bottomSafeArea - chromeDrop
    }

    /// Сколько хром занимает над safe area: 60 + 4 + 66 − опускание 4. Лента очищает
    /// ровно его, как в figma-screen1 §4.
    static var contentBottomInset: CGFloat {
        PlusMetrics.actionBarHeight + actionBarToTabsGap + tabsRowHeight - chromeDrop
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
    /// Считается от физического низа: низ хрома + ряд табов + зазор + половина бара.
    static var underlayBlurHeight: CGFloat {
        chromeBottom + tabsRowHeight + actionBarToTabsGap + PlusMetrics.actionBarHeight / 2
    }

    /// Блюр в поиске — по верхней кромке поля, опущенного на место таббара (правка
    /// пользователя 2026-10-05): обычная высота считана от бара над таббаром, и в выдаче
    /// мылила полосу в 40 pt над полем.
    static var searchUnderlayBlurHeight: CGFloat {
        chromeBottom + PlusMetrics.actionBarHeight
    }

    /// Нижняя безопасная зона — блюр отмеряется от физического низа экрана,
    /// а высота home indicator зависит от устройства.
    static var bottomSafeArea: CGFloat {
        keyWindow?.safeAreaInsets.bottom ?? 0
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
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
    /// Бар идёт на 15 % короче клавиатуры. Ехать ему меньше — до места таббара или
    /// своей обычной высоты, а не до низа экрана, — и с той же длительностью он был
    /// медленнее: щель между ним и уходящей клавиатурой росла на глазах, да ещё
    /// бар трогается на кадр-два позже неё (правка пользователя 2026-10-05). Так его
    /// скорость сравнялась с клавиатурной; запаса щели 12 хватает, чтобы на обгоне
    /// в несколько пунктов он не нырнул под неё (расчёт по кривой: до 8 pt).
    static let barDuration: TimeInterval = duration * 0.85
    /// Кривая бара — `UIView.AnimationOptions.curveEaseInOut` в кубических
    /// коэффициентах UIKit: бар едет той же кривой, что клавиатура под ним.
    static let bar: Animation = .timingCurve(0.42, 0, 0.58, 1, duration: barDuration)
}

enum BottomChromeMotion {
    /// Таббар, уходя, ещё и проседает: бар опускается на его место, и встречное
    /// движение читается как «уступил место», а не как два слоя друг в друге.
    static let tabBarHideOffset: CGFloat = 16
}

/// Фиксированный нижний хром. Живёт в ZStack корня, **вне** `NavigationStack` — внутри
/// он ездил бы вместе с пушами.
struct BottomChrome: View {
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard
    @Environment(SearchState.self) private var search
    /// Клавиатура уже стояла в этом фокусе. Её уход в фокусе — тот, о котором UIKit
    /// сообщил раньше, чем SwiftUI снял фокус (`isBrowsingLayout`). Свежий фокус —
    /// в том числе пока клавиатура ещё уезжает после «Назад», затемнения или ухода
    /// в карточку — сюда не попадает (второе ревью 2026-10-03).
    @State private var isFocusKeyboardServed = false

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
        // Ниже границы safe area на `chromeDrop`: оверлей корня прижат к ней.
        .padding(.bottom, -PlusChromeMetrics.chromeDrop)
        // Системный подъём над клавиатурой выключен: SwiftUI поднял бы весь хром
        // вместе с таббаром, да ещё и сложился бы с нашим сдвигом — бар улетал вдвое выше.
        //
        // Отдать подъём системной безопасной зоне пробовали (2026-08-23): таббар и бар
        // разнесли по разным слоям, зону погасили только у таббара. Бар при этом улетел
        // выше экрана и пропал — сдвиг сложился вдвое ровно так, как описано выше.
        // Синхрон с клавиатурой добираем её собственной кривой, см. `KeyboardObserver`.
        .ignoresSafeArea(.keyboard)
        .onChange(of: keyboard.isUp) { _, isUp in
            if isUp, actionBar.isSearchFocused { isFocusKeyboardServed = true }
        }
        // Выходы («Назад», затемнение, уход в карточку) снимают фокус раньше, чем уходит
        // клавиатура, — защёлка гаснет до следующего фокуса.
        .onChange(of: actionBar.isSearchFocused) { _, focused in
            isFocusKeyboardServed = focused && keyboard.isUp
        }
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
    /// Только пока **уезжает клавиатура этого фокуса** (стояла в нём — `isFocusKeyboardServed`,
    /// и едет — `motion` есть, а `isUp` уже нет): на подъёме окно то же — фокус есть,
    /// клавиатуры ещё нет, — и свежий фокус пустого поля сперва опускал бар к месту
    /// таббара, а потом поднимал над клавиатурой (ревью 2026-10-03). Прежде это окно
    /// закрывал непустой запрос — с «Искали недавно» его нет. Одного `motion` мало:
    /// фокус, поставленный, пока клавиатура ещё уезжает после «Назад», ловил то же.
    private var isBrowsingLayout: Bool {
        search.isBrowsing
            || (actionBar.isSearchFocused && !search.isSuspended
                && isFocusKeyboardServed && keyboard.motion != nil)
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
        let barBottomFromScreenBottom = PlusChromeMetrics.chromeBottom
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
    @Environment(SearchState.self) private var search
    @Environment(ActionBarState.self) private var actionBar
    @Environment(KeyboardObserver.self) private var keyboard

    /// Поиск открыт — бар внизу без таббара, и блюр ниже (`searchUnderlayBlurHeight`).
    /// Признак тот же, что гасит таббар (`BottomChrome.isTabBarHidden`).
    private var isSearchMode: Bool {
        search.isBrowsing || actionBar.isSearchFocused
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VariableBlurView(
                maxBlurRadius: PlusChromeMetrics.underlayBlurRadius,
                direction: .blurredBottomClearTop
            )
            .frame(height: isSearchMode
                ? PlusChromeMetrics.searchUnderlayBlurHeight
                : PlusChromeMetrics.underlayBlurHeight)
            // Той же кривой, что едет бар и уходит таббар.
            .animation(keyboard.motion ?? ActionBarMotion.morph, value: isSearchMode)

            PlusGradient.tabBarUnderlay
                .frame(height: PlusMetrics.bottomUnderlayHeight)
                // В поиске затемнение под баром — как тень сверху у навигации витрин: те же
                // 16 стопов, пик 50 % вместо 90 (правка пользователя 2026-10-31: «слишком
                // тёмный, сильно отличается от верхнего»). Высота прежняя. Стопы — доли пика,
                // поэтому прозрачность слоя даёт ровно такой градиент и анимируется вместе
                // с блюром той же кривой.
                .opacity(isSearchMode ? ServiceTopNavLayout.topShadePeak / PlusGradient.tabBarUnderlayPeak : 1)
                .animation(keyboard.motion ?? ActionBarMotion.morph, value: isSearchMode)
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
        #if DEBUG
        FrameGapTrace.startIfRequested()
        if UserDefaults.standard.bool(forKey: "debugKeyboardTrace") {
            for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification,
                         UIApplication.willEnterForegroundNotification, UIApplication.didBecomeActiveNotification] {
                observers.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                    NSLog("[life] %@", note.name.rawValue)
                })
            }
        }
        #endif
        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                Self.trace(note)
                guard
                    Self.isOwnKeyboard(note),
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
                Self.trace(note)
                guard Self.isOwnKeyboard(note) else { return }
                // Обратный переход обязан совпасть с кривой клавиатуры так же, как прямой.
                self?.drive(overlap: 0, up: false, from: note)
            }
        )
    }

    /// Клавиатура — наша, а не чужого приложения. Уведомления о чужой iOS шлёт тоже:
    /// вернулись из приложения, где она стояла, — пришли её смена кадра и уход. Смена
    /// кадра поднимала `isUp`, и бар на мгновение раскладывался как в поиске: поле
    /// во всю ширину, плеер уезжал вправо и сразу возвращался (жалоба 2026-10-10,
    /// поймано записью возврата из «Настроек» с поднятой клавиатурой).
    private static func isOwnKeyboard(_ note: Notification) -> Bool {
        note.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool ?? true
    }

    /// `-debugKeyboardTrace 1` — каждое уведомление клавиатуры в лог: имя, своя ли,
    /// конечный кадр, длительность и состояние приложения (разбор дёрганья бара при
    /// возврате из переключателя приложений, 2026-10-16).
    private static func trace(_ note: Notification) {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "debugKeyboardTrace") else { return }
        let info = note.userInfo
        let frame = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect).map { "\($0)" } ?? "—"
        let local = (info?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool).map { "\($0)" } ?? "—"
        let duration = info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? -1
        let state = switch UIApplication.shared.applicationState {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "?"
        }
        NSLog("[kb] %@ local=%@ end=%@ dur=%.3f app=%@", note.name.rawValue, local, frame, duration, state)
        #endif
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
            : Self.animation(curve: rawCurve, duration: duration, leads: up, notedAt: CACurrentMediaTime())

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

    /// Фора, которую бар отыгрывает у собственной задержки, — только когда пружину
    /// клавиатуры не нашли и бар едет кубической кривой от своего первого кадра.
    ///
    /// SwiftUI применяет наше состояние следующим проходом рендера — бар трогается
    /// на кадр-полтора позже. Поэтому он едет **той же** кривой, но на длительность
    /// одного-двух кадров короче: оказывается не ниже клавиатуры, а чуть выше.
    /// Ошибка в эту сторону не видна, в обратную — клавиатура накрывает бар.
    private static let commitLatency: Double = 0.03

    /// Кривая анимации клавиатуры по сырому значению из нотификации.
    ///
    /// Системная клавиатура присылает **7** — приватную кривую, которой нет среди
    /// публичных `UIView.AnimationCurve`. За ней стоит пружина `CASpringAnimation`
    /// (`KeyboardSpringTrack`), и подъём едет ею самой; кубическая аппроксимация
    /// `(0.38, 0.7, 0.125, 1.0)` — запас на случай, когда пружины не нашлось.
    /// Остальные значения — стандартные CSS-эквиваленты ease-in-out / in / out / linear.
    ///
    /// На уходе (`leads == false`) форы нет: бар трогается на кадр позже и едет
    /// полную длительность — чуть отстаёт и остаётся над клавиатурой. С форой
    /// он её обгонял и на пару кадров нырял под неё, когда ехал на место таббара
    /// в просмотр выдачи: ход 314 против её 336 (замер записи 2026-10-03).
    private static func animation(curve raw: Int?, duration rawDuration: Double, leads: Bool, notedAt: CFTimeInterval) -> Animation {
        let curve: UnitCurve = switch raw {
        case 0: .bezier(startControlPoint: UnitPoint(x: 0.42, y: 0), endControlPoint: UnitPoint(x: 0.58, y: 1))
        case 1: .bezier(startControlPoint: UnitPoint(x: 0.42, y: 0), endControlPoint: UnitPoint(x: 1, y: 1))
        case 2: .bezier(startControlPoint: UnitPoint(x: 0, y: 0), endControlPoint: UnitPoint(x: 0.58, y: 1))
        case 3: .linear
        default: .bezier(startControlPoint: UnitPoint(x: 0.38, y: 0.7), endControlPoint: UnitPoint(x: 0.125, y: 1))
        }
        guard leads else { return .timingCurve(curve, duration: max(0.12, rawDuration)) }
        return Animation(KeyboardPhaseAnimation(
            curve: curve,
            duration: max(0.12, rawDuration - commitLatency),
            keyboard: KeyboardSpringTrack(notedAt: notedAt)
        ))
    }

}

/// Подъём бара — **той же пружиной и с того же мгновения**, что клавиатура.
///
/// Клавиатура трогается на коммите, через ~40 мс после нотификации, а наш апдейт ждёт
/// главного потока: в фокусе с запросом он занят монтированием выдачи, и бар
/// трогался на 25–80 мс позже клавиатуры при повторной активации и на 450 мс при
/// первой — она накрывала его, и он выныривал из-под неё (запись 2026-10-31).
/// Время от нотификации тоже не годится: бар уходил вперёд на те же 40 мс.
/// Поэтому анимация читает у самой клавиатуры её пружину и время старта
/// и ставит бар в её фазу на каждом кадре, сколько бы ни опоздал первый.
private struct KeyboardPhaseAnimation: CustomAnimation {
    /// Кривая и длительность на случай, когда пружины клавиатуры не нашлось
    /// (аппаратная или плавающая клавиатура): от первого кадра SwiftUI, как прежде.
    let curve: UnitCurve
    let duration: TimeInterval
    let keyboard: KeyboardSpringTrack

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        switch keyboard.phase(atAnimationTime: time) {
        case .waiting:
            return value.scaled(by: 0)
        case .running(let elapsed, let spring, let length):
            guard elapsed < length else { return nil }
            return value.scaled(by: spring.value(target: 1.0, time: max(0, elapsed)))
        case .unknown:
            guard time < duration else { return nil }
            return value.scaled(by: curve.value(at: time / duration))
        }
    }
}

/// Пружина, которой UIKit двигает клавиатуру, и момент её старта.
///
/// Анимация `position` (`CASpringAnimation`) висит на контейнере клавиатуры в окне
/// `UITextEffectsWindow` (`UIKeyboardItemContainerView`, зонд 2026-10-31): она
/// добавлена уже к нотификации, а `beginTime` получает на коммите. Один объект
/// на подъём — его делят все значения, которые едут этой анимацией.
final class KeyboardSpringTrack: Hashable, @unchecked Sendable {
    enum Phase {
        /// Клавиатура ещё не тронулась — бар тоже стоит.
        case waiting
        /// Сколько клавиатура уже едет, её пружина и длина анимации.
        case running(elapsed: TimeInterval, spring: Spring, length: TimeInterval)
        /// Пружины нет — бар едет своей кривой.
        case unknown
    }

    /// Сколько ждать, пока у клавиатуры появится пружина.
    private static let patience: TimeInterval = 0.15
    /// Сколько ждать коммита найденной пружины: на первой активации главный поток
    /// стоит до 470 мс, и клавиатура трогается только после него.
    private static let commitPatience: TimeInterval = 1
    /// Вызовы ближе этого — один проход рендера.
    private static let sameFrameGap: TimeInterval = 0.003

    private let notedAt: CFTimeInterval
    private weak var layer: CALayer?
    private var spring: Spring?
    private var length: TimeInterval = 0
    private var begin: CFTimeInterval?
    /// Метка кадра: все значения одного прохода рендера получают одно время, иначе
    /// за проход (до 6 мс на тяжёлом кадре) поля бара расходились бы по фазе.
    private var frameStamp: CFTimeInterval = 0
    private var lastCall: CFTimeInterval = 0
    /// Кадр, посчитанный сейчас, покажется на следующем обновлении экрана, а клавиатуру
    /// система рисует в фазе на момент показа — бар считаем на кадр вперёд.
    private var presentationLead: TimeInterval = 1.0 / 60
    private var isMissing = false

    init(notedAt: CFTimeInterval) {
        self.notedAt = notedAt
    }

    /// Счёт — по реальному времени, а не по `time` анимации: тот на подвисании
    /// главного потока прибавляет один шаг кадра вместо прошедших 50 мс, и бар
    /// навсегда отставал от клавиатуры на эту разницу (замер 2026-10-31: 33–60 мс).
    func phase(atAnimationTime time: TimeInterval) -> Phase {
        let now = CACurrentMediaTime()
        if now - lastCall > Self.sameFrameGap { frameStamp = now }
        lastCall = now
        if begin == nil, !isMissing, Thread.isMainThread {
            MainActor.assumeIsolated { resolve(now: now) }
        }
        guard let begin, let spring else { return isMissing ? .unknown : .waiting }
        return .running(elapsed: frameStamp + presentationLead - begin, spring: spring, length: length)
    }

    @MainActor
    private func resolve(now: CFTimeInterval) {
        if layer == nil, let found = Self.keyboardLayer() {
            layer = found.layer
            presentationLead = 1 / Double(max(60, found.framesPerSecond))
        }
        if let layer, let animation = layer.animation(forKey: "position") as? CASpringAnimation {
            if spring == nil {
                spring = Spring(mass: animation.mass, stiffness: animation.stiffness,
                                damping: animation.damping, allowOverDamping: true)
                length = animation.duration
            }
            let start = layer.convertTime(animation.beginTime, to: nil)
            // Старт раньше нотификации — пружина прошлого движения, а не этого.
            if animation.beginTime > 0, start > notedAt - Self.sameFrameGap {
                begin = start
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "debugKeyboardTrace") {
                    NSLog("[kb] пружина клавиатуры: старт через %.0f мс после нотификации, бар — с %.0f мс её хода; m %.2f k %.1f c %.1f, %.3f с",
                          (begin! - notedAt) * 1000, (now - begin!) * 1000,
                          animation.mass, animation.stiffness, animation.damping, animation.duration)
                }
                #endif
                return
            }
        }
        if now - notedAt > (spring == nil ? Self.patience : Self.commitPatience) { isMissing = true }
    }

    @MainActor
    private static func keyboardLayer() -> (layer: CALayer, framesPerSecond: Int)? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { String(describing: type(of: $0)).contains("TextEffects") }
        for window in windows {
            if let layer = springLayer(in: window.layer, depth: 0) {
                return (layer, window.screen.maximumFramesPerSecond)
            }
        }
        return nil
    }

    private static func springLayer(in layer: CALayer, depth: Int) -> CALayer? {
        if layer.animation(forKey: "position") is CASpringAnimation { return layer }
        guard depth < 6 else { return nil }
        for sublayer in layer.sublayers ?? [] {
            if let found = springLayer(in: sublayer, depth: depth + 1) { return found }
        }
        return nil
    }

    static func == (lhs: KeyboardSpringTrack, rhs: KeyboardSpringTrack) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}
