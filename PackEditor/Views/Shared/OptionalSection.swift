import SwiftUI

struct OptionalSection<Content: View>: View {
    let label: String
    @Binding var isEnabled: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        Section {
            Toggle(label, isOn: $isEnabled)
            if isEnabled {
                content()
            }
        }
    }
}
