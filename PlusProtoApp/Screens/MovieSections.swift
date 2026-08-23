import SwiftUI

// MARK: - Шапка секции

/// `header / static` 393×52: padding 16/16/12/16, заголовок Group Headline ExtraBold 24.
/// Шеврон-`action` из макета не переносим — переходить некуда.
struct MovieSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .plusMovieSection()
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

    private enum Layout {
        /// `pl 24 / pr 48 / pt 16 / pb 8` у первого абзаца, зеркально — у второго.
        /// Прежняя спека (`2101:22593`) давала первому 16 — это другой файл макета.
        static let top: CGFloat = 16
        static let bottom: CGFloat = 8
        static let near: CGFloat = 24
        static let far: CGFloat = 48
        /// Правое поле сдвинутого абзаца — общее поле секции
        static let edge: CGFloat = 16
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, text in
                let shifted = index.isMultiple(of: 2) == false

                Text(text)
                    .plusMovieCardText()
                    .foregroundStyle(Color.fillOne)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, shifted ? Layout.far : Layout.near)
                    .padding(.trailing, shifted ? Layout.edge : Layout.far)
                    .padding(.top, Layout.top)
                    .padding(.bottom, Layout.bottom)
            }
        }
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
                .plusMovieText()
                .foregroundStyle(Color.fillOne)
                .padding(.trailing, Layout.labelInset)
                .frame(width: Layout.labelWidth, alignment: .leading)

            HStack(spacing: Layout.noteGap) {
                Text(row.value)
                    .plusMovieText()
                    .foregroundStyle(Color.fillOne)

                if let note = row.note {
                    Text(note)
                        .plusMovieText()
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
        static let outer: CGFloat = 8
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
                            .plusTitleM()
                            .frame(width: Layout.circle, height: Layout.circle)
                            .background(Circle().fill(Color.buttonsSecondary))

                        Text(option.title)
                            .plusMovieCaption()
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
