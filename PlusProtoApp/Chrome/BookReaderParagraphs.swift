import SwiftUI

/// Колонка абзацев читалки.
struct BookReaderParagraphs: View {
    let paragraphs: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: PlusTextSize.textL.lineHeight) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph).plusText(.textL, .medium)
                    .foregroundStyle(Color.fillFour)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
