import CoreMotion
import QuartzCore
import SwiftUI
import UIKit

// MARK: - Числа

/// Голография обложки (просьба пользователя 2026-10-31): от наклона телефона по обложке
/// пробегает лёгкий блик с переливами, как у голографической фольги, а карточка едва заметно
/// плавает в перспективе. Одна на все крупные обложки: экраны альбома, плейлиста и книги
/// и центральная обложка большого плеера музыки. Всё — «едва заметно»: на эти экраны заходят
/// часто. Рецепт самого блика (профиль полосы, спектр, смешивание с пикселем) — в `CoverHolo.metal`.
///
/// Повороты — в осях телефона CoreMotion: x > 0 — верх к глазу, y > 0 — правый край от глаза.
enum CoverHoloConfig {
    // MARK: Жизненный цикл

    /// Пауза перед проявлением — после конца зума, ухода плеера, возврата из фона;
    /// заодно гасит дребезг условий.
    static let resumeDelay: Duration = .milliseconds(150)
    /// Проявление — неспешно: критическая пружина ω 3.2, половина за 0.5 с, 90 % за 1.2 с,
    /// старт с нулевой скоростью — первые 100 мс это 4 % силы, «включения» не видно.
    static let riseResponse: Double = 3.2
    /// Уход — быстро, но без ступени: ω 22, 90 % за 0.18 с. Обратный зум кладёт обложку
    /// в миниатюру через ~0.25 с — к посадке от эффекта остаётся 3 %.
    static let fallResponse: Double = 22
    /// Ниже — уже ноль: блик слабее 1/255, наклон меньше 0.005°. Тут эффект засыпает.
    static let settleLevel: Double = 0.002
    static let settleSpeed: Double = 0.05
    /// Шаг модели не длиннее кадра 30 Гц: после фриза или фона всё продолжается с места,
    /// а не догоняет пропущенное рывком.
    static let maxStep: Double = 1.0 / 30

    // MARK: Гироскоп

    /// Опрос — 60 Гц: на 120 Гц кадров замер держится два кадра, интеграл скорости тот же.
    static let sensorInterval: TimeInterval = 1.0 / 60
    /// Замер не обновлялся дольше — датчик встал: его последняя скорость интегрировалась бы
    /// в поворот, которого нет.
    static let staleSample: Double = 0.1

    // MARK: Движение

    /// Память поворота для блика (интеграл скорости с утечкой): наклон держится ~2 с, потом
    /// блик сам уходит в угол — «пробежал и ушёл». Опоры нет: поза, в которой открыли экран,
    /// ничего не сдвигает, а смена позы (лёг, повернулся) не прижимает блик к краю.
    static let glareMemory: Double = 2.0
    /// Память наклона карточки короче — она всплывает обратно к экрану за 1–2 с.
    static let tiltMemory: Double = 1.4
    /// Блик — «свет»: критическая пружина ω 9, 95 % пути за ~0.5 с. Гасит дрожь гироскопа
    /// без ощутимого запаздывания.
    static let glareResponse: Double = 9
    /// Карточка — «тело»: ω 5 и ζ 0.75 — отстаёт от блика и доплывает с перелётом ~3 %,
    /// а не дёргается.
    static let tiltResponse: Double = 5
    static let tiltDamping: Double = 0.75

    // MARK: Наклон

    /// Карточка стоит в мире, как за стеклом: отстаёт от поворота телефона на эту долю —
    /// поворот на 15° даёт встречный наклон 1.8°.
    static let tiltFollow: Double = 0.12
    /// Мягкий предел наклона (tanh по радиусу) — 2.5°: углы кавера уходят не дальше ~1.4 pt.
    static let tiltLimit: Double = 2.5 * .pi / 180
    /// Своё плавание карточки — 0.6° по осям: кромки «дышат» на ~1.3 pt. Периоды 8.3 и 10.7 с
    /// не кратны — круга не видно. На симуляторе гироскопа нет, и движется только оно.
    static let floatAmplitude: Double = 0.6 * .pi / 180
    static let floatPeriods = SIMD2<Double>(8.3, 10.7)
    static let floatPhases = SIMD2<Double>(0.9, 2.3)
    /// Глаз — в двух сторонах обложки: мягкая перспектива без «рыбьего глаза», одна
    /// на всех ширинах экрана (от стороны кавера, а не числом).
    static let cameraDistance: CGFloat = 2
    /// Прозрачное поле вокруг обложки в растре эффекта: наклонённые углы выходят за кадр
    /// до ~1.4 pt и не должны обрезаться. Снаружи снимается отрицательным — раскладка та же.
    static let margin: CGFloat = 3

    // MARK: Блик

    /// Пробег блика — 4 обложки на радиан: обложку он проходит за ~14° поворота,
    /// дрожь руки лишь чуть шевелит угловой глянец.
    static let glareTravel: Double = 4
    /// Мягкий предел поворота для блика — 22° (tanh): дальше полоса не улетает.
    static let glareLimit: Double = 22 * .pi / 180
    /// Цвет кромки медленно перетекает и в покое: ±0.12 цикла спектра за 11 с.
    static let hueDrift: Double = 0.12
    static let hueDriftPeriod: Double = 11
    /// Общая сила блика — множитель рецепта шейдера, для подстройки по фидбеку.
    static let intensity: Double = 1
}

// MARK: - Поза

/// Эффект на один кадр. Покой (`rest`) — ровно обычная обложка: шейдер выключен,
/// трансформа единичная.
struct CoverHoloPose: Equatable {
    /// Наклон карточки, рад (оси CoreMotion) — уже умножен на огибающую.
    var tilt = SIMD2<Double>.zero
    /// Сдвиг блика от покоя, доли обложки: x вправо, y вниз.
    var light = SIMD2<Double>.zero
    /// Дрейф фазы спектра, циклы.
    var hue: Double = 0
    /// Сила блика — огибающая × `intensity`.
    var amount: Double = 0

    static let rest = CoverHoloPose()
}

// MARK: - Модификатор

extension View {
    /// Голографический блик и едва заметный плавающий наклон — на готовую обложку (картинка,
    /// скругление, кромка). Раскладку не меняет.
    /// - Parameters:
    ///   - isPresented: экран на виду по UIKit — от конца появления до начала ухода
    ///     (`CoverHoloPresence`).
    ///   - isOnScreen: обложка хоть краем в кадре — ушла скроллом за верх, считать нечего.
    ///   - isInPlayer: обложка большого плеера музыки — он сам и есть `contentPlayer`,
    ///     а поиск остался под ним.
    func coverHolo(isPresented: Bool, isOnScreen: Bool, isInPlayer: Bool = false) -> some View {
        modifier(CoverHolo(isPresented: isPresented, isOnScreen: isOnScreen, isInPlayer: isInPlayer))
    }
}

/// Один постоянный `TimelineView` без веток `if/else`: идентичность картинки (`@State`
/// у `ArtworkImage`) не меняется никогда. В покое он на паузе, шейдер выключен, трансформа
/// единичная — обложка бит в бит прежняя, и пути рендера переключаются только в этой точке.
/// Покадровое — в обычных полях `CoverHoloMotion`, в `@State` на кадре ничего не пишется
/// (правило 2 CLAUDE.md).
///
/// Сила эффекта — огибающая: растёт, только когда на обложку смотрят (экран на виду, она
/// в кадре, картинка на месте, поверх ничего нет), и гаснет с началом любого ухода. Поэтому
/// на входе зумом обложка плоская и без блика, а глянец проявляется уже после посадки.
struct CoverHolo: ViewModifier {
    let isPresented: Bool
    let isOnScreen: Bool
    let isInPlayer: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale
    @Environment(ActionBarState.self) private var actionBar
    /// Необязательно: у плеера, показанного UIKit поверх всего, окружения поиска нет.
    @Environment(SearchState.self) private var search: SearchState?
    /// Держатель модели. Инициализатор без побочных эффектов: начальное значение `@State`
    /// считается на каждой сборке экрана, лишние копии просто умирают.
    @State private var motion = CoverHoloMotion()
    /// Картинка обложки на месте: на скелетоне нет ни блика, ни наклона.
    @State private var isArtworkShown = false

    func body(content: Content) -> some View {
        let margin = CoverHoloConfig.margin
        let scale = displayScale
        return TimelineView(.animation(paused: motion.isSettled)) { context in
            let pose = motion.pose(at: context.date)
            content
                .padding(margin)
                // Наклон — до шейдера: картинка пересэмплируется один раз, а блик ложится
                // на растр, который выводится на экран как есть.
                .modifier(CoverHoloTilt(rotation: pose.tilt))
                .colorEffect(
                    CoverHoloShader.make(pose, margin: margin, scale: scale),
                    isEnabled: pose.amount > 0
                )
                .padding(-margin)
        }
        // Транзакцию не глушим: внутри бывают свои анимации (размер обложки плеера на паузе —
        // пружиной), а поза и так приходит кадрами `TimelineView` без анимации.
        // Картинка на месте — сообщает сама `ResolvedArtwork`, той же меткой, что кромке.
        .onPreferenceChange(CoverArtworkShownKey.self) { shown in
            isArtworkShown = shown != false
        }
        .task(id: isEligible) {
            guard isEligible else {
                motion.deactivate()
                return
            }
            try? await Task.sleep(for: CoverHoloConfig.resumeDelay)
            guard !Task.isCancelled else { return }
            motion.activate()
        }
        // Экрана уже нет в окне — в покой без огибающей: этого никто не видит.
        .onDisappear {
            motion.reset()
        }
    }

    /// Эффект живёт, только когда на него смотрят: экран на виду и не уходит, обложка
    /// в кадре, картинка на месте, движение не уменьшено, приложение активно, поверх
    /// нет ни плеера (музыка ложится `.overFullScreen` — экран под ней не уходит), ни поиска.
    /// Reduce Motion — своя ветка: эффекта нет вовсе, обложка плоская и без блика.
    private var isEligible: Bool {
        guard isPresented, isOnScreen, isArtworkShown, !reduceMotion, scenePhase == .active else { return false }
        if isInPlayer { return true }
        return actionBar.contentPlayer == nil
            && !actionBar.isSearchFocused
            && !(search?.isBrowsing ?? false)
    }
}

// MARK: - Наклон

/// Наклон карточки с перспективой — свой `GeometryEffect`, чтобы оси, знаки и глубина были
/// явными (у `rotation3DEffect` перспектива — безразмерное «1» от неизвестного размера).
/// Поворот вокруг центра: x > 0 — верх к глазу, y > 0 — правый край от глаза (знаки сверены
/// расчётом углов: на +2.5° по x верхняя кромка 249.7 pt против 244.3 у нижней).
/// В покое — единичная трансформа.
struct CoverHoloTilt: GeometryEffect {
    var rotation: SIMD2<Double>

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(rotation.x, rotation.y) }
        set { rotation = SIMD2(newValue.first, newValue.second) }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard rotation != .zero else { return ProjectionTransform() }
        // Глаз — в `cameraDistance` сторон обложки; сторона — без прозрачного поля.
        let side = max(size.width, size.height) - 2 * CoverHoloConfig.margin
        guard side > 0 else { return ProjectionTransform() }

        let (sinX, cosX) = (CGFloat(sin(rotation.x)), CGFloat(cos(rotation.x)))
        let (sinY, cosY) = (CGFloat(sin(rotation.y)), CGFloat(cos(rotation.y)))
        // Вокруг горизонтали: верх (y < 0 при y вниз) выходит к глазу (z > 0).
        var aroundX = CATransform3DIdentity
        aroundX.m22 = cosX
        aroundX.m23 = -sinX
        aroundX.m32 = sinX
        aroundX.m33 = cosX
        // Вокруг вертикали: правый край (x > 0) уходит от глаза (z < 0).
        var aroundY = CATransform3DIdentity
        aroundY.m11 = cosY
        aroundY.m13 = -sinY
        aroundY.m31 = sinY
        aroundY.m33 = cosY
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / (side * CoverHoloConfig.cameraDistance)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var transform = CATransform3DMakeTranslation(-center.x, -center.y, 0)
        transform = CATransform3DConcat(transform, aroundX)
        transform = CATransform3DConcat(transform, aroundY)
        transform = CATransform3DConcat(transform, perspective)
        transform = CATransform3DConcat(transform, CATransform3DMakeTranslation(center.x, center.y, 0))
        return ProjectionTransform(transform)
    }
}

// MARK: - Шейдер

/// Шейдер блика (`Shaders/CoverHolo.metal`). Один конструктор и на кадр, и на прогрев:
/// у прогретого пайплайна та же раскладка аргументов.
enum CoverHoloShader {
    static func make(_ pose: CoverHoloPose, margin: CGFloat, scale: CGFloat) -> Shader {
        ShaderLibrary.coverHolo(
            .boundingRect,
            .float(margin),
            .float2(pose.light.x, pose.light.y),
            .float(pose.hue),
            .float(pose.amount),
            .float(scale)
        )
    }

    /// Под заставкой (`AppRootView.prepareShowcase`): первый блик на экране обложки
    /// не тратит кадр на сборку пайплайна. Заодно создаётся менеджер CoreMotion — первое
    /// обращение к демону тоже не должно прийтись на экран.
    @MainActor
    static func prewarm() async {
        _ = CoverHoloSensor.shared
        try? await make(.rest, margin: CoverHoloConfig.margin, scale: 3).compile(as: .colorEffect)
    }
}

// MARK: - Движение

/// Фильтры и огибающая. Покадровое — в обычных полях (`@ObservationIgnored`): запись из тела
/// кадра вью не инвалидирует. Наблюдаем только `isSettled`, и меняется он событиями — на
/// включении и следующим тактом после того, как эффект погас, — а не на каждом кадре.
///
/// Всё считается по шагу кадра, а не по настенным часам: после фриза, фона или паузы эффект
/// продолжается с того места, где его видели последним, а не прыгает в «положенное».
@MainActor
@Observable
final class CoverHoloMotion {
    /// Огибающая и цель в нуле — `TimelineView` на паузе, гироскоп выключен.
    private(set) var isSettled = true

    @ObservationIgnored private var target: Double = 0
    @ObservationIgnored private var envelope = HoloEnvelope()
    /// Повороты телефона с утечкой — то, что «видят» блик и карточка (оси CoreMotion, рад).
    @ObservationIgnored private var glareTurn = SIMD2<Double>.zero
    @ObservationIgnored private var tiltTurn = SIMD2<Double>.zero
    @ObservationIgnored private var glareSpring = HoloSpring()
    @ObservationIgnored private var tiltSpring = HoloSpring()
    /// Время кадров — для плавания: на фризах и паузах стоит вместе со всем остальным.
    @ObservationIgnored private var clock: Double = 0
    @ObservationIgnored private var lastDate: Date?
    @ObservationIgnored private var lastPose = CoverHoloPose.rest
    @ObservationIgnored private var isSensing = false
    @ObservationIgnored private var isSettlePending = false

    // MARK: События — не из кадра

    /// Эффекту можно жить: огибающая идёт к единице с того места, где была.
    func activate() {
        target = 1
        attachSensor()
        guard isSettled else { return }
        // С паузы: дата последнего кадра устарела — первый кадр идёт без шага.
        lastDate = nil
        isSettled = false
    }

    /// Начался уход: огибающая к нулю. Гироскоп больше не нужен — поворот дальше просто
    /// утекает к покою.
    func deactivate() {
        target = 0
        detachSensor()
    }

    /// Экрана уже нет в окне: в покой сразу, без огибающей — этого никто не видит.
    func reset() {
        target = 0
        detachSensor()
        restAll()
        lastDate = nil
        if !isSettled { isSettled = true }
    }

    // MARK: Кадр

    /// Поза на кадр `date`. Повторный вызов с той же датой — та же поза: шаг нулевой.
    func pose(at date: Date) -> CoverHoloPose {
        let step = lastDate.map { min(max(date.timeIntervalSince($0), 0), CoverHoloConfig.maxStep) } ?? 0
        lastDate = date
        guard step > 0 else { return lastPose }
        advance(by: step)
        lastPose = makePose()
        return lastPose
    }

    private func advance(by dt: Double) {
        typealias C = CoverHoloConfig
        clock += dt

        // 1. Интеграл скорости с утечкой — точное решение для постоянной на шаге скорости:
        //    на 60 и 120 Гц одно и то же. Скачка от него не бывает по построению: всё, что
        //    случилось без кадров, просто не проинтегрировано.
        let rate = isSensing ? CoverHoloSensor.shared.rate(step: dt, clock: clock) : .zero
        glareTurn = Self.leak(glareTurn, rate: rate, memory: C.glareMemory, dt: dt)
        tiltTurn = Self.leak(tiltTurn, rate: rate, memory: C.tiltMemory, dt: dt)

        // 2. Свет быстрый, тело с инерцией.
        glareSpring.step(toward: glareTurn, omega: C.glareResponse, damping: 1, dt: dt)
        tiltSpring.step(toward: tiltTurn, omega: C.tiltResponse, damping: C.tiltDamping, dt: dt)

        // 3. Огибающая: смена цели меняет только цель и жёсткость — значение и скорость те же.
        envelope.step(toward: target, omega: target > 0 ? C.riseResponse : C.fallResponse, dt: dt)

        // 4. Погасло — всё в ноль (невидимо: огибающая уже в нуле), `TimelineView` встаёт.
        if target == 0, envelope.value < C.settleLevel, abs(envelope.velocity) < C.settleSpeed {
            restAll()
            scheduleSettle()
        }
    }

    private func makePose() -> CoverHoloPose {
        typealias C = CoverHoloConfig
        let strength = envelope.value
        guard strength > 0 else { return .rest }

        let turn = 2 * Double.pi * clock
        // Своё плавание карточки — от времени кадров.
        let float = SIMD2(
            sin(turn / C.floatPeriods.x + C.floatPhases.x),
            sin(turn / C.floatPeriods.y + C.floatPhases.y)
        ) * C.floatAmplitude
        // Карточка стоит в мире, как за стеклом: встречно повороту телефона, с инерцией тела.
        let relative = Self.softLimit(float - tiltSpring.value * C.tiltFollow, to: C.tiltLimit)
        // Свет неподвижен в мире и видит поворот карточки в нём — телефон плюс её наклон —
        // и бежит к кромке, что приблизилась к глазу: верх к глазу (x > 0) — блик вверх,
        // правый край от глаза (y > 0) — блик влево.
        let world = Self.softLimit(glareSpring.value + relative, to: C.glareLimit)
        let light = SIMD2(-world.y, -world.x) * C.glareTravel
        return CoverHoloPose(
            tilt: relative * strength,
            light: light,
            hue: C.hueDrift * sin(turn / C.hueDriftPeriod),
            amount: strength * C.intensity
        )
    }

    private func restAll() {
        envelope = HoloEnvelope()
        glareTurn = .zero
        tiltTurn = .zero
        glareSpring = HoloSpring()
        tiltSpring = HoloSpring()
        clock = 0
        lastPose = .rest
    }

    /// Пауза уходит в SwiftUI следующим тактом: из тела кадра наблюдаемое не пишем.
    private func scheduleSettle() {
        guard !isSettlePending else { return }
        isSettlePending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            isSettlePending = false
            // За это время эффект могли снова включить — тогда пауза не нужна.
            guard target == 0, !isSettled else { return }
            isSettled = true
        }
    }

    private func attachSensor() {
        guard !isSensing else { return }
        isSensing = true
        CoverHoloSensor.shared.attach()
    }

    private func detachSensor() {
        guard isSensing else { return }
        isSensing = false
        CoverHoloSensor.shared.detach()
    }

    /// Интеграл скорости с утечкой (high-pass угла): θ' = ω − θ/τ, точный шаг.
    private static func leak(_ value: SIMD2<Double>, rate: SIMD2<Double>, memory: Double, dt: Double) -> SIMD2<Double> {
        let decay = exp(-dt / memory)
        return value * decay + rate * (memory * (1 - decay))
    }

    /// Мягкий предел по радиусу: у нуля — как есть, дальше плавно к `limit` без упора;
    /// направление сохраняется — диагональ не сплющивается, как у покоординатного клампа.
    private static func softLimit(_ value: SIMD2<Double>, to limit: Double) -> SIMD2<Double> {
        let length = (value * value).sum().squareRoot()
        guard length > 1e-12 else { return value }
        return value * (limit * tanh(length / limit) / length)
    }
}

/// Затухающая пружина в плоскости с точным шагом — решение уравнения за `dt` к неподвижной
/// на шаге цели: на 60 и 120 Гц одна траектория, ошибка не копится.
struct HoloSpring {
    var value = SIMD2<Double>.zero
    var velocity = SIMD2<Double>.zero

    mutating func step(toward target: SIMD2<Double>, omega: Double, damping zeta: Double, dt: Double) {
        let offset = value - target
        if zeta >= 1 {
            // Критическая: y(t) = (y₀ + (v₀ + ωy₀)·t)·e^(−ωt)
            let decay = exp(-omega * dt)
            let drive = velocity + offset * omega
            value = target + (offset + drive * dt) * decay
            velocity = (velocity - drive * (omega * dt)) * decay
        } else {
            // Недодемпфированная: ω_d = ω·√(1 − ζ²)
            let damped = omega * (1 - zeta * zeta).squareRoot()
            let decay = exp(-zeta * omega * dt)
            let cosine = cos(damped * dt)
            let sine = sin(damped * dt)
            let swing = (velocity + offset * (zeta * omega)) / damped
            let restoring = (offset * (omega * omega) + velocity * (zeta * omega)) / damped
            value = target + (offset * cosine + swing * sine) * decay
            velocity = (velocity * cosine - restoring * sine) * decay
        }
    }
}

/// Огибающая — критическая пружина с точным шагом. Скорость переживает смену цели: вход
/// и уход, сменившие друг друга на полпути, стыкуются без излома. Из 0…1 не выходит —
/// сила блика не бывает отрицательной.
struct HoloEnvelope {
    var value: Double = 0
    var velocity: Double = 0

    mutating func step(toward target: Double, omega: Double, dt: Double) {
        let offset = value - target
        let decay = exp(-omega * dt)
        let drive = velocity + omega * offset
        value = target + (offset + drive * dt) * decay
        velocity = (velocity - omega * drive * dt) * decay
        if value < 0 {
            value = 0
            velocity = max(velocity, 0)
        } else if value > 1 {
            value = 1
            velocity = min(velocity, 0)
        }
    }
}

// MARK: - Гироскоп

/// Гироскоп — один `CMMotionManager` на все экраны с обложкой в стопке, со счётчиком зрителей:
/// Apple советует один менеджер на приложение. Опрос без обработчика: свежий замер берёт кадр.
@MainActor
final class CoverHoloSensor {
    static let shared = CoverHoloSensor()

    private let manager = CMMotionManager()
    private var users = 0
    /// Замер, оставшийся от прошлого включения: его скорость — не нынешнее движение.
    private var staleTimestamp: TimeInterval = -1
    private var lastTimestamp: TimeInterval = -1
    /// Сколько времени кадров замер не обновлялся.
    private var sampleAge: Double = 0

    private init() {}

    func attach() {
        users += 1
        guard users == 1 else { return }
        staleTimestamp = manager.deviceMotion?.timestamp ?? -1
        lastTimestamp = -1
        sampleAge = 0
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = CoverHoloConfig.sensorInterval
        manager.startDeviceMotionUpdates()
    }

    func detach() {
        guard users > 0 else { return }
        users -= 1
        guard users == 0, manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    /// Скорость поворота телефона, рад/с: x > 0 — верх к глазу, y > 0 — правый край от глаза
    /// (правило правой руки CoreMotion). Нет свежего замера (симулятор, только включили,
    /// датчик встал) — ноль: интеграл просто утекает к покою.
    func rate(step dt: Double, clock: Double) -> SIMD2<Double> {
        guard users > 0 else { return .zero }
        #if DEBUG
        if Self.sweeps { return Self.sweepRate(at: clock) }
        #endif
        guard let motion = manager.deviceMotion, motion.timestamp > staleTimestamp else { return .zero }
        if motion.timestamp != lastTimestamp {
            lastTimestamp = motion.timestamp
            sampleAge = 0
        } else {
            sampleAge += dt
        }
        guard sampleAge < CoverHoloConfig.staleSample else { return .zero }
        return SIMD2(motion.rotationRate.x, motion.rotationRate.y)
    }

    #if DEBUG
    /// `-debugHoloSweep 1` — подставное качание ±14° по диагонали с периодом 4 с вместо
    /// гироскопа (на симуляторе его нет). Идёт тем же интегралом и пружинами, что живой замер.
    private static let sweeps = UserDefaults.standard.bool(forKey: "debugHoloSweep")

    private static func sweepRate(at time: Double) -> SIMD2<Double> {
        let amplitude = 14 * Double.pi / 180
        let period = 4.0
        let speed = amplitude * 2 * Double.pi / period * cos(2 * Double.pi * time / period)
        // Верх от глаза и левый край от глаза вместе — блик бежит из левого верхнего угла
        // через центр и обратно.
        return SIMD2(-speed, -speed) / 2.0.squareRoot()
    }
    #endif
}

// MARK: - Экран на виду

/// Экран на виду по UIKit: «да» — с конца появления (зум доехал), «нет» — с начала любого
/// ухода: поп, свайп назад, пуш поверх, `.fullScreen`-плеер. Отменённый свайп — снова «да».
/// SwiftUI о начале ухода не сообщает: `onDisappear` приходит, когда экрана уже нет. Тот же
/// приём, что у `ZoomPresenceTracker`, и стоит так же — вне ленты экрана.
struct CoverHoloPresence: UIViewControllerRepresentable {
    let onChange: (Bool) -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller(onChange: onChange)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onChange = onChange
    }

    final class Controller: UIViewController {
        var onChange: (Bool) -> Void

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            onChange(true)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // Свайп назад — эффект живёт, пока палец ведёт экран, и гаснет, только когда его
            // отпустили на закрытие (ревью 2026-10-31): иначе глянец пропадал под пальцем,
            // а на отменённом свайпе обложка мигала и разгоралась заново. До посадки обратного
            // зума после отпускания ~0.25 с — уход успевает. Отменённый свайп UIKit заканчивает
            // повторным `viewDidAppear`.
            guard let coordinator = transitionCoordinator, coordinator.isInteractive else {
                onChange(false)
                return
            }
            coordinator.notifyWhenInteractionChanges { [weak self] context in
                if !context.isCancelled { self?.onChange(false) }
            }
        }
    }
}
