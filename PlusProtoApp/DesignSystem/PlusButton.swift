import SwiftUI

// MARK: - Варианты

/// Тип кнопки — `Type` компонента `button` ДС (`7284:43450` файла `b8maDlvYFFs2vagJxwxc4A`).
/// Accent Yango Play и dark в прототип не берём: другой проект и тёмная кнопка нигде
/// не нужна (решение пользователя 2026-10-17).
enum PlusButtonType {
    /// Accent YaPS — градиент, вспышка, бордер-градиентом. Одна на экран.
    case accent
    /// Белый 8 % и бордер; под ними — фоновый блюр кнопок проекта (в ДС его нет, правка
    /// пользователя 2026-10-17: контент под кнопкой размывается).
    case secondary
    /// Secondary в хроме — стекло хрома `chromeGlass` (правка пользователя 2026-10-10:
    /// макетное стекло над светлыми обложками светлело, иконка тонула).
    case chrome
    /// Белая заливка, чёрные текст и иконка.
    case white
    /// Без фона.
    case plain
}

/// Размер — `Size` ДС: высота 32 / 40 / 48 / 52.
enum PlusButtonSize {
    case s, m, l, xl

    var height: CGFloat {
        switch self {
        case .s: 32
        case .m: 40
        case .l: 48
        case .xl: 52
        }
    }

    /// Бокс иконки — 16 / 20 / 24 / 24; ассет рисуется ровно в него.
    var iconBox: CGFloat {
        switch self {
        case .s: 16
        case .m: 20
        case .l, .xl: 24
        }
    }

    /// Text S・13 у S, Text M・15 у остальных — оба Semibold.
    var textSize: PlusTextSize { self == .s ? .textS : .textM }

    /// Поле со стороны текста
    var textInset: CGFloat {
        switch self {
        case .s: 16
        case .m: 20
        case .l: 24
        case .xl: 26
        }
    }

    /// Поле со стороны иконки
    var iconInset: CGFloat {
        switch self {
        case .s: 14
        case .m: 16
        case .l: 20
        case .xl: 22
        }
    }

    var iconGap: CGFloat {
        switch self {
        case .s, .m: 6
        case .l, .xl: 8
        }
    }

    /// Спиннер вместо содержимого (`preloader`)
    var spinner: CGFloat { self == .s ? 16 : 24 }

    /// Спиннер рядом с текстом (`preloader + text`): свой бокс, поле и зазор.
    var titledSpinner: CGFloat {
        switch self {
        case .s, .m: 16
        case .l, .xl: 20
        }
    }

    var titledSpinnerInset: CGFloat {
        switch self {
        case .s: 12
        case .m: 16
        case .l: 20
        case .xl: 22
        }
    }

    var titledSpinnerGap: CGFloat {
        switch self {
        case .s: 8
        case .m: 10
        case .l, .xl: 12
        }
    }

    /// Ширина кнопки с текстом — замером строки, до раскладки: скелетоны держат её место.
    func width(title: String, hasIcon: Bool = false) -> CGFloat {
        let font = textSize.uiFont(.semibold)
        let text = ceil((title as NSString).size(withAttributes: [.font: font]).width)
        let icon = hasIcon ? iconInset + iconBox + iconGap : textInset
        return icon + text + textInset
    }
}

/// Состояние — `State` ДС.
enum PlusButtonState: Equatable {
    case normal
    /// `preloader`: спиннер вместо содержимого, ширина кнопки прежняя
    case loading
    /// `preloader + text`: спиннер на месте иконки, текст остаётся
    case loadingWithTitle
    /// Текст и иконка — белый 30 %, у accent — подложка secondary без блюра; нажатий нет
    case disabled

    var isLoading: Bool { self == .loading || self == .loadingWithTitle }
}

enum PlusButtonIconPlacement {
    case leading, trailing
}

// MARK: - Кнопка

/// Кнопка ДС — одна на всё приложение: тип, размер, состояние, текст и/или иконка слева
/// или справа. Без текста — круг диаметром с высоту. Иконка — ассет (`icon:`) или свой
/// глиф в бокс `size.iconBox` (`PlayPauseGlyph`, `LikeGlyph`); подпись — строка или своё
/// содержимое набором кнопки (`title:`). Нажатие — `PressScaleButtonStyle`.
struct PlusButton<Icon: View, Title: View>: View {
    let label: PlusButtonLabel<Icon, Title>
    let accessibilityTitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) { label }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(label.state == .disabled || label.state.isLoading)
            .accessibilityLabel(accessibilityTitle ?? "")
    }
}

extension PlusButton where Title == Text {
    /// Текст и/или свой глиф.
    init(
        _ title: String? = nil,
        type: PlusButtonType,
        size: PlusButtonSize,
        iconPlacement: PlusButtonIconPlacement = .leading,
        state: PlusButtonState = .normal,
        fillsWidth: Bool = false,
        blursBackdrop: Bool = false,
        accessibilityTitle: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) {
        self.label = PlusButtonLabel(
            type: type,
            size: size,
            title: title.map { Text($0) },
            iconPlacement: iconPlacement,
            state: state,
            fillsWidth: fillsWidth,
            blursBackdrop: blursBackdrop,
            icon: icon()
        )
        self.accessibilityTitle = accessibilityTitle ?? title
        self.action = action
    }
}

extension PlusButton where Icon == PlusButtonAssetIcon, Title == Text {
    /// Иконка — ассет из ДС «Графика» (template, единый холст 16×16).
    init(
        _ title: String? = nil,
        icon: String,
        type: PlusButtonType,
        size: PlusButtonSize,
        iconPlacement: PlusButtonIconPlacement = .leading,
        state: PlusButtonState = .normal,
        fillsWidth: Bool = false,
        blursBackdrop: Bool = false,
        accessibilityTitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            title,
            type: type,
            size: size,
            iconPlacement: iconPlacement,
            state: state,
            fillsWidth: fillsWidth,
            blursBackdrop: blursBackdrop,
            accessibilityTitle: accessibilityTitle,
            action: action
        ) {
            PlusButtonAssetIcon(name: icon)
        }
    }
}

extension PlusButton where Icon == EmptyView, Title == Text {
    /// Только текст.
    init(
        _ title: String,
        type: PlusButtonType,
        size: PlusButtonSize,
        state: PlusButtonState = .normal,
        fillsWidth: Bool = false,
        accessibilityTitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            title,
            type: type,
            size: size,
            state: state,
            fillsWidth: fillsWidth,
            accessibilityTitle: accessibilityTitle,
            action: action
        ) {
            EmptyView()
        }
    }
}

extension PlusButton where Icon == EmptyView {
    /// Своя подпись — набирается стилем кнопки (у «Получить [Плюс] 100» знак между словами).
    init(
        type: PlusButtonType,
        size: PlusButtonSize,
        state: PlusButtonState = .normal,
        fillsWidth: Bool = false,
        accessibilityTitle: String,
        action: @escaping () -> Void,
        @ViewBuilder title: () -> Title
    ) {
        self.label = PlusButtonLabel(
            type: type,
            size: size,
            title: title(),
            iconPlacement: .leading,
            state: state,
            fillsWidth: fillsWidth,
            blursBackdrop: false,
            icon: EmptyView()
        )
        self.accessibilityTitle = accessibilityTitle
        self.action = action
    }
}

struct PlusButtonAssetIcon: View {
    let name: String

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
    }
}

// MARK: - Вид кнопки

/// Вид кнопки без жеста — для `PlusButton` и мест, где нажимается не кнопка, а то, что
/// под ней (знак ▶ на обложке, шеврон тоста, ярлык системного `Menu`).
struct PlusButtonLabel<Icon: View, Title: View>: View {
    let type: PlusButtonType
    let size: PlusButtonSize
    let title: Title?
    var iconPlacement: PlusButtonIconPlacement = .leading
    var state: PlusButtonState = .normal
    /// Растянуть на ширину контейнера — содержимое по центру
    var fillsWidth = false
    /// Фоновый блюр под plain — у ▶ блока «Похоже на» (инстанс макета с блюром поверх фото)
    var blursBackdrop = false
    let icon: Icon

    private var isIconOnly: Bool { title == nil }
    private var hasIcon: Bool { Icon.self != EmptyView.self }

    private var foreground: Color {
        switch type {
        case .white: .fillInverted
        default: state == .disabled ? .fillSeven : .fillOne
        }
    }

    var body: some View {
        content
            .foregroundStyle(foreground)
            .frame(height: size.height)
            .frame(width: isIconOnly ? size.height : nil)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .modifier(PlusButtonSurface(type: type, isDisabled: state == .disabled, blursBackdrop: blursBackdrop))
    }

    @ViewBuilder
    private var content: some View {
        if let title {
            let titledSpinner = state == .loadingWithTitle
            let showsIcon = hasIcon || titledSpinner
            let iconSide = titledSpinner ? size.titledSpinnerInset : size.iconInset
            HStack(spacing: titledSpinner ? size.titledSpinnerGap : size.iconGap) {
                if showsIcon && iconPlacement == .leading { iconSlot(titledSpinner: titledSpinner) }
                title
                    .plusText(size.textSize, .semibold)
                    .lineLimit(1)
                    .fixedSize()
                if showsIcon && iconPlacement == .trailing { iconSlot(titledSpinner: titledSpinner) }
            }
            .padding(.leading, showsIcon && iconPlacement == .leading ? iconSide : size.textInset)
            .padding(.trailing, showsIcon && iconPlacement == .trailing ? iconSide : size.textInset)
            .opacity(state == .loading ? 0 : 1)
            .overlay {
                if state == .loading { PlusSpinner(color: foreground, box: size.spinner) }
            }
        } else {
            iconView
                .opacity(state.isLoading ? 0 : 1)
                .overlay {
                    if state.isLoading { PlusSpinner(color: foreground, box: size.spinner) }
                }
        }
    }

    @ViewBuilder
    private func iconSlot(titledSpinner: Bool) -> some View {
        if titledSpinner {
            PlusSpinner(color: foreground, box: size.titledSpinner)
        } else {
            iconView
        }
    }

    private var iconView: some View {
        icon.frame(width: size.iconBox, height: size.iconBox)
    }
}

extension PlusButtonLabel where Title == Text {
    init(
        _ title: String? = nil,
        type: PlusButtonType,
        size: PlusButtonSize,
        iconPlacement: PlusButtonIconPlacement = .leading,
        state: PlusButtonState = .normal,
        @ViewBuilder icon: () -> Icon
    ) {
        self.init(
            type: type,
            size: size,
            title: title.map { Text($0) },
            iconPlacement: iconPlacement,
            state: state,
            icon: icon()
        )
    }
}

extension PlusButtonLabel where Icon == PlusButtonAssetIcon, Title == Text {
    init(_ title: String? = nil, icon: String, type: PlusButtonType, size: PlusButtonSize) {
        self.init(title, type: type, size: size) { PlusButtonAssetIcon(name: icon) }
    }
}

// MARK: - Подложка

/// Подложка одним деревом на все типы: смена типа (secondary → white у ✓ и реакций)
/// перекрашивает слои, а не пересоздаёт кнопку — анимируется снаружи как обычно.
/// Форма — капсула (сглаживание углов ДС 0.6 — `.continuous`): на квадратной кнопке она круг.
private struct PlusButtonSurface: ViewModifier {
    let type: PlusButtonType
    let isDisabled: Bool
    let blursBackdrop: Bool

    @AppStorage(ChromeGlass.dimKey) private var chromeDim = ChromeGlass.defaultDim

    private var blur: CGFloat {
        switch type {
        case .secondary: PlusMetrics.buttonBlur
        case .chrome: PlusMetrics.glassBlur
        case .plain: blursBackdrop ? PlusMetrics.buttonBlur : 0
        case .accent, .white: 0
        }
    }

    private var fill: Color {
        switch type {
        case .accent: isDisabled ? .buttonsPrimary : .clear
        case .secondary: .buttonsSecondary
        case .chrome: .buttonsPrimary
        case .white: .buttonsInverted
        case .plain: .clear
        }
    }

    private var border: Color {
        switch type {
        case .accent: isDisabled ? SecondaryButtonBorder.color : .clear
        case .secondary, .chrome: SecondaryButtonBorder.color
        case .white, .plain: .clear
        }
    }

    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        content
            .background {
                ZStack {
                    if blur > 0 {
                        BackdropBlurView(radius: blur)
                    }
                    if type == .chrome {
                        Color.black.opacity(chromeDim)
                    }
                    fill
                    if type == .accent {
                        AccentYaPSFill(shape: shape)
                            .opacity(isDisabled ? 0 : 1)
                    }
                }
                .clipShape(shape)
            }
            .overlay {
                shape.strokeBorder(border, lineWidth: SecondaryButtonBorder.width)
            }
            .contentShape(shape)
    }
}

// MARK: - Спиннер

enum PlusSpinnerConfig {
    /// Оборот — секунда, как у системного индикатора
    static let period: Double = 1
    /// Дуга — 254° от верха по часовой: хвост прозрачен до 18°, проявляется к 183°,
    /// голова непрозрачна (угловой градиент маски `spinner` ДС)
    static let sweep: CGFloat = 254 / 360
    static let tailClear: CGFloat = 18 / 360
    static let tailOpaque: CGFloat = 183 / 360
    /// Толщина — 3 на 24, у меньших — тем же отношением
    static let lineRatio: CGFloat = 3 / 24
    /// Reduce Motion: вместо вращения — пульс прозрачности
    static let pulsePeriod: Double = 1.6
    static let pulseFloor: Double = 0.4
}

/// Спиннер ДС: дуга с прозрачным хвостом, вращается по часовой. Угол — функция времени,
/// `TimelineView` живёт только пока спиннер в дереве.
struct PlusSpinner: View {
    let color: Color
    let box: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Config = PlusSpinnerConfig

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            arc
                .rotationEffect(reduceMotion ? .zero : .degrees(time.truncatingRemainder(dividingBy: Config.period) / Config.period * 360))
                .opacity(reduceMotion ? pulse(time) : 1)
        }
        .frame(width: box, height: box)
        .accessibilityHidden(true)
    }

    private var arc: some View {
        let line = box * Config.lineRatio
        return Circle()
            .inset(by: line / 2)
            .trim(from: 0, to: Config.sweep)
            .stroke(
                AngularGradient(
                    stops: [
                        .init(color: color.opacity(0), location: 0),
                        .init(color: color.opacity(0), location: Config.tailClear),
                        .init(color: color, location: Config.tailOpaque),
                        .init(color: color, location: Config.sweep + 0.05),
                        // Круглый торец хвоста заходит за 0° — там снова прозрачно
                        .init(color: color.opacity(0), location: Config.sweep + 0.1),
                        .init(color: color.opacity(0), location: 1),
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: line, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }

    private func pulse(_ time: Double) -> Double {
        let phase = (1 - cos(time / Config.pulsePeriod * 2 * .pi)) / 2
        return Config.pulseFloor + (1 - Config.pulseFloor) * phase
    }
}
