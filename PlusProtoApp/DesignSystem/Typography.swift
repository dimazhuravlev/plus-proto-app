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

    /// Насколько глифы выходят за рамку строк по вертикали — запас области отрисовки
    /// (`HeadlineInkRenderer`). Нужен и тем, кто сам маскирует или клипует заголовок:
    /// маска по рамке срежет хвосты так же, как срезал их рендер iOS.
    var inkOutset: CGFloat { size * HeadlineInk.vertical }

    /// Где базовая линия от верха строки — как в Фигме.
    ///
    /// Строка 100 % ниже натуральной (у YS — 1.172 кегля). Фигма делит нехватку поровну
    /// между верхом и низом строки: базовая линия в 0.842 кегля от верха. iOS при точной
    /// высоте строки ставит её на самый низ строки — прописные сидели на 0.158 кегля ниже
    /// макета, хвосты целиком уходили под рамку. Отсюда шеврон выше центра заголовка рядом
    /// с ним, тесный зазор под заголовком и срезанные хвосты (жалобы пользователя 2026-10-03).
    var figmaBaseline: CGFloat {
        let font = UIFont(name: PlusFont.displaySemibold, size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
        return (lineHeight - font.lineHeight) / 2 + font.ascender
    }
}

/// Запас под «чернила» YS Display Bold за рамкой строк, в долях кегля. Замер по
/// метрикам шрифта при глифах на месте Фигмы (`figmaBaseline`): хвосты «р», «у», «Д»
/// уходят на 0.202 под базовую линию — у последней строки это 0.044 кегля за нижней
/// кромкой; диакритика «Й», «Ё», «Ö» — до 0.935 над ней, у первой строки это 0.093
/// кегля над верхней. По горизонтали дальше всех вылезает «j» — 0.08. Запас с избытком.
private enum HeadlineInk {
    static let vertical: CGFloat = 0.25
    static let horizontal: CGFloat = 0.1
}

/// Рендер заголовков: ставит каждую строку на базовую линию Фигмы и разрешает глифам
/// выходить за рамку.
///
/// iOS режет отрисовку `Text` по его рамке, а при интерлиньяже 100 % глифы выше строки:
/// хвосты последней строки срезались нижней кромкой контейнера (жалоба пользователя
/// 2026-10-03). `displayPadding` расширяет только область отрисовки, сдвиг строки —
/// только рисунок: раскладка прежняя, блок по-прежнему высотой ровно в N кеглей.
private struct HeadlineInkRenderer: TextRenderer {
    let style: PlusHeadline

    var displayPadding: EdgeInsets {
        let vertical = style.inkOutset
        let horizontal = style.size * HeadlineInk.horizontal
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let target = style.figmaBaseline
        for line in layout {
            // Строка точной высоты отдаёт подъём, равный высоте строки: её базовая линия
            // лежит на низу строки. Сдвигаем на место Фигмы от верха этой же строки.
            let bounds = line.typographicBounds
            let baseline = bounds.origin.y - bounds.rect.minY
            var lineContext = context
            lineContext.translateBy(x: 0, y: target - baseline)
            lineContext.draw(line)
        }
    }
}

/// Волна появления строки: глиф за глифом, каждый — из прозрачности и чуть снизу.
/// Числа — у вызывающего (своей анимации у типографики нет).
///
/// Блюра нет намеренно: фильтр на каждый глиф на старте волны подвешивал главный
/// поток на ~280 мс — первые глифы проявлялись, а строка вставала целиком рывком
/// (лог отрисовки 2026-10-03; без блюра — ровные 60 кадров).
struct HeadlineWave: Equatable {
    /// Между стартами соседних глифов, секунды.
    var stagger: Double
    /// Проявление одного глифа, секунды.
    var glyph: Double
    /// Подъём глифа на место снизу, pt.
    var rise: CGFloat

    /// Вся волна для строки из `glyphs` знаков.
    func total(glyphs: Int) -> Double {
        stagger * Double(max(glyphs - 1, 0)) + glyph
    }
}

/// Заголовок с волной появления: то же размещение строк, что у `HeadlineInkRenderer`,
/// плюс у каждого глифа свой отрезок общей шкалы `progress`.
///
/// Волна — внутри одного `Text`, а не стопкой `Text` по букве: так целы кернинг,
/// перенос и базовая линия макета. `progress` идёт линейно (его анимирует вызывающий),
/// кривую каждого глифа считает рендерер — сильный ease-out (квартика ≈
/// cubic-bezier(0.25, 1, 0.5, 1)).
private struct HeadlineWaveRenderer: TextRenderer, Animatable {
    let style: PlusHeadline
    let wave: HeadlineWave
    /// 0 — строки не видно, 1 — вся на месте.
    var progress: Double
    /// «Уменьшение движения»: без подъёма, строка проявляется целиком.
    let reduceMotion: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var displayPadding: EdgeInsets {
        // Запас — и на подъём глифа снизу.
        let vertical = style.inkOutset + wave.rise
        let horizontal = style.size * HeadlineInk.horizontal
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let count = layout.reduce(0) { lines, line in
            lines + line.reduce(0) { runs, run in runs + run.count }
        }
        let time = progress * wave.total(glyphs: count)
        let target = style.figmaBaseline
        var index = 0
        for line in layout {
            let bounds = line.typographicBounds
            let baseline = bounds.origin.y - bounds.rect.minY
            var lineContext = context
            lineContext.translateBy(x: 0, y: target - baseline)
            for run in line {
                for slice in run {
                    let raw = reduceMotion
                        ? progress
                        : min(max((time - wave.stagger * Double(index)) / wave.glyph, 0), 1)
                    index += 1
                    guard raw > 0 else { continue }
                    let eased = 1 - pow(1 - raw, 4)
                    var glyph = lineContext
                    glyph.opacity = eased
                    if !reduceMotion, eased < 1 {
                        glyph.translateBy(x: 0, y: (1 - eased) * wave.rise)
                    }
                    glyph.draw(slice)
                }
            }
        }
    }
}

extension View {
    /// Заголовок по шкале UI kit с волной появления (`HeadlineWave`): `progress`
    /// анимирует вызывающий — линейно, за `wave.total(glyphs:)`.
    func plusHeadline(
        _ style: PlusHeadline,
        wave: HeadlineWave,
        progress: Double,
        reduceMotion: Bool
    ) -> some View {
        font(.custom(PlusFont.displaySemibold, size: style.size))
            .lineHeight(.exact(points: style.lineHeight))
            .textRenderer(HeadlineWaveRenderer(
                style: style,
                wave: wave,
                progress: progress,
                reduceMotion: reduceMotion
            ))
    }

    /// Заголовок по шкале UI kit — Headline XXXL…S.
    ///
    /// Высота строки точная (`lineHeight(.exact)`, iOS 26): 100 % меньше натурального
    /// интерлиньяжа YS (1.172 кегля), а `lineSpacing` умеет только прибавлять —
    /// многострочный заголовок шёл бы рыхло. Глифы при этом выше строки, и рисует их
    /// `HeadlineInkRenderer` — на месте Фигмы и с запасом за рамкой, иначе хвосты
    /// последней строки срезаны.
    func plusHeadline(_ style: PlusHeadline) -> some View {
        font(.custom(PlusFont.displaySemibold, size: style.size))
            .lineHeight(.exact(points: style.lineHeight))
            .textRenderer(HeadlineInkRenderer(style: style))
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
