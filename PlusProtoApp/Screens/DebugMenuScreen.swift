import SwiftUI

/// Вид выдачи поиска — переключатель дебаг-меню (задача пользователя 2026-10-05).
/// Хранится в `UserDefaults` и переживает перезапуск; на один запуск его подменяет
/// аргумент `-searchResultsStyle masonry` (docs/DEBUG.md).
enum SearchResultsStyle: String, CaseIterable, Identifiable {
    /// Карусели по разделам — первая версия (макет `2118:17378`)
    case carousels
    /// Сетка вперемешку с фильтрами — вторая версия (макет `2479:24822`)
    case masonry

    static let storageKey = "searchResultsStyle"

    var id: Self { self }

    var title: String {
        switch self {
        case .carousels: "Карусели по разделам"
        case .masonry: "Сетка вперемешку"
        }
    }
}

/// Дебаг-меню — переключатели прототипа. Вход — ячейка профиля над «Настройками».
/// Своего макета нет: собрано из островков профиля и навбара внутренних экранов.
struct DebugMenuScreen: View {
    @AppStorage(SearchResultsStyle.storageKey) private var searchStyle: SearchResultsStyle = .carousels

    private enum Layout {
        /// Подпись под островком — поля как у ячеек, сверху 8
        static let noteTop: CGFloat = 8
        static let checkIcon: CGFloat = 24
    }

    /// Название раздела видно всегда, подложки нет: экран короче её порога.
    private static let navThresholds = EntityNavBarThresholds(
        backgroundStart: .greatestFiniteMagnitude,
        backgroundRamp: 1,
        titleStart: -.greatestFiniteMagnitude,
        titleRamp: 0
    )

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Выдача поиска")
                        .plusHeadline(.m)
                        .foregroundStyle(Color.fillOne)
                        .padding(.top, ProfileLayout.titleTop)
                        .padding(.bottom, ProfileLayout.titleBottom)
                        .padding(.horizontal, ProfileLayout.side)

                    optionsIsland
                        .padding(.horizontal, ProfileLayout.side)

                    Text("Сетка — вторая версия выдачи: все разделы в одной ленте, сверху фильтры. Выбор сохраняется между запусками.")
                        .plusText(.textS, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .padding(.top, Layout.noteTop)
                        .padding(.horizontal, ProfileLayout.side + ProfileLayout.cellHorizontal)
                }
                .padding(.top, EntityNavBarGeometry.barHeight)
                .padding(.bottom, ProfileLayout.bottomPadding)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .top) {
            EntityNavBar(title: "Дебаг меню", thresholds: Self.navThresholds)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Островок выбора — как ячейки профиля (`ProfileLayout`): строки с разделителями,
    /// у выбранной — галочка справа.
    private var optionsIsland: some View {
        VStack(spacing: 0) {
            ForEach(SearchResultsStyle.allCases) { style in
                optionRow(style)
                    .overlay(alignment: .top) {
                        if style != SearchResultsStyle.allCases.first {
                            Rectangle()
                                .fill(ProfileLayout.divider)
                                .frame(height: 0.5)
                                .padding(.leading, ProfileLayout.dividerInset)
                        }
                    }
            }
        }
        .padding(.vertical, ProfileLayout.islandPadding)
        .background(
            RoundedRectangle(cornerRadius: ProfileLayout.islandRadius, style: .continuous)
                .fill(Color.fillNine)
        )
    }

    private func optionRow(_ style: SearchResultsStyle) -> some View {
        Button {
            guard style != searchStyle else { return }
            TabBarMotion.tapHaptic()
            searchStyle = style
        } label: {
            HStack(spacing: ProfileLayout.cellGap) {
                Text(style.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("iconDone")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: Layout.checkIcon, height: Layout.checkIcon)
                    .foregroundStyle(Color.fillOne)
                    .opacity(style == searchStyle ? 1 : 0)
            }
            .padding(.horizontal, ProfileLayout.cellHorizontal)
            .padding(.vertical, ProfileLayout.cellVertical)
            .contentShape(.rect)
        }
        .buttonStyle(DebugRowButtonStyle())
        .accessibilityAddTraits(style == searchStyle ? .isSelected : [])
    }
}

/// Нажатая строка подсвечивается, как ячейка профиля, — без сжатия.
private struct DebugRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.06 : 0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
