import SwiftUI

struct JSONPreviewSheet<T: Encodable>: View {
    let title: String
    let value: T
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(jsonString, forType: .string)
                }
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                Text(jsonString)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var jsonString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "Failed to encode JSON"
        }
        return string
    }
}
