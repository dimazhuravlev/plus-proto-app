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

    /// Мини-плеер, подписи прогресса — YS Text Medium 13 / lh 16 / tracking −0.2
    func plusTextS() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textMedium, size: 13, lineHeight: 16, tracking: -0.2))
    }

    /// Лейблы табов — YS Text Medium 11 / lh 14
    func plusTabLabel() -> some View {
        modifier(FigmaTextStyle(family: PlusFont.textMedium, size: 11, lineHeight: 14, tracking: 0))
    }
}
