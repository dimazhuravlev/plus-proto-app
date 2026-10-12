import SwiftUI

// Адаптивная вёрстка: макет снят на 402 pt (`PlusMetrics.designWidth`), устройства бывают
// уже и шире. Размеры считаем от `PlusMetrics.screenWidth` и констант макета, а не читаем
// с вью (правила 2 и 4 CLAUDE.md). Хелперы ниже — для каруселей и сеток; композиции,
// которые масштабируются целиком, берут `PlusMetrics.widthScale`.
//
// Проверка на 402: все формулы возвращают макетные значения.
// Поиск small: designCard 86 → cardWidth 86; постеры Кино: 148; история Кино: 252;
// альбомы: 159.

/// Карусель с торчащим краем следующей карточки: на любой ширине помещается столько же
/// целых карточек, сколько на 402, а торчащий край следующей — тот же, что на 402.
/// Поля и зазоры постоянные, растёт карточка.
///
///     peek      = designWidth − side − whole·(designCard + gap)      // инвариант, по макету
///     cardWidth = (screenWidth − side − peek − whole·gap) / whole    // без округления
///     scale     = cardWidth / designCard                              // для высот и пропорций
struct CarouselFit {
    /// Ширина карточки на 402
    let designCard: CGFloat
    /// Целых карточек на 402
    let whole: Int
    /// Левое поле
    let side: CGFloat
    let gap: CGFloat

    /// Торчащий край следующей карточки на 402 — инвариант на любой ширине.
    var peek: CGFloat {
        PlusMetrics.designWidth - side - CGFloat(whole) * (designCard + gap)
    }

    /// Ширина карточки на текущей ширине экрана.
    @MainActor
    var cardWidth: CGFloat {
        (PlusMetrics.screenWidth - side - peek - CGFloat(whole) * gap) / CGFloat(whole)
    }

    /// `cardWidth / designCard` — множитель для высот и пропорций карточки.
    @MainActor
    var scale: CGFloat { cardWidth / designCard }
}

/// Карусель с центрированным слотом, соседи выглядывают по краям. Видимые края соседей
/// постоянны (как на 402), растёт слот.
///
///     slot   = screenWidth − (designWidth − designSlot)
///     scale  = slot / designSlot
///     margin = (screenWidth − slot) / 2
struct CenteredCarouselFit {
    /// Ширина слота на 402
    let designSlot: CGFloat
    let gap: CGFloat

    /// Ширина центрального слота на текущей ширине экрана.
    @MainActor
    var slot: CGFloat {
        PlusMetrics.screenWidth - (PlusMetrics.designWidth - designSlot)
    }

    /// `slot / designSlot` — множитель для высот и пропорций.
    @MainActor
    var scale: CGFloat { slot / designSlot }

    /// Поле слева и справа от слота (центровка).
    @MainActor
    var margin: CGFloat { (PlusMetrics.screenWidth - slot) / 2 }
}

/// Сетки и колонки: поля и зазоры постоянные, колонки делят остаток.
enum PlusGrid {
    /// Ширина колонки сетки: `(screenWidth − 2·side − (columns−1)·gap) / columns`.
    @MainActor
    static func column(columns: Int, side: CGFloat, gap: CGFloat) -> CGFloat {
        (PlusMetrics.screenWidth - 2 * side - CGFloat(columns - 1) * gap) / CGFloat(columns)
    }

    /// Колонка треков (карусель столбцов): `screenWidth − side − peek` — колонка плюс
    /// поле справа до выглядывающей следующей.
    @MainActor
    static func columnWidth(side: CGFloat, peek: CGFloat) -> CGFloat {
        PlusMetrics.screenWidth - side - peek
    }
}
