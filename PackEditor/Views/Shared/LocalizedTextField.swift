import SwiftUI

/// A component for editing localized text with separate English and Russian fields.
///
/// Displays two text input fields side by side (or stacked on small screens) for editing
/// `LocalizedString` content. The component works with `Binding<String>` for each language
/// to allow mutation of immutable `LocalizableText` structures.
///
/// Example usage:
/// ```swift
/// @State private var enText = "Hello"
/// @State private var ruText = "Привет"
///
/// LocalizedTextField(
///     label: "Greeting",
///     en: $enText,
///     ru: $ruText
/// )
/// ```
struct LocalizedTextField: View {
    /// Label displayed above the text fields
    let label: String

    /// Binding to the English text value
    @Binding var en: String

    /// Binding to the Russian text value
    @Binding var ru: String

    /// If true, uses TextEditor for multiline input; otherwise uses TextField
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(label)
                .font(.headline)
                .foregroundColor(.secondary)

            // Two-column layout for EN and RU fields
            HStack(spacing: 16) {
                // English field
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("🇺🇸")
                            .font(.body)
                        Text("English")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if multiline {
                        TextEditor(text: $en)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                            .border(Color.gray.opacity(0.3), width: 1)
                            .cornerRadius(4)
                    } else {
                        TextField("Enter English text", text: $en)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: .infinity)

                // Russian field
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("🇷🇺")
                            .font(.body)
                        Text("Русский")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if multiline {
                        TextEditor(text: $ru)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                            .border(Color.gray.opacity(0.3), width: 1)
                            .cornerRadius(4)
                    } else {
                        TextField("Enter Russian text", text: $ru)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @State var enText = "Hello, World!"
    @State var ruText = "Привет, мир!"
    @State var enMultiline = "Line 1\nLine 2\nLine 3"
    @State var ruMultiline = "Строка 1\nСтрока 2\nСтрока 3"

    return VStack(spacing: 32) {
        LocalizedTextField(
            label: "Single Line Example",
            en: $enText,
            ru: $ruText
        )

        LocalizedTextField(
            label: "Multiline Example",
            en: $enMultiline,
            ru: $ruMultiline,
            multiline: true
        )

        Spacer()
    }
    .padding()
    .frame(width: 600, height: 400)
}
