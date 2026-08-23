import SwiftUI

/// Семейства шрифтов. В проекте ровно два: YS Display (заголовки) и YS Text (тексты),
/// каждое в двух начертаниях. Отдельного файла Semibold в семействе не существует —
/// в Figma переменная `Font Weight/Semibold` резолвится в Bold(700), поэтому Semibold ≡ Bold.
enum PlusFont {
    static let displayMedium = "YSDisplay-Medium"
    static let displaySemibold = "YSDisplay-Bold"
    static let textMedium = "YSText-Medium"
    static let textSemibold = "YSText-Bold"
}

/// Точная типографика из Figma: кегль + межстрочное + трекинг.
/// SwiftUI берёт натуральный lineHeight шрифта, а в макете он задан явно —
/// разницу компенсируем через lineSpacing и симметричный вертикальный отступ.
private struct FigmaTextStyle: ViewModifier {
    let family: String
    let size: CGFloat
    let lineHeight: CGFloat
    let tracking: CGFloat

    func body(content: Content) -> some View {
        let natural = (UIFont(name: family, size: size) ?? .systemFont(ofSize: size)).lineHeight
        // Дельта бывает отрицательной: у YS натуральный интервал 1.172em, то есть на 32pt
        // это 37.5 против макетных 36. Обрезать её нулём нельзя — на трёх строках заголовка
        // набегает 4.5pt, и весь блок уезжает вниз относительно макета.
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
/// и на трёх строках заголовка набегает 4.5pt. Ни один штатный способ этого не лечит:
/// `lineSpacing` умеет только прибавлять, а `paragraphStyle` в `AttributedString`
/// SwiftUI игнорирует (замер дал шаг 37.6 вместо 36).
///
/// Поэтому строки набираются отдельными `Text` в стеке с точным — при необходимости
/// отрицательным — зазором. Переносы задаёт сам текст через `\n`: в макете они
/// расставлены под врезки между словами, автоперенос их бы не повторил.
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

extension View {
    /// Заголовок экрана-витрины — YS Display Semibold 32 / lh 36 / tracking −0.2
    func plusHeadline() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.displaySemibold, size: 32, lineHeight: 36, tracking: -0.2))
    }

    /// Плейсхолдер поиска и заголовок блока оценки — YS Display Semibold 20 / lh 26
    func plusTitleL() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.displaySemibold, size: 20, lineHeight: 26, tracking: 0))
    }

    /// Эмодзи в чипах оценки — YS Display Semibold 24 / lh 28
    func plusTitleM() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.displaySemibold, size: 24, lineHeight: 28, tracking: 0))
    }

    /// Выдержка из книги в карточке «продолжить чтение» — YS Text Medium 18 / lh 20 / tracking −0.2
    func plusReaderText() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textMedium, size: 18, lineHeight: 20, tracking: -0.2))
    }

    /// Подписи карточек — YS Text Medium 15 / lh 18 / tracking −0.2
    func plusTextM() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textMedium, size: 15, lineHeight: 18, tracking: -0.2))
    }

    /// Мини-плеер, подписи прогресса — YS Text Medium 13 / lh 16 / tracking 0.
    /// Трекинг был −0.2 «по аналогии» с соседними стилями; замер ноды мини-плеера
    /// показал в макете ровно 0, и подписи из-за минуса шли на 6pt уже эталона
    /// («Cocteau Twins» 82.67 против 89). Решение пользователя 2026-08-23.
    func plusTextS() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textMedium, size: 13, lineHeight: 16, tracking: 0))
    }

    /// Лейблы табов — YS Text Medium 11 / lh 14
    func plusTabLabel() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textMedium, size: 11, lineHeight: 14, tracking: 0))
    }
}

// MARK: - Карточка тайтла

/// Экран фильма нарисован в другом файле Figma («🎬 Mobile Title Card») и на другом
/// шрифте — Yango Group Headline / Yango Text. Метрики оттуда с витриной не совпадают:
/// интерлиньяж задан процентами (110 / 120 / 100 %), трекинг всюду нулевой, у текста
/// 15 кегля межстрочное 20, а не 18. Поэтому это отдельная линейка стилей, а не
/// перенастройка существующих: смешивать их — значит незаметно сдвинуть витрину.
/// Семейства — ближайшие бандленные: YS Display вместо Group Headline, YS Text вместо Yango Text.
extension View {
    /// Лид карточки — Group Headline Bold, lh 110 %. Кегль живёт в `MovieLeadType`,
    /// а не здесь: от него считается высота инфо-блока и, через неё, высота кавера —
    /// две величины обязаны браться из одного места. Почему не макетные 32 — там же.
    func plusMovieLead() -> some View {
        modifier(FigmaTextStyle(
            family: PlusFont.displaySemibold,
            size: MovieLeadType.size,
            lineHeight: MovieLeadType.lineHeight,
            tracking: 0
        ))
    }

    /// Заголовок секции — Group Headline ExtraBold 24 / lh 100 %
    func plusMovieSection() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.displaySemibold, size: 24, lineHeight: 24, tracking: 0))
    }

    /// Мета, значения в «Деталях» — Yango Text Medium 15 / lh 20
    func plusMovieText() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textMedium, size: 15, lineHeight: 20, tracking: 0))
    }

    /// Лейблы кнопок — Yango Text Semibold(=Bold) 15 / lh 20
    func plusMovieTextBold() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textSemibold, size: 15, lineHeight: 20, tracking: 0))
    }

    /// Название тайтла на месте логотипа — `2063:11230`: YS Display Bold 28 / lh 32.
    func plusMovieHeaderTitle() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.displaySemibold, size: 28, lineHeight: 32, tracking: 0))
    }

    /// Текст секции видеокарточек — YS Display Bold 24 / lh 28.
    ///
    /// Один стиль на всё: заголовок карточки, подпись и абзацы между карточками
    /// в макете `2052:10642` набраны одинаково и различаются только цветом. Прежняя
    /// спека обещала заголовку 32/110 %, но описывала другой файл — здесь у заголовка
    /// и подписи одна высота строки, это видно и по замеру нод (28 и 56 = 2×28).
    func plusMovieCardText() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.displaySemibold, size: 24, lineHeight: 28, tracking: 0))
    }

    /// Подписи оценки и бейджей — Yango Text Bold 13 / lh 18
    func plusMovieCaption() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textSemibold, size: 13, lineHeight: 18, tracking: 0))
    }
}
