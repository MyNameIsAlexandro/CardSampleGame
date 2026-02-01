import SwiftUI

struct StringListEditor: View {
    let label: String
    @Binding var items: [String]

    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            HStack {
                TextField("Item", text: $items[index])
                Button(role: .destructive) {
                    items.remove(at: index)
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        Button {
            items.append("")
        } label: {
            Label("Add \(label)", systemImage: "plus.circle")
        }
    }
}
