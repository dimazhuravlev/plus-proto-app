import SwiftUI
import UIKit

@MainActor private enum PromoSynopsisCache {
    static var lines: [String: [String]] = [:]
}

/// Фиксированный текстовый слот. TextKit переносит полную аннотацию без ellipsis;
/// максимум три строки, только обрезанная третья затухает справа.
struct PromoSynopsis: View {
    let text: String
    var availableWidth: CGFloat? = nil
    private var width: CGFloat { max(1, availableWidth ?? min(300, PlusMetrics.screenWidth - 48)) }
    private let lineHeight: CGFloat = 16

    @MainActor private var lines: [String] {
        let key = "\(width)|\(text)"
        if let cached = PromoSynopsisCache.lines[key] { return cached }
        let plain = text.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let font = UIFont(name: PlusFont.textMedium, size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        let storage = NSTextStorage(string: plain, attributes: [.font: font, .paragraphStyle: paragraph])
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: lineHeight * 4))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = 4
        container.lineBreakMode = .byWordWrapping
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        layout.ensureLayout(for: container)
        var result: [String] = []
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) { _, _, _, range, stop in
            let characters = layout.characterRange(forGlyphRange: range, actualGlyphRange: nil)
            result.append((plain as NSString).substring(with: characters).trimmingCharacters(in: .whitespacesAndNewlines))
            if result.count == 4 { stop.pointee = true }
        }
        PromoSynopsisCache.lines[key] = result
        return result
    }

    var body: some View {
        let lines = lines
        VStack(alignment: .center, spacing: 0) {
            ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { index, line in
                Text(line).plusText(.textS, .medium).foregroundStyle(Color.fillOne)
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .frame(width: width, height: lineHeight, alignment: .center).clipped()
                    .mask {
                        if index == 2 && lines.count > 3 {
                            let font = UIFont(name: PlusFont.textMedium, size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
                            let end = min(width, max(1, (line as NSString).size(withAttributes: [.font: font]).width))
                            let leading: CGFloat = (width - end) / 2
                            LinearGradient(stops: [.init(color: .white, location: 0),
                                                   .init(color: .white, location: max(0, leading + end - 24) / width),
                                                   .init(color: .clear, location: (leading + end) / width),
                                                   .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
                        } else { Color.white }
                    }
            }
        }
        .frame(width: width, height: lineHeight * 3, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

extension ShowcaseBlock {
    var promoSynopsis: String? {
        switch self {
        case .movie(let movie): movie.synopsis ?? movie.caption
        case .book(let book): book.synopsis ?? book.caption
        default: nil
        }
    }
}
