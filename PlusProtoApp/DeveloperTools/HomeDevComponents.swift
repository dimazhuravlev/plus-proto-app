import SwiftUI

extension HomeDevControls {
    func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).plusText(.textM, .semibold)
            content()
        }
    }

    func sliderTile<Control: View>(_ title: String, value: String, @ViewBuilder control: () -> Control) -> some View
    {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).fixedSize(horizontal: false, vertical: true)
            Text(value).monospacedDigit().foregroundStyle(Color.fillSubtitle)
            control()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.buttonsSecondary, in: RoundedRectangle(cornerRadius: 14))
    }

    func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }

    func hint(_ text: String) -> some View {
        Text(text).foregroundStyle(Color.fillSubtitle)
            .fixedSize(horizontal: false, vertical: true)
    }
}
