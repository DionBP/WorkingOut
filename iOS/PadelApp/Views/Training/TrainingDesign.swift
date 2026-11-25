import SwiftUI
import UIKit

enum TrainingDesign {
    static let background = adaptive(light: 0.965, dark: 0.055)
    static let surface = adaptive(light: 1, dark: 0.115)
    static let subdued = adaptive(light: 0.94, dark: 0.17)
    static let route = adaptive(light: 0.12, dark: 0.93)
    static let accent = Color(red: 1.0, green: 0.34, blue: 0.06)
    static let spacing: CGFloat = 18

    private static func adaptive(light: CGFloat, dark: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(white: traits.userInterfaceStyle == .dark ? dark : light, alpha: 1)
        })
    }

    static func section(_ title: String) -> some View {
        Text(title).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
    }

    static func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24, content: content)
                .frame(maxWidth: 700)
                .padding(.horizontal, spacing)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
        }
        .background(background.ignoresSafeArea())
        .tint(accent)
    }
}

struct TrainingPanel: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(TrainingDesign.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TrainingDesign.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct TrainingMetric: View {
    var label: String
    var value: String
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.subheadline.weight(.semibold)).accessibilityHidden(true)
            Text(value).font(.title2.weight(.bold)).monospacedDigit()
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .modifier(TrainingPanel())
        .accessibilityElement(children: .combine)
    }
}

struct TrainingCTA: ButtonStyle {
    var inverted = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(inverted ? Color.black : Color.white)
            .background(inverted ? Color.white : TrainingDesign.accent, in: RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
    }
}
