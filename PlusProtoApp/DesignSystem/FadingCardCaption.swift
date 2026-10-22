import SwiftUI
import UIKit

/// Полная строка без многоточия, по центру карточки. Если она шире миниатюры,
/// текст выравнивается слева и затухает справа. Замеряем только текст, не раскладку вью.
struct FadingCardCaption: View {
    let title: String
    let width: CGFloat

    private var overflows: Bool {
        let font = UIFont(name: PlusFont.textMedium, size: 13) ?? .systemFont(ofSize: 13)
        return (title as NSString).size(withAttributes: [.font: font]).width > width
    }

    var body: some View {
        Text(title.replacingOccurrences(of: "\n", with: " "))
            .plusText(.textS, .medium)
            .foregroundStyle(Color.fillOne)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: width, height: 16, alignment: overflows ? .leading : .center)
            .clipped()
            .mask {
                if overflows {
                    LinearGradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: min(0.5, 16 / width)),
                        .init(color: .white, location: max(0, 1 - 16 / width)),
                        .init(color: .clear, location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                } else {
                    Color.white
                }
            }
            .accessibilityLabel(title)
    }
}
