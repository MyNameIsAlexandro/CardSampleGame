import SwiftUI

/// Editable view for [String: Int] dictionaries.
struct DictEditor: View {
    let label: String
    @Binding var dict: [String: Int]

    var body: some View {
        ForEach(dict.keys.sorted(), id: \.self) { key in
            HStack {
                Text(key)
                    .frame(width: 120, alignment: .leading)
                Spacer()
                TextField("Value", value: valueBinding(for: key), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Stepper("", value: valueBinding(for: key))
                    .labelsHidden()
                Button(role: .destructive) {
                    dict.removeValue(forKey: key)
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        Button {
            // Find a unique key name
            var newKey = "resource"
            var counter = 1
            while dict[newKey] != nil {
                newKey = "resource_\(counter)"
                counter += 1
            }
            dict[newKey] = 0
        } label: {
            Label("Add \(label)", systemImage: "plus.circle")
        }
    }

    private func valueBinding(for key: String) -> Binding<Int> {
        Binding(
            get: { dict[key] ?? 0 },
            set: { dict[key] = $0 }
        )
    }
}
