import SwiftUI

/// Общие настройки из upstream: один набор bindings для модального девменю.
/// Контейнер задаёт скролл и внешние поля; здесь только содержимое вкладки.
struct DebugGeneralControls: View {
    @AppStorage(SearchResultsStyle.storageKey) private var searchStyle: SearchResultsStyle = SearchResultsStyle
        .defaultStyle
    /// Громкость звука музыки — превью Deezer (`MusicAudio`), по умолчанию 50 %.
    @AppStorage(MusicAudio.volumeKey) private var musicVolume = MusicAudio.defaultVolume
    /// Затемнение фона под стеклом хрома (`ChromeGlass`), по умолчанию 40 %.
    @AppStorage(ChromeGlass.dimKey) private var glassDim = ChromeGlass.defaultDim
    /// Белая иконка активного таба без свечения — ключ `tabActiveWhite` (`TabStyleDebug`).
    @AppStorage(TabStyleDebug.whiteActiveKey) private var whiteActiveTab = false
    /// Голова Люмена в поле поиска вместо навигации «Главной» — ключ `lumenInSearch` (`LumenDebug`).
    @AppStorage(LumenDebug.inSearchKey) private var lumenInSearch = false

    private enum Layout {
        /// Подпись под островком — поля как у ячеек, сверху 8
        static let noteTop: CGFloat = 8
        /// Верхний отступ заголовков секций со второй: общие 16 (`ProfileLayout.titleTop`) + 8 + 16,
        /// секции разнесены дальше, чем в профиле (правки пользователя 2026-10-12 и 2026-10-16)
        static let sectionGap: CGFloat = ProfileLayout.titleTop + 8 + 16
        static let checkIcon: CGFloat = 24
        /// Подпись громкости над слайдером
        static let sliderGap: CGFloat = 8
        /// Шаг слайдеров — 5 %
        static let sliderStep: Double = 0.05
        /// Предел затемнения стекла: дальше пилюли на любом фоне — чёрные
        static let glassDimRange: ClosedRange<Double> = 0...0.8
        /// Колонка кегля между «−» и «+» — под три цифры, кнопки не ездят
        static let headlineValueWidth: CGFloat = 36
        static let headlineButtonGap: CGFloat = 4
        /// Сброс кеглей — под островком, на 12 ниже
        static let resetTop: CGFloat = 12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title("Настройка заголовков", top: 0)
            headlineIsland
            headlineReset
                .padding(.top, Layout.resetTop)

            title("Вид поисковой выдачи", top: Layout.sectionGap)

            optionsIsland

            title("Громкость музыки", top: Layout.sectionGap)
            volumeIsland

            title("Прозрачность навигации", top: Layout.sectionGap)
            sliderIsland(
                "Затемнение фона",
                value: $glassDim,
                in: Layout.glassDimRange,
                accessibility: "Затемнение фона под стеклом хрома"
            )
            note("Затемнение под стеклом таббара, action bar, тостов и кнопок навбаров")

            title("Таббар", top: Layout.sectionGap)
            toggleIsland(
                "Активный таб без свечения",
                isOn: $whiteActiveTab,
                accessibility: "Активный таб: белая иконка без свечения"
            )
            note("Белая иконка активного таба вместо фиолетового свечения")

            title("Люмен", top: Layout.sectionGap)
            toggleIsland(
                "Люмен в поиске",
                isOn: $lumenInSearch,
                accessibility: "Люмен в поле поиска"
            )
        }
    }

    private func title(_ text: String, top: CGFloat = ProfileLayout.titleTop) -> some View {
        Text(text)
            .plusHeadline(.s)
            .foregroundStyle(Color.fillOne)
            .padding(.top, top)
            .padding(.bottom, ProfileLayout.titleBottom)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .plusText(.textS, .medium)
            .foregroundStyle(Color.fillSubtitle)
            .padding(.top, Layout.noteTop)
            .padding(.horizontal, ProfileLayout.cellHorizontal)
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
                .tint(Color.accentPrimary)
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
        .tint(Color.accentPrimary)
        .accessibilityLabel(accessibility)
        .padding(.horizontal, ProfileLayout.cellHorizontal)
        .padding(.vertical, ProfileLayout.cellVertical)
        .padding(.vertical, ProfileLayout.islandPadding)
        .background(
            RoundedRectangle(cornerRadius: ProfileLayout.islandRadius, style: .continuous)
                .fill(Color.fillNine)
        )
    }

    /// Кегли переменных YS Display (`HeadlineSizes`) — строка на переменную, «−»/«+» по 1 pt.
    /// Меняются сразу во всём приложении: заголовки читают кегль в своём `body`
    /// (задача пользователя 2026-10-17).
    private var headlineIsland: some View {
        VStack(spacing: 0) {
            ForEach(PlusHeadline.allCases, id: \.self) { style in
                headlineRow(style)
                    .overlay(alignment: .top) {
                        if style != PlusHeadline.allCases.first {
                            Rectangle()
                                .fill(ProfileLayout.divider)
                                .frame(height: 0.5)
                                .padding(.leading, ProfileLayout.cellHorizontal)
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

    private func headlineRow(_ style: PlusHeadline) -> some View {
        let sizes = HeadlineSizes.shared
        let size = sizes.size(of: style)
        return HStack(spacing: ProfileLayout.cellGap) {
            VStack(alignment: .leading, spacing: 0) {
                Text(style.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                Text("по умолчанию \(Int(style.defaultSize))")
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillSubtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Layout.headlineButtonGap) {
                PlusButton(
                    type: .secondary,
                    size: .s,
                    state: size <= HeadlineSizes.range.lowerBound ? .disabled : .normal,
                    accessibilityTitle: "Уменьшить \(style.title)"
                ) {
                    sizes.adjust(style, by: -HeadlineSizes.step)
                } icon: {
                    MinusGlyph()
                }
                Text("\(Int(size))")
                    .plusText(.textM, .semibold)
                    .foregroundStyle(Color.fillOne)
                    .frame(width: Layout.headlineValueWidth)
                PlusButton(
                    icon: "iconAdd",
                    type: .secondary,
                    size: .s,
                    state: size >= HeadlineSizes.range.upperBound ? .disabled : .normal,
                    accessibilityTitle: "Увеличить \(style.title)"
                ) {
                    sizes.adjust(style, by: HeadlineSizes.step)
                }
            }
        }
        .padding(.horizontal, ProfileLayout.cellHorizontal)
        .padding(.vertical, ProfileLayout.cellVertical)
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(Int(size))")
    }

    /// Все кегли — обратно к переменным ДС; уже на них — кнопка выключена.
    private var headlineReset: some View {
        PlusButton(
            "Сбросить",
            type: .secondary,
            size: .s,
            state: HeadlineSizes.shared.isDefault ? .disabled : .normal
        ) {
            HeadlineSizes.shared.reset()
        }
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

/// «−» кнопок кегля: в ДС «🦄 Графика» минуса нет — это горизонтальная черта `iconAdd`
/// (на холсте 24 — 18.4 × 2.4 по центру), растянутая на бокс иконки кнопки.
private struct MinusGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            Rectangle()
                .frame(width: side * 18.4 / 24, height: side * 2.4 / 24)
                .frame(width: side, height: side)
        }
    }
}
