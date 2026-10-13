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
    /// По умолчанию — единая лента (правка пользователя 2026-10-12); выбор в дебаг-меню
    /// сохраняется и перекрывает умолчание.
    static let defaultStyle: SearchResultsStyle = .masonry

    var id: Self { self }

    var title: String {
        switch self {
        case .carousels: "Карусели по разделам"
        case .masonry: "Единая лента выдачи"
        }
    }
}

/// Дебаг-меню — переключатели прототипа. Вход — ячейка профиля над «Настройками».
/// Своего макета нет: собрано из островков профиля и навбара внутренних экранов.
struct DebugMenuScreen: View {
    @AppStorage(SearchResultsStyle.storageKey) private var searchStyle: SearchResultsStyle = SearchResultsStyle.defaultStyle
    /// Громкость звука музыки — превью Deezer (`MusicAudio`), по умолчанию 50 %.
    @AppStorage(MusicAudio.volumeKey) private var musicVolume = MusicAudio.defaultVolume
    /// Затемнение фона под стеклом хрома (`ChromeGlass`), по умолчанию 40 %.
    @AppStorage(ChromeGlass.dimKey) private var glassDim = ChromeGlass.defaultDim
    /// Белая иконка активного таба без свечения — ключ `tabActiveWhite` (`TabStyleDebug`).
    @AppStorage(TabStyleDebug.whiteActiveKey) private var whiteActiveTab = false
    /// Сколько пунктов ленты ушло вверх — для подложки навбара
    @State private var scrollOffset: CGFloat = 0

    private enum Layout {
        /// Подпись под островком — поля как у ячеек, сверху 8
        static let noteTop: CGFloat = 8
        /// Верхний отступ заголовков секций 2–4: общие 16 (`ProfileLayout.titleTop`) + 8,
        /// секции разнесены дальше, чем в профиле (правка пользователя 2026-10-12)
        static let sectionGap: CGFloat = ProfileLayout.titleTop + 8
        static let checkIcon: CGFloat = 24
        /// Подпись громкости над слайдером
        static let sliderGap: CGFloat = 8
        /// Шаг слайдеров — 5 %
        static let sliderStep: Double = 0.05
        /// Предел затемнения стекла: дальше пилюли на любом фоне — чёрные
        static let glassDimRange: ClosedRange<Double> = 0...0.8
    }

    /// Название раздела видно всегда, подложка (блюр с затемнением) проявляется
    /// с первых пунктов скролла — как у профиля и списков.
    private static let navThresholds = EntityNavBarThresholds(
        backgroundStart: 0,
        backgroundRamp: ServiceTopNavMotion.backdropRamp,
        titleStart: -.greatestFiniteMagnitude,
        titleRamp: 0
    )

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    title("Вид поисковой выдачи")

                    optionsIsland
                        .padding(.horizontal, ProfileLayout.side)

                    title("Громкость музыки", top: Layout.sectionGap)
                    volumeIsland
                        .padding(.horizontal, ProfileLayout.side)

                    title("Прозрачность навигации", top: Layout.sectionGap)
                    sliderIsland(
                        "Затемнение фона",
                        value: $glassDim,
                        in: Layout.glassDimRange,
                        accessibility: "Затемнение фона под стеклом хрома"
                    )
                    .padding(.horizontal, ProfileLayout.side)
                    note("Затемнение под стеклом таббара, action bar, тостов и кнопок навбаров")

                    title("Таббар", top: Layout.sectionGap)
                    toggleIsland(
                        "Активный таб без свечения",
                        isOn: $whiteActiveTab,
                        accessibility: "Активный таб: белая иконка без свечения"
                    )
                    .padding(.horizontal, ProfileLayout.side)
                    note("Белая иконка активного таба вместо фиолетового свечения")
                }
                .padding(.top, EntityNavBarGeometry.barHeight)
                .padding(.bottom, ProfileLayout.bottomPadding)
            }
            .scrollIndicators(.hidden)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) {
            EntityNavBar(title: "Дебаг меню", scrollOffset: scrollOffset, thresholds: Self.navThresholds)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func title(_ text: String, top: CGFloat = ProfileLayout.titleTop) -> some View {
        Text(text)
            .plusHeadline(.s)
            .foregroundStyle(Color.fillOne)
            .padding(.top, top)
            .padding(.bottom, ProfileLayout.titleBottom)
            .padding(.horizontal, ProfileLayout.side)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .plusText(.textS, .medium)
            .foregroundStyle(Color.fillSubtitle)
            .padding(.top, Layout.noteTop)
            .padding(.horizontal, ProfileLayout.side + ProfileLayout.cellHorizontal)
    }

    /// Громкость — меняется на лету, играет музыка или нет.
    private var volumeIsland: some View {
        sliderIsland("Громкость", value: $musicVolume, in: 0...1, accessibility: "Громкость музыки")
            .onChange(of: musicVolume) { _, volume in
                MusicAudio.shared.setVolume(volume)
            }
    }

    /// Островок-слайдер той же формы, что выбор выдачи: подпись с процентами
    /// и слайдер акцентного цвета, шаг 5 %.
    private func sliderIsland(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        accessibility: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.sliderGap) {
            HStack(spacing: ProfileLayout.cellGap) {
                Text(label)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(Int((value.wrappedValue * 100).rounded()))\u{00A0}%")
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            Slider(value: value, in: range, step: Layout.sliderStep)
                .tint(Color.moviesAccent)
                .accessibilityLabel(accessibility)
        }
        .padding(.horizontal, ProfileLayout.cellHorizontal)
        .padding(.vertical, ProfileLayout.cellVertical)
        .padding(.vertical, ProfileLayout.islandPadding)
        .background(
            RoundedRectangle(cornerRadius: ProfileLayout.islandRadius, style: .continuous)
                .fill(Color.fillNine)
        )
    }

    /// Островок-переключатель той же формы, что остальные: подпись `textM` и `Toggle`
    /// акцентного цвета, поля — как у ячеек профиля.
    private func toggleIsland(_ label: String, isOn: Binding<Bool>, accessibility: String) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .plusText(.textM, .medium)
                .foregroundStyle(Color.fillOne)
        }
        .tint(Color.moviesAccent)
        .accessibilityLabel(accessibility)
        .padding(.horizontal, ProfileLayout.cellHorizontal)
        .padding(.vertical, ProfileLayout.cellVertical)
        .padding(.vertical, ProfileLayout.islandPadding)
        .background(
            RoundedRectangle(cornerRadius: ProfileLayout.islandRadius, style: .continuous)
                .fill(Color.fillNine)
        )
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
        .buttonStyle(CellHighlightButtonStyle())
        .accessibilityAddTraits(style == searchStyle ? .isSelected : [])
    }
}
