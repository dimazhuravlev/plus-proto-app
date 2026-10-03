import SwiftUI

// MARK: - Шапка секции

/// `header / static` 393×52: padding 16/16/12/16, заголовок Group Headline ExtraBold 24.
/// Шеврон-`action` из макета не переносим — переходить некуда.
struct MovieSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .plusHeadline(.m)
            .foregroundStyle(Color.fillOne)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, MovieLayout.sectionHeaderTop)
            .padding(.bottom, MovieLayout.sectionHeaderBottom)
            .padding(.horizontal, MovieLayout.sectionSide)
    }
}

// MARK: - Описание

/// Абзацы описания в шахматном порядке: первый прижат влево и не доходит до правого
/// края, второй наоборот.
///
/// Живёт **внутри** секции видеокарточек (`MovieVideoSection`), между второй и третьей,
/// — там его место по макету `2052:10645`. Отдельной секцией экрана он был, только пока
/// карточек не существовало.
struct MovieSynopsisSection: View {
    let paragraphs: [String]

    /// Описание раскрыто целиком. Свёрнутое состояние — по умолчанию.
    @State private var isExpanded = false

    private enum Layout {
        /// Слева шахматно из макета: `pl 24` у первого абзаца, 48 у сдвинутого.
        /// Справа макет зеркалил (48/16), но у нас правое поле у всех — общее поле
        /// экрана 16 (правка пользователя 2026-08-25); шахматность осталась слева.
        static let top: CGFloat = 16
        static let bottom: CGFloat = 8
        static let near: CGFloat = 24
        static let far: CGFloat = 48
        /// Правое поле всех абзацев — общее поле секции
        static let edge: CGFloat = 16
        /// Сколько описания показываем свёрнутым. Считается по всей длине, а не
        /// по числу абзацев: важно, сколько текста на экране, а не на сколько кусков
        /// его разбило нарезание по предложениям.
        static let collapsedLimit = 500
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, text in
                let shifted = index.isMultiple(of: 2) == false

                Text(text)
                    .plusHeadline(.m)
                    .foregroundStyle(Color.fillOne)
                    // Абзац обязан занять свою полную высоту. Без этого он ужимается
                    // под высоту, предложенную снаружи, и SwiftUI режет его многоточием
                    // по месту — так описание обрывалось на полуслове в каждом абзаце,
                    // хотя в исходнике оно целое (замер по ответу API: 414 символов,
                    // одно многоточие, и то авторское, в самом конце).
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, shifted ? Layout.far : Layout.near)
                    .padding(.trailing, Layout.edge)
                    .padding(.top, Layout.top)
                    .padding(.bottom, Layout.bottom)
            }
        }
        // Нажатие по всему блоку, а не по кнопке «Ещё»: в макете такой кнопки нет,
        // а текст — единственное, что здесь есть.
        .contentShape(.rect)
        .onTapGesture {
            guard isTruncated || isExpanded else { return }
            withAnimation(.snappy(duration: 0.28)) { isExpanded.toggle() }
        }
        .accessibilityAddTraits(isTruncated || isExpanded ? .isButton : [])
        .accessibilityHint(isExpanded ? "Свернуть описание" : "Показать описание целиком")
    }

    /// Что показываем сейчас. Свёрнутым — абзацы, пока их суммарная длина не перевалит
    /// за предел; последний влезший обрывается многоточием, остальные не показываются
    /// вовсе. Обрывается **только последний**: раньше многоточие получал каждый абзац,
    /// и текст читался как набор обрубков.
    private var shown: [String] {
        guard !isExpanded, isTruncated else { return paragraphs }

        var result: [String] = []
        var used = 0
        for paragraph in paragraphs {
            let room = Layout.collapsedLimit - used
            if paragraph.count <= room {
                result.append(paragraph)
                used += paragraph.count
            } else {
                result.append(paragraph.clipped(to: room))
                break
            }
        }
        return result
    }

    /// Есть ли что раскрывать.
    private var isTruncated: Bool {
        paragraphs.reduce(0) { $0 + $1.count } > Layout.collapsedLimit
    }
}

private extension String {
    /// Обрезает по границе слова и ставит многоточие. Точка перед ним не нужна:
    /// её и так нет в конце абзацев.
    func clipped(to limit: Int) -> String {
        guard limit > 0, count > limit else { return self }
        let head = prefix(limit)
        guard let space = head.lastIndex(of: " ") else { return String(head) + "…" }
        return String(head[..<space]) + "…"
    }
}


// MARK: - Детали

/// Строка блока «Details»: лейбл, значение и приглушённое уточнение
/// (в макете — «Arabic *Stereo*», «Arabic *Closed captions*»).
struct MovieDetailRow: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let note: String?
}

/// `3806:11193` — 393×280: padding-y 16, шапка + список с разделителями.
struct MovieDetailsSection: View {
    let rows: [MovieDetailRow]

    private enum Layout {
        static let outer: CGFloat = 16
        /// Зазор шапка ↔ список
        static let headerGap: CGFloat = 8
        /// Зазор между строками и разделителями
        static let rowGap: CGFloat = 14
        /// Колонка лейбла: 128 с внутренним отступом 24 справа
        static let labelWidth: CGFloat = 128
        static let labelInset: CGFloat = 24
        static let separator: CGFloat = 1
        /// Пробел между значением и уточнением («Русский стерео»)
        static let noteGap: CGFloat = 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.headerGap) {
            MovieSectionHeader(title: "Детали")

            VStack(alignment: .leading, spacing: Layout.rowGap) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.fillNine)
                            .frame(height: Layout.separator)
                    }
                    line(row)
                }
            }
            .padding(.horizontal, MovieLayout.sectionSide)
        }
        .padding(.vertical, Layout.outer)
    }

    private func line(_ row: MovieDetailRow) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(row.label)
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillOne)
                .padding(.trailing, Layout.labelInset)
                .frame(width: Layout.labelWidth, alignment: .leading)

            HStack(spacing: Layout.noteGap) {
                Text(row.value)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)

                if let note = row.note {
                    Text(note)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Оценка

/// `3807:12644` — 393×160: четыре равные колонки, круг 52 на белом 8 %.
/// Геометрия совпадает с блоком оценки витрины (figma-screen1 §3.7).
struct MovieRateSection: View {
    private enum Layout {
        /// Поле блока сверху и снизу. Макетные 8 + 16 (правка пользователя
        /// 2026-08-25): блоку оценки нужен воздух от соседних секций.
        static let outer: CGFloat = 24
        /// Ряд кнопок 393×92
        static let rowHeight: CGFloat = 92
        static let circle: CGFloat = 52
        static let labelGap: CGFloat = 8
    }

    private struct Option: Identifiable {
        var id: String { title }
        let emoji: String
        let title: String
    }

    private static let options = [
        Option(emoji: "👎", title: "Не зашло"),
        Option(emoji: "😐", title: "Так себе"),
        Option(emoji: "👍", title: "Хорошо"),
        Option(emoji: "😍", title: "Обожаю"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MovieSectionHeader(title: "Уже смотрели? Как вам?")

            HStack(spacing: 0) {
                ForEach(MovieRateSection.options) { option in
                    VStack(spacing: Layout.labelGap) {
                        Text(option.emoji)
                            .plusHeadline(.m)
                            .frame(width: Layout.circle, height: Layout.circle)
                            .background(Circle().fill(Color.buttonsSecondary))

                        Text(option.title)
                            .plusText(.textS, .semibold)
                            .foregroundStyle(Color.fillOne)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: Layout.rowHeight, alignment: .top)
            .padding(.horizontal, MovieLayout.sectionSide)
        }
        .padding(.vertical, Layout.outer)
    }
}
