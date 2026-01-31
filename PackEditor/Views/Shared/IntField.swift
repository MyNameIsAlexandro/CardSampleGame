import SwiftUI

struct IntField: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int>? = nil

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Stepper("", value: $value, in: range ?? Int.min...Int.max)
                .labelsHidden()
        }
    }
}
