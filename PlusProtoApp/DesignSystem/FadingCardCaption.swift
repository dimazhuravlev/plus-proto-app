import SwiftUI
import UIKit

/// Две строки без многоточия: при переполнении затухает только последняя.
struct FadingCardCaption: View {
    let title: String
    let width: CGFloat
    var leadingAligned = false
    var subtitle: String? = nil

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
        var secondStart: Int?
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { _, _, _, range, stop in
            let characters = layout.characterRange(forGlyphRange: range, actualGlyphRange: nil)
            if result.count == 1 { secondStart = characters.location }
            result.append((plain as NSString).substring(with: characters).trimmingCharacters(in: .whitespacesAndNewlines))
            if result.count == 3 { stop.pointee = true }
        }
        if result.count > 2, let secondStart {
            result[1] = (plain as NSString).substring(from: secondStart)
        }
        return result
    }

    var body: some View {
        let lines = lines
        let displayed = subtitle.map { [title.replacingOccurrences(of: "\n", with: " "), $0] } ?? Array(lines.prefix(2))
        VStack(alignment: leadingAligned ? .leading : .center, spacing: 0) {
            ForEach(Array(displayed.enumerated()), id: \.offset) { index, line in
                let overflows = (line as NSString).size(withAttributes: [.font: font]).width > width
                Text(line)
                    .plusText(.textS, .medium)
                    .foregroundStyle(subtitle != nil && index == 1 ? Color.fillSubtitle : Color.fillOne)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: width, height: 16, alignment: leadingAligned || overflows ? .leading : .center)
                    .clipped()
                    .mask {
                        if (subtitle == nil && index == 1 && lines.count > 2) || (subtitle != nil && (line as NSString).size(withAttributes: [.font: font]).width > width) {
                            let textWidth = min(width, max(1, (line as NSString).size(withAttributes: [.font: font]).width))
                            let end = leadingAligned ? textWidth : (width + textWidth) / 2
                            LinearGradient(stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: max(0, end - 8) / max(1, width)),
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
