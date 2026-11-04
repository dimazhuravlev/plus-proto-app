import SwiftUI
import UIKit

/// Две строки без многоточия: при переполнении затухает только последняя.
struct FadingCardCaption: View {
    let title: String
    let width: CGFloat

    private var font: UIFont {
        PlusTextSize.textS.uiFont(.medium)
    }

    private var lines: [String] {
        let plain = title.replacingOccurrences(of: "\n", with: " ")
        let storage = NSTextStorage(string: plain, attributes: [.font: font])
        let layout = NSLayoutManager()
        // Третья строка нужна только для обнаружения обрезанного продолжения.
        let container = NSTextContainer(size: CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = 3
        container.lineBreakMode = .byWordWrapping
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        var result: [String] = []
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { _, _, _, range, stop in
            let characters = layout.characterRange(forGlyphRange: range, actualGlyphRange: nil)
            result.append((plain as NSString).substring(with: characters).trimmingCharacters(in: .whitespacesAndNewlines))
            if result.count == 3 { stop.pointee = true }
        }
        return result
    }

    var body: some View {
        let lines = lines
        VStack(alignment: .center, spacing: 0) {
            ForEach(Array(lines.prefix(2).enumerated()), id: \.offset) { index, line in
                Text(line)
                    .plusText(.textS, .medium)
                    .foregroundStyle(Color.fillOne)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: width, height: 16, alignment: .center)
                    .clipped()
                    .mask {
                        if index == 1 && lines.count > 2 {
                            let textWidth = min(width, max(1, (line as NSString).size(withAttributes: [.font: font]).width))
                            let end = (width + textWidth) / 2
                            LinearGradient(stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: max(0, end - 16) / max(1, width)),
                                .init(color: .clear, location: end / max(1, width)),
                                .init(color: .clear, location: 1)
                            ], startPoint: .leading, endPoint: .trailing)
                        } else { Color.white }
                    }
            }
        }
        .frame(width: width, height: 32, alignment: .top)
        .accessibilityLabel(title)
    }
}
