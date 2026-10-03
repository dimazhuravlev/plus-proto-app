import SwiftUI

/// Семейства шрифтов. В проекте ровно два: YS Display (акцидентные заголовки) и YS Text
/// (тексты), каждое в двух начертаниях. Отдельного файла Semibold в семействе не существует —
/// в Figma переменная `Font Weight/Semibold` резолвится в Bold(700), поэтому Semibold ≡ Bold.
///
/// Набирать текст напрямую этими именами нельзя — только стилями UI kit ниже:
/// `plusText(_:_:)` для YS Text и `plusHeadline(_:)` для YS Display.
enum PlusFont {
    static let displayMedium = "YSDisplay-Medium"
    static let displaySemibold = "YSDisplay-Bold"
    static let textMedium = "YSText-Medium"
    static let textSemibold = "YSText-Bold"
}

/// Точная типографика из Figma: кегль + межстрочное + трекинг.
/// SwiftUI берёт натуральный lineHeight шрифта, а в макете он задан явно —
/// разницу компенсируем через lineSpacing и симметричный вертикальный отступ.
/// Годится, пока интерлиньяж не меньше натурального: `lineSpacing` умеет только
/// прибавлять. У стилей YS Text так и есть, у шкалы YS Display — нет, там точная
/// высота строки (`plusHeadline`).
private struct FigmaTextStyle: ViewModifier {
    let family: String
    let size: CGFloat
    let lineHeight: CGFloat
    let tracking: CGFloat

    func body(content: Content) -> some View {
        let natural = (UIFont(name: family, size: size) ?? .systemFont(ofSize: size)).lineHeight
        let delta = lineHeight - natural
        return content
            .font(.custom(family, size: size))
            .tracking(tracking)
            .lineSpacing(delta)
            .padding(.vertical, delta / 2)
    }
}

/// Многострочный текст с межстрочным интервалом ровно как в макете.
///
/// У YS натуральный интервал 1.172em — на кегле 32 это 37.5pt против макетных 36,
/// и на трёх строках заголовка набегает 4.5pt. `lineSpacing` умеет только прибавлять,
/// а `paragraphStyle` в `AttributedString` SwiftUI игнорирует (замер дал шаг 37.6 вместо 36).
///
/// Поэтому строки набираются отдельными `Text` в стеке с точным — при необходимости
/// отрицательным — зазором. Переносы задаёт сам текст через `\n`: в макете они
/// расставлены под врезки между словами, автоперенос их бы не повторил.
/// Живёт ради заголовка витрины — см. исключение у `PlusHeadline`.
struct FigmaText: View {
    let text: String
    let family: String
    let size: CGFloat
    let lineHeight: CGFloat
    let tracking: CGFloat

    private var lineGap: CGFloat {
        let natural = (UIFont(name: family, size: size) ?? .systemFont(ofSize: size)).lineHeight
        return lineHeight - natural
    }

    var body: some View {
        VStack(alignment: .leading, spacing: lineGap) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.custom(family, size: size))
                    .tracking(tracking)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - UI kit: стили YS Text

/// Кегль стиля YS Text — переменные UI kit «🧩 Mobile · Library» (`7529:1713`),
/// правила работы — там же (`7529:2161`). Других стилей YS Text в проекте нет и быть
/// не может (решение пользователя 2026-10-03).
///
/// Правила, по которым стиль выбирается на месте применения:
/// - кегля только пять; текст крупнее 24 — сигнал, что нужен YS Display (`plusHeadline`);
/// - начертания: Semibold — для 18 и 24, Medium — для 11, 13 и 15; исключение —
///   тексты всех кнопок и хедер навбара экрана, там 15 Semibold;
/// - трекинг везде 0;
/// - цвета текста — `fillOne`, `fillFour` (блоки длиннее двух строк), `fillSubtitle`
///   и инвертированный чёрный на белых поверхностях;
/// - иерархические пары: 13M + 13M, 15M + 15M, 15M + 13M, 18SB + 15M, 18SB + 18SB, 24SB + 15M.
enum PlusTextSize {
    /// Title S・24/28 — заголовки коммуникационных форматов (`title_S`)
    case titleS
    /// Text L・18/24 — заголовки блоков, модулей, каруселей (`text_L`)
    case textL
    /// Text M・15/20 — базовый кегль: заголовки и подзаголовки айтемов, блоки текста
    /// (`text_m_medium`), тексты кнопок (`text_m_semibold`)
    case textM
    /// Text S・13/16 — второстепенные подписи, дескрипшены (`text_S`)
    case textS
    /// Text XS・11/14 — подписи иконок таббара, каунтер тайтла (`text_XS`)
    case textXS

    var size: CGFloat {
        switch self {
        case .titleS: 24
        case .textL: 18
        case .textM: 15
        case .textS: 13
        case .textXS: 11
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .titleS: 28
        case .textL: 24
        case .textM: 20
        case .textS: 16
        case .textXS: 14
        }
    }
}

/// Начертание стиля YS Text — их только два.
enum PlusTextWeight {
    case semibold
    case medium

    var family: String {
        switch self {
        case .semibold: PlusFont.textSemibold
        case .medium: PlusFont.textMedium
        }
    }
}

extension View {
    /// Текст по UI kit — «Text M・15 / Medium» пишется `.plusText(.textM, .medium)`.
    func plusText(_ size: PlusTextSize, _ weight: PlusTextWeight) -> some View {
        modifier(FigmaTextStyle(
            family: weight.family,
            size: size.size,
            lineHeight: size.lineHeight,
            tracking: 0
        ))
    }
}

// MARK: - UI kit: заголовки YS Display

/// Шкала акцидентных заголовков и текстов YS Display — UI kit проекта (решение
/// пользователя 2026-10-03): всё, что набрано YS Display, берёт кегль только отсюда.
/// Начертание одно — Bold (Semibold Фигмы), интерлиньяж 100 % на любом кегле, трекинг 0.
///
/// Исключение одно — заголовок витрины (`ShowcaseHeader`): макетные 32/36, под них
/// вручную расставлены врезки между словами, а 32 в шкале нет. Ждёт решения, на какую
/// ступень его перевести, — вместе с перерасчётом позиций врезок.
enum PlusHeadline: CaseIterable {
    case xxxl, xxl, xl, l, m, s

    var size: CGFloat {
        switch self {
        case .xxxl: 52
        case .xxl: 44
        case .xl: 36
        case .l: 28
        case .m: 24
        case .s: 20
        }
    }

    /// Интерлиньяж 100 %: высота строки равна кеглю.
    var lineHeight: CGFloat { size }
}

extension View {
    /// Заголовок по шкале UI kit — Headline XXXL…S.
    ///
    /// Высота строки точная (`lineHeight(.exact)`, iOS 26): 100 % меньше натурального
    /// интерлиньяжа YS (1.172 кегля), а `lineSpacing` умеет только прибавлять —
    /// многострочный заголовок шёл бы рыхло.
    func plusHeadline(_ style: PlusHeadline) -> some View {
        font(.custom(PlusFont.displaySemibold, size: style.size))
            .lineHeight(.exact(points: style.lineHeight))
    }
}

// MARK: - Название сущности

/// Ступень шкалы для названия на экранах книги и альбома — от длины названия, одной
/// лестницей на оба экрана (задача пользователя 2026-10-03): короткое набирается
/// крупно, длинное становится меньше, чтобы шапка не разрасталась на пол-экрана.
///
/// Концы лестницы — макеты: «Snow Day» (8 знаков) на альбоме `2079:11226` — XXL
/// (в макете было 40, в шкале ближайшая крупная ступень 44), «Atomic Heart. Предыстория
/// «Предприятия 3826»» (44 знака) на книге `2427:26464` — M, ровно как в макете.
/// Границы — по замеру строк YS Display Bold в колонке 370pt: на XXL до 14 знаков
/// встают в строку («Технофеодализм» — 358pt), на XL до 24 и на L до 40 — в две,
/// длиннее на M — в две-три. Тот же приём, что у текстового логотипа тайтла
/// (`MovieHeaderLayout.titleSteps`), только колонка там уже.
enum EntityTitleType {
    static let steps: [(maxLength: Int, style: PlusHeadline)] = [
        (14, .xxl),
        (24, .xl),
        (40, .l),
        (Int.max, .m),
    ]

    /// Последняя ступень ловит всё (`Int.max`) — `!` безопасен.
    static func style(for title: String) -> PlusHeadline {
        steps.first { title.count <= $0.maxLength }!.style
    }
}
