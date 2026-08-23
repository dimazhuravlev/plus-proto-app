import SwiftUI

/// Экран фильма. Пока заглушка того же вида, что у книги и альбома — по нему
/// проверяется зум-переход с карточки витрины.
///
/// Полная вёрстка собирается по `docs/research/figma-moviecard.md`
/// (макет `IKXMroHnoO08WT5W6Rd2bs`, нода `2101:20320`).
struct MovieScreen: View {
    let entity: EntityRef

    var body: some View {
        EntityStubScreen(entity: entity, kind: "Фильм")
    }
}
