import SwiftUI
import UIKit

// MARK: - Содержимое

/// Пункт шторки действий — ячейка островка `cell / master`: иконка 24 и название Text M.
struct ActionSheetItem: Identifiable {
    let icon: String
    let title: String
    /// Цвет иконки: у отмеченного «Нравится» — акцент, как залитое сердце в шторках
    /// Музыки (решение пользователя 2026-10-28)
    var iconColor: Color = .fillOne
    /// Нет действия — пункт только откликается (подсветка и хаптика), шторка остаётся:
    /// за ним в прототипе ничего нет.
    var action: (@MainActor () -> Void)? = nil

    var id: String { title }
}

/// Шапка шторки — сущность, о которой пункты (`list-item / music` макета `17213:40283`):
/// обложка 52 r6 (у исполнителя — круг), название и серым подробности через точку.
struct ActionSheetHeader {
    var artwork: ArtworkSource?
    var isCircle = false
    let title: String
    /// Исполнитель, владелец… — серым в строку через точки; пустые не пишутся.
    var details: [String] = []
}

/// «Моя волна по …» — капсула 72 (`my vibe module`): ▶ 36, подпись серым и название
/// крупно, Headline XL.
struct ActionSheetVibe {
    let caption: String
    let title: String
    var action: (@MainActor () -> Void)?
}

/// Что показывает шторка: шапка, пометки, «Моя волна» и островки пунктов — блоки
/// `.modal-content` через 16; любой из первых трёх может отсутствовать.
struct ActionSheetContent {
    var header: ActionSheetHeader? = nil
    /// Пометки под шапкой — Text M белым, построчно («Возрастное ограничение 18+»)
    var notes: [String] = []
    var vibe: ActionSheetVibe? = nil
    /// Островки сверху вниз
    var groups: [[ActionSheetItem]]
}

/// Шторка действий поверх всего — оверфлоу сущностей (`.modal-content` `18482:216310`
/// и шторка трека `17213:40281` файла «ЯПС · Mobile · Current State»). Живёт
/// в `OverlayLayer`, как шеринг: затемнение закрывает и хром. Окружения корня в слое
/// нет — действия приходят готовыми замыканиями от того, кто открыл шторку.
@MainActor
@Observable
final class ActionSheetState {
    static let shared = ActionSheetState()

    /// `nil` — шторки нет.
    private(set) var content: ActionSheetContent?
    /// Меняется на каждый `present`: вью шторки не переиспользует состояние прошлого показа.
    private(set) var presentationID = UUID()

    @ObservationIgnored
    private var pendingRemoval: Task<Void, Never>?

    /// Шторка на экране (и пока уезжает). Им же карточка, открывшая шторку долгим
    /// нажатием, отличает отпускание пальца от тапа.
    var isPresented: Bool { content != nil }

    func present(_ content: ActionSheetContent) {
        pendingRemoval?.cancel()
        presentationID = UUID()
        self.content = content
        OverlayLayerState.shared.isInteractive = true
    }

    /// Снять шторку со слоя, когда она уехала. Шеринг, открытый из шторки, держит слой
    /// интерактивным.
    func remove(after delay: TimeInterval) {
        pendingRemoval?.cancel()
        pendingRemoval = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.pendingRemoval = nil
            self.content = nil
            OverlayLayerState.shared.isInteractive = ShareState.shared.presented != nil
        }
    }
}

// MARK: - Числа

/// `Bottom Sheet` макета (`18482:215976` — книга, `18487:220323` — скачанный фильм,
/// `17213:40283` — трек): шапка 56 с индикатором и ✕, блоки содержимого через 16,
/// островки Fill/Nine r16 по 16 от краёв через 8, ячейки 48, до home indicator — 24.
enum ActionSheetLayout {
    /// Верхние углы шторки
    static let radius: CGFloat = 30
    /// Шапка `modal-sheet / header`
    static let headerHeight: CGFloat = 56
    static let indicatorWidth: CGFloat = 36
    static let indicatorHeight: CGFloat = 3
    static let indicatorTop: CGFloat = 6
    /// ✕ макета — круг 28 на 16 от верха и правого края. У нас `PlusButton` S 32 (как ✕
    /// шеринга) с тем же центром: на 2 ближе к углу.
    static let closeDesign: CGFloat = 28
    static let closeInset: CGFloat = 16
    static var closeOffset: CGFloat { closeInset + (closeDesign - PlusButtonSize.s.height) / 2 }
    static let side: CGFloat = 16
    /// Между блоками содержимого — шапкой, пометками, «Моей волной» и островками
    static let blockGap: CGFloat = 16
    /// Шапка-сущность: обложка 52 r6, до текста 12, точка-разделитель 3 через 4
    static let entityCover: CGFloat = 52
    static let entityCoverRadius: CGFloat = 6
    static let entityGap: CGFloat = 12
    static let dot: CGFloat = 3
    static let dotGap: CGFloat = 4
    /// «Моя волна»: капсула 72, поля 24 слева и 32 справа, ▶ 36, до текста 8
    static let vibeHeight: CGFloat = 72
    static let vibeLeading: CGFloat = 24
    static let vibeTrailing: CGFloat = 32
    static let vibeIcon: CGFloat = 36
    static let vibeGap: CGFloat = 8
    static let groupGap: CGFloat = 8
    /// Поля островка сверху и снизу
    static let groupPadding: CGFloat = 4
    static let groupRadius: CGFloat = 16
    /// Ячейка: 14 + строка 20 + 14 — иконка 24 выступает за строку поровну
    static let cellHeight: CGFloat = 48
    static let cellPadding: CGFloat = 16
    static let iconGap: CGFloat = 12
    static let icon: CGFloat = 24
    /// От последнего островка до safe area (`Navigation`, `pt-24`)
    static let bottom: CGFloat = 24
    /// Затемнение под шторкой — `monochrome/black-60` (вне палитры Theme)
    static let fadeOpacity: Double = 0.6
    /// Тень названия «Моей волны» — `0 1 8` чёрным 8 % (радиус SwiftUI — половина блюра)
    static let vibeShadowOpacity: Double = 0.08
    static let vibeShadowRadius: CGFloat = 4
    static let vibeShadowY: CGFloat = 1
}

enum ActionSheetMotion {
    /// Выезд и уход — по экрану, ease-in-out; уход короче.
    static let open: Animation = .easeInOut(duration: 0.35)
    static let close: Animation = .easeInOut(duration: 0.3)
    static let closeDuration: TimeInterval = 0.3
    /// Не дотянул — встаёт на место.
    static let settle: Animation = .smooth(duration: 0.3)
    /// Отпущена ниже этой доли своей высоты — закрывается.
    static let dismissFraction: CGFloat = 0.3
    /// Бросок вниз быстрее этого закрывает с любого места; такой же вверх — отменяет.
    static let flickVelocity: CGFloat = 600
    /// Reduce Motion — только прозрачность.
    static let reducedFade: Animation = .easeInOut(duration: 0.25)
    static let reducedDuration: TimeInterval = 0.25
    /// Долгое нажатие на карточку или строку — как у системного контекстного меню
    static let holdDuration: Duration = .milliseconds(500)
}

// MARK: - Шторка

/// Шторка действий: затемнение чёрным 60 % на весь экран, снизу — лист со стеклом
/// Surface/Five (блюр хрома, бордер Fill/Nine), индикатор и ✕ в шапке, ниже шапка-сущность,
/// пометки, «Моя волна» и островки пунктов. Выезжает снизу, закрывается ✕, тапом
/// по затемнению, свайпом вниз (лист идёт за пальцем с первого пункта, вверх — резиной)
/// и пунктом с действием.
struct ActionSheetOverlay: View {
    let content: ActionSheetContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShown = false
    @State private var isClosing = false
    /// Высота листа над safe area — путь выезда. Сдвиг — трансформ, раскладку листа
    /// он не трогает; до замера лист стоит за кромкой экрана.
    @State private var sheetHeight: CGFloat?
    /// Ход листа за пальцем — по касанию, не покадровая анимация.
    @State private var drag: CGFloat = 0
    /// Ход жеста в момент, когда он признан: лист едет от этой точки, без скачка на порог.
    @State private var dragStart: CGFloat?

    private typealias L = ActionSheetLayout

    /// Весь путь листа — с безопасной зоной под ним.
    private var travel: CGFloat {
        (sheetHeight ?? PlusMetrics.screenWidth * 4) + PlusChromeMetrics.bottomSafeArea
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(L.fadeOpacity)
                .opacity(fadeVisibility)
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture(perform: close)
                .accessibilityHidden(true)

            sheet
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    let isFirst = sheetHeight == nil
                    sheetHeight = height
                    if isFirst { open() }
                }
                .offset(y: reduceMotion ? 0 : (isShown ? drag : travel))
                .opacity(reduceMotion && !isShown ? 0 : 1)
                .gesture(dragGesture)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityAction(.escape, close)
    }

    /// Затемнение гаснет вместе с ходом листа вниз.
    private var fadeVisibility: Double {
        guard isShown else { return 0 }
        return Double(1 - min(1, max(0, drag) / travel))
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: L.blockGap) {
                if let entity = content.header {
                    entityRow(entity)
                }
                if !content.notes.isEmpty {
                    Text(content.notes.joined(separator: "\n"))
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillOne)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, L.side)
                }
                if let vibe = content.vibe {
                    vibeButton(vibe)
                }
                VStack(spacing: L.groupGap) {
                    ForEach(content.groups.indices, id: \.self) { index in
                        island(content.groups[index])
                    }
                }
                .padding(.horizontal, L.side)
            }
        }
        .padding(.bottom, L.bottom)
        .frame(maxWidth: .infinity)
        // Стекло — до физического низа экрана, под home indicator; пункты — над ним.
        .background {
            Color.clear
                .glassSurface(
                    UnevenRoundedRectangle(topLeadingRadius: L.radius, topTrailingRadius: L.radius, style: .continuous),
                    blur: PlusMetrics.glassBlur,
                    fill: .surfaceFive,
                    border: .fillNine,
                    borderWidth: PlusMetrics.hairline
                )
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var header: some View {
        Color.clear
            .frame(height: L.headerHeight)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.fillEight)
                    .frame(width: L.indicatorWidth, height: L.indicatorHeight)
                    .padding(.top, L.indicatorTop)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                PlusButton(icon: "iconCross", type: .secondary, size: .s, accessibilityTitle: "Закрыть", haptic: .inAction) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    close()
                }
                .padding(.top, L.closeOffset)
                .padding(.trailing, L.closeOffset)
            }
    }

    // MARK: Шапка-сущность и «Моя волна»

    private func entityRow(_ entity: ActionSheetHeader) -> some View {
        HStack(spacing: L.entityGap) {
            if entity.isCircle {
                CollectionArtwork(source: entity.artwork, width: L.entityCover, height: L.entityCover, shape: Circle())
            } else {
                CollectionArtwork(
                    source: entity.artwork,
                    width: L.entityCover,
                    height: L.entityCover,
                    shape: RoundedRectangle(cornerRadius: L.entityCoverRadius, style: .continuous)
                )
            }
            VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                Text(entity.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                let details = entity.details.filter { !$0.isEmpty }
                if !details.isEmpty {
                    HStack(spacing: L.dotGap) {
                        ForEach(details.indices, id: \.self) { index in
                            if index > 0 {
                                Circle()
                                    .fill(Color.fillSeven)
                                    .frame(width: L.dot, height: L.dot)
                            }
                            Text(details[index])
                                .plusText(.textM, .medium)
                                .foregroundStyle(Color.fillSubtitle)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, L.side)
        .accessibilityElement(children: .combine)
    }

    /// Капсула вне шкалы кнопок ДС — своя, но просадка и хаптика как у `PlusButton`
    /// с текстом.
    private func vibeButton(_ vibe: ActionSheetVibe) -> some View {
        Button {
            PlayerHaptics.tap()
            guard !isClosing, let action = vibe.action else { return }
            close()
            action()
        } label: {
            HStack(spacing: L.vibeGap) {
                Image("iconPlay")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: L.vibeIcon, height: L.vibeIcon)
                    .foregroundStyle(Color.fillOne)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: EntitySectionLayout.textStackGap) {
                    Text(vibe.caption)
                        .plusText(.textM, .medium)
                        .foregroundStyle(Color.fillSubtitle)
                        .lineLimit(1)
                    Text(vibe.title)
                        .plusHeadline(.xl)
                        .foregroundStyle(Color.fillOne)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(L.vibeShadowOpacity), radius: L.vibeShadowRadius, y: L.vibeShadowY)
                }
            }
            .padding(.leading, L.vibeLeading)
            .padding(.trailing, L.vibeTrailing)
            .frame(height: L.vibeHeight)
            .background(Capsule().fill(Color.buttonsPrimary))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.textButtonScale))
        .padding(.horizontal, L.side)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(vibe.caption) «\(vibe.title)»")
    }

    // MARK: Островки

    /// Островок — `cell / cell-table / grouped-island`: Fill/Nine r16, поля 4, между
    /// ячейками разделители 0.5 от 16 слева до правого края.
    private func island(_ items: [ActionSheetItem]) -> some View {
        let shape = RoundedRectangle(cornerRadius: L.groupRadius, style: .continuous)
        return VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                cell(items[index])
                    .overlay(alignment: .bottom) {
                        if index < items.count - 1 {
                            ListDivider().padding(.leading, L.cellPadding)
                        }
                    }
            }
        }
        .padding(.vertical, L.groupPadding)
        // Подсветка нажатия — во всю ячейку: у крайних углы вылезали бы за скругление.
        .clipShape(shape)
        .background(shape.fill(Color.fillNine))
    }

    private func cell(_ item: ActionSheetItem) -> some View {
        Button { perform(item) } label: {
            HStack(spacing: L.iconGap) {
                Image(item.icon)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: L.icon, height: L.icon)
                    .foregroundStyle(item.iconColor)
                    .accessibilityHidden(true)
                Text(item.title)
                    .plusText(.textM, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, L.cellPadding)
            .frame(height: L.cellHeight)
            .contentShape(.rect)
        }
        .buttonStyle(CellHighlightButtonStyle())
    }

    // MARK: Действия

    private func open() {
        withAnimation(reduceMotion ? ActionSheetMotion.reducedFade : ActionSheetMotion.open) {
            isShown = true
        }
    }

    /// Пункт с действием закрывает шторку и делает своё; без действия — только отклик.
    private func perform(_ item: ActionSheetItem) {
        PlayerHaptics.tap()
        guard !isClosing, let action = item.action else { return }
        close()
        action()
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(reduceMotion ? ActionSheetMotion.reducedFade : ActionSheetMotion.close) {
            isShown = false
            drag = 0
        }
        ActionSheetState.shared.remove(
            after: reduceMotion ? ActionSheetMotion.reducedDuration : ActionSheetMotion.closeDuration
        )
    }

    // MARK: Свайп

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isClosing, !reduceMotion else { return }
                let start = dragStart ?? value.translation.height
                if dragStart == nil { dragStart = start }
                let shift = value.translation.height - start
                // Вверх — резиной: вчетверо медленнее пальца, с мягким потолком.
                drag = shift >= 0 ? shift : -ServiceTopNavMotion.pullShift(for: shift)
            }
            .onEnded { value in
                let start = dragStart ?? 0
                dragStart = nil
                guard !isClosing, !reduceMotion else { return }
                let shift = value.translation.height - start
                let velocity = value.velocity.height
                let isFlickDown = velocity > ActionSheetMotion.flickVelocity
                let isFlickUp = velocity < -ActionSheetMotion.flickVelocity
                if isFlickDown || (!isFlickUp && shift > travel * ActionSheetMotion.dismissFraction) {
                    close()
                } else {
                    withAnimation(ActionSheetMotion.settle) { drag = 0 }
                }
            }
    }
}

// MARK: - Откуда открывается

extension View {
    /// Шторка по долгому нажатию на карточку или строку. Содержимое собирается в момент
    /// нажатия — пункты показывают текущее состояние («нравится», «скачано»).
    func actionSheetOnHold(_ content: @escaping @MainActor () -> ActionSheetContent?) -> some View {
        gesture(ActionSheetHold {
            guard let content = content() else { return }
            PlayerHaptics.tap()
            ActionSheetState.shared.present(content)
        })
    }
}

/// «Ещё» строки — открывает шторку. Вид и отклик — `TrackMoreButton` (plain M).
struct ActionSheetMoreButton: View {
    let content: @MainActor () -> ActionSheetContent?

    var body: some View {
        TrackMoreButton {
            guard let content = content() else { return }
            ActionSheetState.shared.present(content)
        }
    }
}

/// Долгое нажатие. Распознаватель пассивный, как у просадки (`PressTouchRecognizer`):
/// сам не срабатывает и касание ни у кого не отнимает — скролл, кнопка и тап строки
/// работают как без него, а он по таймеру зовёт действие, если палец стоит на месте.
/// Отпускание после этого доходит до кнопки как тап — его гасит открытая шторка
/// (`ActionSheetState.isPresented`).
private struct ActionSheetHold: UIGestureRecognizerRepresentable {
    let action: @MainActor () -> Void

    func makeUIGestureRecognizer(context: Context) -> ActionSheetHoldRecognizer {
        ActionSheetHoldRecognizer(target: nil, action: nil)
    }

    func updateUIGestureRecognizer(_ recognizer: ActionSheetHoldRecognizer, context: Context) {
        recognizer.onHold = action
    }
}

private final class ActionSheetHoldRecognizer: UIGestureRecognizer {
    var onHold: @MainActor () -> Void = {}

    private weak var touch: UITouch?
    private var origin = CGPoint.zero
    private var timer: Task<Void, Never>?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesEnded = false
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard touch == nil, let first = touches.first, !Self.isScrolling(under: first) else {
            state = .failed
            return
        }
        touch = first
        origin = first.location(in: nil)
        timer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: ActionSheetMotion.holdDuration)
            guard !Task.isCancelled, let self, let touch = self.touch, !Self.isScrolling(under: touch) else { return }
            self.onHold()
            self.finish()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch, touches.contains(touch) else { return }
        let point = touch.location(in: nil)
        if hypot(point.x - origin.x, point.y - origin.y) > PressMotion.slop || Self.isScrolling(under: touch) {
            finish()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        finish()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        finish()
    }

    override func reset() {
        super.reset()
        timer?.cancel()
        timer = nil
        touch = nil
    }

    private func finish() {
        timer?.cancel()
        timer = nil
        touch = nil
        state = .failed
    }

    private static func isScrolling(under touch: UITouch) -> Bool {
        guard let view = touch.view else { return false }
        return sequence(first: view, next: \.superview).contains { view in
            guard let scroll = view as? UIScrollView else { return false }
            return scroll.isDragging || scroll.isDecelerating
        }
    }
}
