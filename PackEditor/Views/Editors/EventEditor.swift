import SwiftUI
import TwilightEngine

struct EventEditor: View {
    @Binding var event: EventDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: event.id)
                LabeledContent("Title (EN)", value: event.title.displayString)
                LabeledContent("Body", value: event.body.displayString)
            }

            Section("Settings") {
                LabeledContent("Weight", value: "\(event.weight)")
                LabeledContent("One-time", value: event.isOneTime ? "Yes" : "No")
                LabeledContent("Instant", value: event.isInstant ? "Yes" : "No")
                LabeledContent("Cooldown", value: "\(event.cooldown)")
                LabeledContent("Pool IDs", value: event.poolIds.joined(separator: ", "))
            }

            Section("Choices (\(event.choices.count))") {
                ForEach(event.choices) { choice in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(choice.label.displayString).fontWeight(.medium)
                        Text("ID: \(choice.id)").font(.caption).foregroundStyle(.secondary)
                        if let tooltip = choice.tooltip {
                            Text(tooltip.displayString).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
    }
}
