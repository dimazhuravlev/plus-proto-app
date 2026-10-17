import SwiftUI

/// Семейства шрифтов. В проекте ровно два: YS Display (акцидентные заголовки) в одном
/// начертании — Bold, и YS Text (наборные тексты) в двух — Medium и Semibold. Отдельного
/// файла Semibold в семействе не существует — в Figma переменная `Font Weight/Semibold`
/// резолвится в Bold (700), поэтому Semibold ≡ Bold.
///
/// Набирать текст напрямую этими именами нельзя — только стилями ДС ниже:
/// `plusText(_:_:)` для YS Text и `plusHeadline(_:)` для YS Display.
enum PlusFont {
    static let display = "YSDisplay-Bold"
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

// MARK: - ДС: наборные стили YS Text

/// Кегль стиля YS Text — переменные ДС «🫟 Mobile · Library» (`7529:1713`): Title S・24,
/// Text L・18, Text M・15, Text S・13, Text ХS・11, каждый в Semibold и Medium; правила
/// работы — там же (`7529:2161`). Других стилей YS Text в проекте нет и быть не может
/// (решения пользователя 2026-10-03 и 2026-10-17: вся типографика — только переменными).
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

extension PlusTextSize {
    /// Файл шрифта переменной. Как в ДС: «Title S・24/Medium» там набран YS Text Bold,
    /// как и Semibold, — переменная повторена ровно.
    func family(_ weight: PlusTextWeight) -> String {
        self == .titleS ? PlusFont.textSemibold : weight.family
    }

    /// Шрифт стиля для замеров текста до раскладки (ширина, число строк) — тот же файл
    /// и кегль, что рисует `plusText`. Интерлиньяж у него натуральный.
    func uiFont(_ weight: PlusTextWeight) -> UIFont {
        UIFont(name: family(weight), size: size) ?? .systemFont(ofSize: size, weight: .medium)
    }
}

extension View {
    /// Текст по ДС — «Text M・15/Medium» пишется `.plusText(.textM, .medium)`.
    func plusText(_ size: PlusTextSize, _ weight: PlusTextWeight) -> some View {
        modifier(FigmaTextStyle(
            family: size.family(weight),
            size: size.size,
            lineHeight: size.lineHeight,
            tracking: 0
        ))
    }
}

// MARK: - ДС: акцидентные стили YS Display

/// Шкала акцидентных заголовков YS Display — переменные ДС «🫟 Mobile · Library»
/// (`7816:504`) ровно: Headline/Headline XXXL 56, XXL 48, XL 40, L 32, M 28, S 24.
/// Всё, что набрано YS Display, берёт стиль только отсюда, и всё, что зависит от его
/// строки (рамки шапок, скелетоны), считается от `size`/`lineHeight`, а не числом.
/// Начертание одно — Bold, интерлиньяж 100 % на любом кегле, трекинг 0, у S — 1.5 %.
///
/// Прежняя шкала проекта (52/44/36/28/24/20) переведена на ДС с сохранением кеглей:
/// 24 → S, 28 → M, 36/44/52 — ступенью ниже (L, XL, XXL), 20 → S (решения пользователя
/// 2026-10-17).
enum PlusHeadline: String, CaseIterable {
    case xxxl, xxl, xl, l, m, s

    /// Кегль переменной ДС.
    var defaultSize: CGFloat {
        switch self {
        case .xxxl: 56
        case .xxl: 48
        case .xl: 40
        case .l: 32
        case .m: 28
        case .s: 24
        }
    }

    /// Кегль в приложении — переменная ДС или примерка из дебаг-меню (`HeadlineSizes`).
    /// Читать в `body` или в вычисляемом свойстве, не в `static let`: тогда смена
    /// кегля перерисовывает заголовок сразу.
    var size: CGFloat { HeadlineSizes.shared.size(of: self) }

    /// Имя переменной в Фигме — «Headline XXXL»…
    var title: String { "Headline \(rawValue.uppercased())" }

    /// Интерлиньяж 100 %: высота строки равна кеглю.
    var lineHeight: CGFloat { size }

    /// Трекинг в пунктах: у S — 1.5 % кегля, у остальных 0.
    var tracking: CGFloat {
        self == .s ? size * 0.015 : 0
    }

    /// Следующая ступень шкалы вниз; у самой мелкой остаётся она же.
    var smaller: PlusHeadline {
        switch self {
        case .xxxl: .xxl
        case .xxl: .xl
        case .xl: .l
        case .l: .m
        case .m: .s
        case .s: .s
        }
    }

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
        let font = uiFont
        return (lineHeight - font.lineHeight) / 2 + font.ascender
    }

    /// Шрифт стиля для замеров текста до раскладки (число строк, ширина): тот же YS Display
    /// Bold и тот же кегль, что рисует `plusHeadline`. Натуральный интерлиньяж у него
    /// 1.172 кегля — строки в замере считать им, а не `lineHeight`.
    var uiFont: UIFont {
        UIFont(name: PlusFont.display, size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
    }

    /// Атрибуты для замера строки стилем — шрифт и трекинг, как их рисует `plusHeadline`.
    var measureAttributes: [NSAttributedString.Key: Any] {
        [.font: uiFont, .kern: tracking]
    }
}

/// Кегли шкалы для примерки (задача пользователя 2026-10-17): по умолчанию — переменные
/// ДС, дебаг-меню меняет каждую кнопками «−»/«+». Наблюдаемые: заголовок читает кегль
/// в своём `body`, и смена сразу видна на всех экранах. Изменённые кегли хранятся
/// в `UserDefaults` и переживают перезапуск, как прочие ручки дебаг-меню.
@Observable
final class HeadlineSizes {
    static let shared = HeadlineSizes()

    static let storageKey = "headlineSizes"
    static let step: CGFloat = 1
    static let range: ClosedRange<CGFloat> = 8...120

    private var values: [PlusHeadline: CGFloat]

    private init() {
        // Числа — и строкой: ключ можно задать из шелла (`defaults write … -dict s 30`).
        let stored = UserDefaults.standard.dictionary(forKey: Self.storageKey) ?? [:]
        values = Dictionary(uniqueKeysWithValues: PlusHeadline.allCases.map { style in
            let value = (stored[style.rawValue] as? NSNumber)?.doubleValue
                ?? (stored[style.rawValue] as? String).flatMap(Double.init)
            return (style, value.map { CGFloat($0) } ?? style.defaultSize)
        })
    }

    func size(of style: PlusHeadline) -> CGFloat {
        values[style] ?? style.defaultSize
    }

    func adjust(_ style: PlusHeadline, by delta: CGFloat) {
        let size = min(max(size(of: style) + delta, Self.range.lowerBound), Self.range.upperBound)
        guard size != values[style] else { return }
        values[style] = size
        let changed = values.reduce(into: [String: Double]()) { stored, entry in
            if entry.value != entry.key.defaultSize { stored[entry.key.rawValue] = Double(entry.value) }
        }
        if changed.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        } else {
            UserDefaults.standard.set(changed, forKey: Self.storageKey)
        }
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

/// Волна появления строки: глиф за глифом, каждый — только из прозрачности, без
/// сдвига (правка пользователя 2026-10-03: «не нужна анимация офсета»).
/// Числа — у вызывающего (своей анимации у типографики нет).
///
/// Блюра нет намеренно: фильтр на каждый глиф на старте волны подвешивал главный
/// поток на ~280 мс — первые глифы проявлялись, а строка вставала целиком рывком
/// (лог отрисовки 2026-10-03; без блюра — ровные 60 кадров).
struct HeadlineWave: Equatable {
    /// Между стартами соседних глифов, секунды.
    var stagger: Double
    /// Проявление одного глифа, секунды. Ноль — глиф встаёт сразу, шагом, без
    /// проявления прозрачностью (печать).
    var glyph: Double
    /// Пауза на границе слов, секунды, — после глифов с номерами из `pauseAfter`
    /// (пробелы). Рукой печатают не ровным шагом: слово набирается подряд, а перед
    /// следующим рука замирает (правка пользователя 2026-10-05).
    var pause: Double = 0
    var pauseAfter: Set<Int> = []

    /// Старт глифа с этим номером.
    func start(_ index: Int) -> Double {
        stagger * Double(index) + pause * Double(pauseAfter.filter { $0 < index }.count)
    }

    /// Вся волна для строки из `glyphs` знаков.
    func total(glyphs: Int) -> Double {
        start(max(glyphs - 1, 0)) + glyph
    }

    /// Печать по словам: глифы встают шагом, перед каждым словом, кроме первого, — пауза.
    static func typing(_ text: String, stagger: Double, pause: Double) -> HeadlineWave {
        let spaces = Set(text.enumerated().filter { $0.element == " " }.map(\.offset))
        return HeadlineWave(stagger: stagger, glyph: 0, pause: pause, pauseAfter: spaces)
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
    /// «Уменьшение движения»: строка проявляется целиком, без волны.
    let reduceMotion: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var displayPadding: EdgeInsets {
        let vertical = style.inkOutset
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
                    let start = wave.start(index)
                    let raw: Double
                    if reduceMotion {
                        raw = progress
                    } else if wave.glyph <= 0 {
                        // Шаг: глиф есть, как только до него дошла волна.
                        raw = progress > 0 && time >= start ? 1 : 0
                    } else {
                        raw = min(max((time - start) / wave.glyph, 0), 1)
                    }
                    index += 1
                    guard raw > 0 else { continue }
                    let eased = 1 - pow(1 - raw, 4)
                    var glyph = lineContext
                    glyph.opacity = eased
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
        font(.custom(PlusFont.display, size: style.size))
            .tracking(style.tracking)
            .lineHeight(.exact(points: style.lineHeight))
            .textRenderer(HeadlineWaveRenderer(
                style: style,
                wave: wave,
                progress: progress,
                reduceMotion: reduceMotion
            ))
    }

    /// Поле ввода по шкале UI kit — тот же кегль и начертание, что у `plusHeadline`,
    /// но с натуральной высотой строки. `TextField` — UIKit-поле: рендерер с запасом
    /// за рамкой (`HeadlineInkRenderer`) до него не доходит, и точная строка 100 %
    /// срезала хвосты букв снизу («у» в «Преступление», жалоба пользователя 2026-10-03).
    /// Базовая линия при этом та же, что у плейсхолдера на `plusHeadline`: обе строки
    /// центрируются в поле, а смещение базовой линии от центра у них совпадает.
    func plusHeadlineField(_ style: PlusHeadline) -> some View {
        font(.custom(PlusFont.display, size: style.size))
            .tracking(style.tracking)
    }

    /// Заголовок по шкале UI kit — Headline XXXL…S.
    ///
    /// Высота строки точная (`lineHeight(.exact)`, iOS 26): 100 % меньше натурального
    /// интерлиньяжа YS (1.172 кегля), а `lineSpacing` умеет только прибавлять —
    /// многострочный заголовок шёл бы рыхло. Глифы при этом выше строки, и рисует их
    /// `HeadlineInkRenderer` — на месте Фигмы и с запасом за рамкой, иначе хвосты
    /// последней строки срезаны.
    func plusHeadline(_ style: PlusHeadline) -> some View {
        font(.custom(PlusFont.display, size: style.size))
            .tracking(style.tracking)
            .lineHeight(.exact(points: style.lineHeight))
            .textRenderer(HeadlineInkRenderer(style: style))
    }
}

// MARK: - Название сущности

/// Ступень шкалы для названия на экранах книги и альбома — от длины названия, одной
/// лестницей на оба экрана (задача пользователя 2026-10-03): короткое набирается
/// крупно, длинное становится меньше, чтобы шапка не разрасталась на пол-экрана.
///
/// Концы лестницы — макеты: «Snow Day» (8 знаков) на альбоме `2079:11226` — XL 40,
/// как в макете, «Atomic Heart. Предыстория «Предприятия 3826»» (44 знака) на книге
/// `2427:26464` — S 24, как в макете. Границы — по замеру строк YS Display Bold в колонке
/// 370pt на прежней шкале 44/36/28/24 (на XL 40 «Технофеодализм» — 325pt, в строку);
/// ступени переведены на ДС с сохранением кеглей (2026-10-17), кегли не выросли, и границы
/// остались в силе. Тот же приём, что у текстового логотипа тайтла
/// (`MovieHeaderLayout.titleSteps`), только колонка там уже.
enum EntityTitleType {
    static let steps: [(maxLength: Int, style: PlusHeadline)] = [
        (14, .xl),
        (24, .l),
        (40, .m),
        (Int.max, .s),
    ]

    /// Последняя ступень ловит всё (`Int.max`) — `!` безопасен.
    static func style(for title: String) -> PlusHeadline {
        steps.first { title.count <= $0.maxLength }!.style
    }
}
