import CoreMotion
import QuartzCore
import simd
import SwiftUI
import UIKit

// MARK: - Числа

/// Рефлексы обложки (голография — просьба пользователя 2026-10-31; рефлексы вместо неё —
/// 2026-11-04: «слишком примитивное, не даёт глубины, объёма, натуральности»): обложка —
/// глянцевая печать, в которой отражается студия за спиной смотрящего, и от наклона телефона
/// отражение ходит по ней, как по настоящему лаку; кромка-фаска ловит свет, а карточка едва
/// заметно плавает в перспективе. Одна на все крупные обложки: экраны альбома, плейлиста
/// и книги и центральная обложка большого плеера музыки. Всё — «едва заметно»: на эти экраны
/// заходят часто. Оптика (луч на пиксель, студия, Френель, фаска, рельеф) — в `CoverHolo.metal`.
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

    /// Опрос — 100 Гц: запрос 1/60 на деле даёт ~52 Гц, и поза отставала бы от руки.
    static let sensorInterval: TimeInterval = 1.0 / 100
    /// Замер не обновлялся дольше — датчик встал: его последняя скорость интегрировалась бы
    /// в поворот, которого нет.
    static let staleSample: Double = 0.1

    // MARK: Движение

    /// Память наклона карточки (интеграл скорости с утечкой): она всплывает обратно к экрану
    /// за 1–2 с. Свет так не утекает — он функция позы относительно опоры.
    static let tiltMemory: Double = 1.4
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

    // MARK: Свет

    /// Сглаживание света — экспонента τ 60 мс: гасит ступени замеров на кадрах 120 Гц, но не
    /// даёт «анимации вдогонку» (у Telegram Wallet τ 0.1 с; прежняя пружина ω 9 — 0.2 с лага).
    static let lightSmoothing: Double = 0.06
    /// Замер доводится по скорости поворота на свой возраст и ещё на 8 мс вперёд, не дальше 25 мс.
    static let attitudeLead: Double = 0.008
    static let attitudeLeadLimit: Double = 0.025
    /// Перезахват опоры (системный свет Apple): наклон дальше 30° от опоры дольше 1.5 с или
    /// полный поворот дальше 60° дольше 0.3 с — провал яркости 0.8 с, в его середине опора
    /// защёлкивается на позу.
    static let farAngle: Double = 30 * .pi / 180
    static let farHold: Double = 1.5
    static let veryFarAngle: Double = 60 * .pi / 180
    static let veryFarHold: Double = 0.3
    static let dipDuration: Double = 0.8

    // MARK: Полоса

    /// Свет в опоре — сверху слева спереди (оси CoreMotion, y вверх): в покое полоса стоит
    /// поперёк левой верхней диагонали (как у Telegram Wallet, `normalize(−0.5, 0.5, 1)`).
    static let lightRest = simd_normalize(SIMD3<Double>(-0.5, 0.5, 1))
    /// В покое середина полосы — в 0.72 стороны от центра к свету: ядро только что за левым
    /// верхним углом, в углу — ореол. Обложка чистая, «эффекта почти нет».
    static let stripeRest: Double = 0.72
    /// Ход полосы — 1.75 стороны на радиан изменения угла света: обложку она проходит за ~33°
    /// наклона, как у продуктов (pokemon-cards-css 32–36°, Telegram 30–37°).
    static let stripeTravel: Double = 1.75
    /// Свет почти в лоб (проекция короче 0.1) — направление на экране неустойчиво, угол
    /// полосы держится; сглаживание угла — τ 0.1 с (Telegram Wallet).
    static let angleHold: Double = 0.1
    static let angleSmoothing: Double = 0.1
    /// Сила от отклонения позы: в покое половина, полная — с 12° (Telegram QR, holo_card;
    /// в покое 65 % — «надо снизить заметность», правка пользователя 2026-11-04).
    static let gateBase: Double = 0.5
    static let gateFull: Double = 12 * .pi / 180

    // MARK: Кольцевая лампа

    /// Кольцо радиусом 24° — на обложке заметная дуга (при 55° она была почти прямой, и вариант
    /// не отличался от полосы); в покое оно проходит в 14° от оси взгляда сверху слева — сразу
    /// за левым верхним углом.
    static let lampRadius: Double = 24 * .pi / 180
    static let lampOffset: Double = 14 * .pi / 180
    /// Наклон для лампы — 1.6 настоящего, как у глянца в руке (глаз неподвижен в мире —
    /// отражение уходит на 2θ): обложка проходится за ~10°, блик живой и быстрый. Поворот
    /// в плоскости — 1:1.
    static let lampSwing: Double = 1.6

    /// Общая сила отражения и света — множитель рецепта шейдера, для подстройки по фидбеку.
    static let intensity: Double = 1
    /// Как далеко шейдер читает соседей — кромка до 2.4 pt (`kEdgeWidth`) с запасом на сглаживание.
    static let sampleReach = CGSize(width: 3, height: 3)
}

// MARK: - Поза

/// Эффект на один кадр. Покой (`rest`) — ровно обычная обложка: шейдер выключен,
/// трансформа единичная.
struct CoverHoloPose: Equatable {
    /// Наклон карточки, рад (оси CoreMotion) — уже умножен на огибающую.
    var tilt = SIMD2<Double>.zero
    /// Свет: поворот из осей телефона в опоре в его нынешние оси. Неподвижный в мире вектор `v`
    /// в нынешних осях — `light.act(v)`.
    var light = CoverLight.identity
    /// Нормаль полосы на экране (y вниз), к свету — сглаженный угол проекции света.
    var stripe = SIMD2<Double>(-0.5.squareRoot(), -0.5.squareRoot())
    /// Сила отражения и света — огибающая × `intensity`.
    var amount: Double = 0

    static let rest = CoverHoloPose()
}

// MARK: - Модификатор

extension View {
    /// Рефлексы и едва заметный плавающий наклон — на готовую обложку (картинка, скругление,
    /// кромка). Раскладку не меняет.
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
    /// Вариант рефлекса — дебаг-меню (`CoverSheenStyle`), меняется на лету.
    @AppStorage(CoverSheenStyle.storageKey) private var style: CoverSheenStyle = .defaultStyle

    func body(content: Content) -> some View {
        let margin = CoverHoloConfig.margin
        let scale = displayScale
        return TimelineView(.animation(paused: motion.isSettled)) { context in
            let pose = motion.pose(at: context.date)
            content
                .padding(margin)
                // Наклон — до шейдера: картинка пересэмплируется один раз, а отражение ложится
                // на растр, который выводится на экран как есть. Слой, а не цвет: шейдер читает
                // соседей — край обложки для фаски и рельеф краски.
                .modifier(CoverHoloTilt(rotation: pose.tilt))
                .layerEffect(
                    CoverHoloShader.make(pose, style: style, margin: margin, scale: scale),
                    maxSampleOffset: CoverHoloConfig.sampleReach,
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

/// Шейдер рефлексов (`Shaders/CoverHolo.metal`). Один конструктор и на кадр, и на прогрев:
/// у прогретого пайплайна та же раскладка аргументов.
enum CoverHoloShader {
    static func make(_ pose: CoverHoloPose, style: CoverSheenStyle, margin: CGFloat, scale: CGFloat) -> Shader {
        typealias C = CoverHoloConfig
        let toLight = pose.light.act(C.lightRest)
        let away = CoverLight.angle(of: pose.light)
        let gate = C.gateBase + (1 - C.gateBase) * smoothstep(away / C.gateFull)
        let geometry: SIMD4<Double>
        switch style {
        case .stripe, .pearl:
            // Наклон (swing) двигает и поворачивает полосу: середина идёт за смещением угла
            // света на экране (направление проекции × угол от нормали, рад) × ход — непрерывно
            // и при свете в лоб. Поворот в плоскости (twist) поворачивает всю картину жёстко
            // вокруг центра обложки — полоса стоит по уровню мира.
            let rest = angularOffset(C.lightRest)
            let swung = CoverLight.swing(of: pose.light).act(C.lightRest)
            let center = simd_normalize(rest) * C.stripeRest + (angularOffset(swung) - rest) * C.stripeTravel
            let twist = CoverLight.twistAngle(of: pose.light)
            let normal = screenRotation(pose.stripe, by: twist)
            let point = screenRotation(center, by: twist)
            geometry = SIMD4(normal.x, normal.y, point.x, point.y)
        case .lamp:
            // Кольцо закреплено в мире; наклон для него — 1.6 настоящего, поворот в плоскости — весь.
            let center = CoverLight.scaledSwing(pose.light, by: C.lampSwing).act(lampCenter)
            geometry = SIMD4(center.x, center.y, center.z, C.lampRadius)
        case .edge:
            // Лицо обложки чистое — шейдеру нужен только свет для кромки.
            geometry = .zero
        }
        return ShaderLibrary.coverHolo(
            .boundingRect,
            .float(margin),
            .float4(geometry.x, geometry.y, geometry.z, geometry.w),
            .float4(toLight.x, toLight.y, toLight.z, gate),
            .float(pose.amount),
            .float(style.shaderIndex),
            .float(scale)
        )
    }

    /// Центр кольца в опоре: сверху слева, в радиус + 12° от оси взгляда — ближайшая к оси
    /// точка кольца лежит в 12° от неё, к левому верхнему углу.
    private static let lampCenter: SIMD3<Double> = {
        let tilt = CoverHoloConfig.lampRadius + CoverHoloConfig.lampOffset
        let side = 0.5.squareRoot()
        return SIMD3(-side * sin(tilt), side * sin(tilt), cos(tilt))
    }()

    /// Угловое смещение света от нормали на экране: направление проекции (y вниз) × угол, рад.
    private static func angularOffset(_ light: SIMD3<Double>) -> SIMD2<Double> {
        let projected = SIMD2(light.x, -light.y)
        let spread = simd_length(projected)
        guard spread > 1e-9 else { return .zero }
        return projected / spread * acos(min(max(light.z, -1), 1))
    }

    /// Поворот на `angle` в осях CoreMotion (y вверх, против часовой) — вектор экрана (y вниз):
    /// там он идёт по часовой.
    private static func screenRotation(_ v: SIMD2<Double>, by angle: Double) -> SIMD2<Double> {
        let (sine, cosine) = (sin(angle), cos(angle))
        return SIMD2(v.x * cosine + v.y * sine, -v.x * sine + v.y * cosine)
    }

    /// Гладкая ступень 0…1 без излома.
    private static func smoothstep(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Под заставкой (`AppRootView.prepareShowcase`): первое отражение на экране обложки
    /// не тратит кадр на сборку пайплайна. Заодно создаётся менеджер CoreMotion — первое
    /// обращение к демону тоже не должно прийтись на экран.
    @MainActor
    static func prewarm() async {
        _ = CoverHoloSensor.shared
        try? await make(.rest, style: .stripe, margin: CoverHoloConfig.margin, scale: 3).compile(as: .layerEffect)
    }
}

// MARK: - Движение

/// Фильтры и огибающая. Покадровое — в обычных полях (`@ObservationIgnored`): запись из тела
/// кадра вью не инвалидирует. Наблюдаем только `isSettled`, и меняется он событиями — на
/// включении и следующим тактом после того, как эффект погас, — а не на каждом кадре.
///
/// Свет — поза телефона относительно опоры по всем трём осям (кватернион CoreMotion), а не
/// интеграл скорости с утечкой (исследование 2026-11-04: у Telegram Wallet, системного света
/// iOS 26, LookingGlassUI, pokemon-cards-css блик — функция позы относительно опоры).
/// Удержанный наклон держит блик, возврат позы возвращает вид, поворот в плоскости экрана
/// поворачивает полосу 1:1, как у настоящего глянца. Опора снимается на каждом включении
/// эффекта. Ушли от неё далеко и надолго (легли, развернулись) — она перезахватывается под
/// провалом яркости, как у системного света Apple: блик гаснет, опора защёлкивается на нынешнюю
/// позу, блик загорается уже в покое — скольжения к покою нет.
/// Наклон карточки («тело») — по-прежнему интеграл скорости с утечкой и пружина.
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
    /// Поворот телефона с утечкой — то, что «видит» карточка (оси CoreMotion, рад).
    @ObservationIgnored private var tiltTurn = SIMD2<Double>.zero
    @ObservationIgnored private var tiltSpring = HoloSpring()
    /// Опора света — ориентация телефона (оси телефона → мир) на включении эффекта.
    @ObservationIgnored private var reference: simd_quatd?
    /// Свет: поворот из осей телефона в опоре в его нынешние оси, сглаженный.
    @ObservationIgnored private var light = CoverLight.identity
    /// Нормаль полосы на экране — угол проекции света, сглаженный; `nil` — ещё не было света.
    @ObservationIgnored private var stripe: SIMD2<Double>?
    /// Провал яркости с перезахватом опоры: фаза 0…1, `nil` — провала нет.
    @ObservationIgnored private var dip: Double?
    /// Сколько секунд поза держится далеко и очень далеко от опоры.
    @ObservationIgnored private var farTime: Double = 0
    @ObservationIgnored private var veryFarTime: Double = 0
    /// Время кадров — для плавания: на фризах и паузах стоит вместе со всем остальным.
    @ObservationIgnored private var clock: Double = 0
    @ObservationIgnored private var lastDate: Date?
    @ObservationIgnored private var lastPose = CoverHoloPose.rest
    @ObservationIgnored private var isSensing = false
    @ObservationIgnored private var isSettlePending = false

    // MARK: События — не из кадра

    /// Эффекту можно жить: огибающая идёт к единице с того места, где была. Опора света —
    /// заново: первый замер после включения.
    func activate() {
        target = 1
        reference = nil
        dip = nil
        attachSensor()
        guard isSettled else { return }
        // С паузы: дата последнего кадра устарела — первый кадр идёт без шага.
        lastDate = nil
        isSettled = false
    }

    /// Начался уход: огибающая к нулю. Гироскоп больше не нужен — свет стоит, где был.
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
        let sensor = CoverHoloSensor.shared

        // 1. Карточка: интеграл скорости с утечкой — точное решение для постоянной на шаге
        //    скорости, на 60 и 120 Гц одно и то же; тело с инерцией.
        let rate = isSensing ? sensor.rate(step: dt, clock: clock) : .zero
        tiltTurn = Self.leak(tiltTurn, rate: rate, memory: C.tiltMemory, dt: dt)
        tiltSpring.step(toward: tiltTurn, omega: C.tiltResponse, damping: C.tiltDamping, dt: dt)

        // 2. Свет — поза относительно опоры. Без датчика (уход, ещё нет замера) стоит, где был.
        if isSensing, let attitude = sensor.attitude(clock: clock) {
            followLight(attitude, dt: dt)
        }
        followStripe(dt: dt)

        // 3. Огибающая: смена цели меняет только цель и жёсткость — значение и скорость те же.
        envelope.step(toward: target, omega: target > 0 ? C.riseResponse : C.fallResponse, dt: dt)

        // 4. Погасло — всё в ноль (невидимо: огибающая уже в нуле), `TimelineView` встаёт.
        if target == 0, envelope.value < C.settleLevel, abs(envelope.velocity) < C.settleSpeed {
            restAll()
            scheduleSettle()
        }
    }

    /// Свет за позой: поворот из осей опоры в нынешние, перезахват опоры под провалом
    /// и короткое сглаживание — гасит ступени замеров 100 Гц на кадрах 120 Гц, но не даёт
    /// «анимации вдогонку» (τ 60 мс против 0.2 с лага прежней пружины).
    private func followLight(_ attitude: simd_quatd, dt: Double) {
        typealias C = CoverHoloConfig
        #if DEBUG
        if let fixed = CoverHoloSensor.fixedLight {
            light = fixed
            return
        }
        #endif
        guard let anchor = reference else {
            reference = attitude
            light = CoverLight.identity
            return
        }
        var relative = (attitude.conjugate * anchor).normalized

        if let phase = dip {
            let next = phase + dt / C.dipDuration
            // Середина провала — блика не видно: опора защёлкивается на нынешнюю позу.
            if phase < 0.5, next >= 0.5 {
                reference = attitude
                relative = CoverLight.identity
                light = relative
            }
            dip = next >= 1 ? nil : next
        } else {
            // «Далеко» — по наклону: поворот в плоскости экрана законен (полоса стоит по уровню
            // мира), его держат, разглядывая. «Очень далеко» — по полному повороту (лёг на бок).
            farTime = CoverLight.angle(of: CoverLight.swing(of: relative)) > C.farAngle ? farTime + dt : 0
            veryFarTime = CoverLight.angle(of: relative) > C.veryFarAngle ? veryFarTime + dt : 0
            if farTime > C.farHold || veryFarTime > C.veryFarHold {
                dip = 0
                farTime = 0
                veryFarTime = 0
            }
        }
        light = simd_slerp(light, relative, 1 - exp(-dt / C.lightSmoothing)).normalized
    }

    /// Угол полосы — угол проекции света на экран (Telegram Wallet): поворот в плоскости — 1:1,
    /// наклон — ~0.85° на градус. Полоса — линия: угол берётся по модулю π, к ближайшему,
    /// и нормаль разворачивается к свету. Свет почти в лоб — угол держится.
    private func followStripe(dt: Double) {
        typealias C = CoverHoloConfig
        // Угол — от наклона без поворота в плоскости: тот добавляется жёстко при сборке позы.
        let toLight = CoverLight.swing(of: light).act(C.lightRest)
        let projected = SIMD2(toLight.x, -toLight.y)
        let spread = simd_length(projected)
        guard spread >= C.angleHold else { return }
        let target = projected / spread
        guard let current = stripe else {
            stripe = target
            return
        }
        let angle = atan2(current.y, current.x)
        let turn = remainder(atan2(target.y, target.x) - angle, .pi)
        let next = angle + turn * (1 - exp(-dt / C.angleSmoothing))
        var normal = SIMD2(cos(next), sin(next))
        if simd_dot(normal, target) < 0 { normal = -normal }
        stripe = normal
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
        // Наклон и плавание карточки в свет не идут: плавание сдвигало бы блик при неподвижном
        // телефоне, а отражение, которое движется само, читается фальшью (исследование 2026-11-04).
        var pose = CoverHoloPose(
            tilt: relative * strength,
            light: light,
            amount: strength * C.intensity * CoverLight.dipLevel(dip)
        )
        if let stripe { pose.stripe = stripe }
        return pose
    }

    private func restAll() {
        envelope = HoloEnvelope()
        tiltTurn = .zero
        tiltSpring = HoloSpring()
        reference = nil
        light = CoverLight.identity
        stripe = nil
        dip = nil
        farTime = 0
        veryFarTime = 0
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

/// Кватернионы света. Оси CoreMotion: x вправо, y вверх, z из экрана к глазу; поворот
/// по x > 0 — верх к глазу, по y > 0 — правый край от глаза, по z > 0 — против часовой.
enum CoverLight {
    static let identity = simd_quatd(ix: 0, iy: 0, iz: 0, r: 1)

    /// Поворот телефона: сперва вокруг x, потом y, потом z (для малых углов порядок не важен).
    static func rotation(x: Double, y: Double, z: Double) -> simd_quatd {
        let qx = simd_quatd(angle: x, axis: SIMD3(1, 0, 0))
        let qy = simd_quatd(angle: y, axis: SIMD3(0, 1, 0))
        let qz = simd_quatd(angle: z, axis: SIMD3(0, 0, 1))
        return (qz * qy * qx).normalized
    }

    /// Поворот в плоскости экрана (twist вокруг z) — проекция кватерниона на ось z; одинаков
    /// для разложений q = swing · twist и q = twist · swing (ось наклона лежит в плоскости xy).
    static func twist(of q: simd_quatd) -> simd_quatd {
        let raw = simd_quatd(ix: 0, iy: 0, iz: q.imag.z, r: q.real)
        guard simd_length(raw.vector) > 1e-9 else { return identity }
        return raw.normalized
    }

    /// Угол поворота в плоскости, рад: > 0 — против часовой в осях CoreMotion.
    static func twistAngle(of q: simd_quatd) -> Double {
        let t = twist(of: q)
        return 2 * atan2(t.imag.z, t.real)
    }

    /// Наклон без поворота в плоскости: q = twist · swing → swing = twist⁻¹ · q.
    static func swing(of q: simd_quatd) -> simd_quatd {
        (twist(of: q).conjugate * q).normalized
    }

    /// Наклон (swing) масштабирован, поворот в плоскости экрана (twist вокруг z) — целиком:
    /// q = twist · swing, twist — проекция q на ось z.
    static func scaledSwing(_ q: simd_quatd, by factor: Double) -> simd_quatd {
        let turn = twist(of: q)
        let tilt = (turn.conjugate * q).normalized
        // Угол наклона × factor вокруг той же оси — без экстраполяции slerp за единицу.
        let tiltAngle = angle(of: tilt)
        guard tiltAngle > 1e-9 else { return q }
        let axis = simd_normalize(tilt.imag) * (tilt.real < 0 ? -1 : 1)
        return (turn * simd_quatd(angle: tiltAngle * factor, axis: axis)).normalized
    }

    /// Полный угол поворота, рад (0…π).
    static func angle(of q: simd_quatd) -> Double {
        2 * acos(min(abs(q.real), 1))
    }

    /// Яркость в провале с перезахватом опоры (системный свет Apple, iOS 26.1):
    /// I(t) = 1 − (1 − 4(t − ½)²)² — гладко 1 → 0 → 1, ноль ровно в середине.
    static func dipLevel(_ phase: Double?) -> Double {
        guard let t = phase else { return 1 }
        let u = 1 - 4 * (t - 0.5) * (t - 0.5)
        return 1 - u * u
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
        // Опора по вертикали, курс произвольный: свету нужен только поворот относительно
        // опоры, а магнитометр с его калибровкой ни к чему.
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
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

    /// Ориентация телефона (оси телефона → мир) к кадру: замер, доведённый по скорости
    /// поворота на его возраст и чуть вперёд — замеры 100 Гц приходят с опозданием, и свет
    /// без этого отставал бы от руки. Нет свежего замера — `nil`, свет стоит. На симуляторе
    /// датчика нет — медленное синтетическое покачивание, чтобы эффект было видно.
    func attitude(clock: Double) -> simd_quatd? {
        guard users > 0 else { return nil }
        #if DEBUG
        if Self.sweeps { return Self.sweepAttitude(at: clock) }
        #endif
        guard manager.isDeviceMotionAvailable else { return Self.idleAttitude(at: clock) }
        guard let motion = manager.deviceMotion, motion.timestamp > staleTimestamp else { return nil }
        let q = motion.attitude.quaternion
        var attitude = simd_quatd(ix: q.x, iy: q.y, iz: q.z, r: q.w)
        // Возраст замера по часам CoreMotion (с загрузки) и анимации (`CACurrentMediaTime`) —
        // один отсчёт; расхождение больше разумного — без доводки.
        let lag = CACurrentMediaTime() - motion.timestamp
        guard lag >= 0, lag < CoverHoloConfig.staleSample else { return attitude.normalized }
        let lead = min(lag + CoverHoloConfig.attitudeLead, CoverHoloConfig.attitudeLeadLimit)
        let spin = SIMD3(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
        let speed = simd_length(spin)
        if speed * lead > 1e-6 {
            // Скорость — в осях телефона: доворот справа.
            attitude = attitude * simd_quatd(angle: speed * lead, axis: spin / speed)
        }
        return attitude.normalized
    }

    /// Синтетическая поза без датчика (симулятор): тангаж ±4°, крен ±6°, рыскание ±3°
    /// с некратными периодами — полоса видна и медленно ходит, как в руке.
    private static func idleAttitude(at time: Double) -> simd_quatd {
        let degree = Double.pi / 180
        return CoverLight.rotation(
            x: 4 * degree * sin(2 * .pi * time / 7.7),
            y: 3 * degree * sin(2 * .pi * time / 9.1 + 1.1),
            z: 6 * degree * sin(2 * .pi * time / 11.3 + 2.3)
        )
    }

    #if DEBUG
    /// `-debugHoloSweep 1` — подставное качание вместо датчика: наклон ±14° по диагонали
    /// (верх от глаза и левый край от глаза вместе) с периодом 4 с и поворот в плоскости
    /// экрана ±12° с периодом 6 с. Идёт тем же путём, что живой замер.
    private static let sweeps = UserDefaults.standard.bool(forKey: "debugHoloSweep")

    private static func sweepRate(at time: Double) -> SIMD2<Double> {
        let amplitude = 14 * Double.pi / 180
        let period = 4.0
        let speed = amplitude * 2 * Double.pi / period * cos(2 * Double.pi * time / period)
        return SIMD2(-speed, -speed) / 2.0.squareRoot()
    }

    private static func sweepAttitude(at time: Double) -> simd_quatd {
        let degree = Double.pi / 180
        let swing = 14 * degree * sin(2 * .pi * time / 4) / 2.0.squareRoot()
        return CoverLight.rotation(x: -swing, y: -swing, z: 12 * degree * sin(2 * .pi * time / 6))
    }

    /// `-debugHoloTurn "(<x>,<y>)"` или `"(<x>,<y>,<z>)"` — свет замирает в позе: поворот
    /// телефона от опоры, градусы в осях CoreMotion (x > 0 — верх к глазу, y > 0 — правый
    /// край от глаза, z > 0 — против часовой). Кадр рефлекса в одной позе, чтобы сравнивать
    /// скриншоты. Скобки обязательны: значение с минусом в начале UserDefaults принимает
    /// за следующий ключ, а «(…)» читает массивом.
    static let fixedLight: simd_quatd? = {
        let raw = UserDefaults.standard.object(forKey: "debugHoloTurn")
        let items = (raw as? [Any]) ?? (raw as? String)?.split(separator: ",").map { String($0) } ?? []
        let parts = items.compactMap { Double(String(describing: $0).trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let degree = Double.pi / 180
        let device = CoverLight.rotation(
            x: parts[0] * degree,
            y: parts[1] * degree,
            z: (parts.count == 3 ? parts[2] : 0) * degree
        )
        // Телефон повернулся — свет, неподвижный в мире, в его осях повернулся обратно.
        return device.conjugate
    }()
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
