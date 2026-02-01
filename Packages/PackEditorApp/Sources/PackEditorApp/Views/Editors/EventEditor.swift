import SwiftUI
import TwilightEngine
import PackEditorKit

struct EventEditor: View {
    @Binding var event: EventDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: event.id)
                LocalizedTextField(label: "Title", text: $event.title)
                    .validated(event.title.displayString.isEmpty ? .error("Title is required") : nil)
                LocalizedTextField(label: "Body", text: $event.body, multiline: true)
            }

            Section("Kind") {
                LabeledContent("Event Kind", value: String(describing: event.eventKind))
            }

            Section("Settings") {
                IntField(label: "Weight", value: $event.weight)
                    .validated(event.weight <= 0 ? .warning("Weight should be positive") : nil)
                Toggle("One-time", isOn: $event.isOneTime)
                Toggle("Instant", isOn: $event.isInstant)
                IntField(label: "Cooldown", value: $event.cooldown)
                StringListEditor(label: "Pool IDs", items: $event.poolIds)
            }

            Section("Availability (read-only)") {
                LabeledContent("Availability", value: String(describing: event.availability))
            }

            Section("Choices (\(event.choices.count))") {
                ForEach(event.choices.indices, id: \.self) { index in
                    DisclosureGroup(event.choices[index].label.displayString) {
                        TextField("ID", text: $event.choices[index].id)

                        LocalizedTextField(label: "Label", text: $event.choices[index].label)

                        LocalizedTextField(label: "Tooltip", text: tooltipBinding(at: index))

                        LabeledContent("Requirements",
                                       value: String(describing: event.choices[index].requirements ?? "None" as Any))

                        LabeledContent("Consequences",
                                       value: String(describing: event.choices[index].consequences))

                        Button(role: .destructive) {
                            event.choices.remove(at: index)
                        } label: {
                            Label("Remove Choice", systemImage: "minus.circle")
                        }
                    }
                }

                Button {
                    event.choices.append(
                        ChoiceDefinition(
                            id: "choice_new",
                            label: .inline(LocalizedString(en: "New Choice", ru: "Новый выбор")),
                            consequences: ChoiceConsequences()
                        )
                    )
                } label: {
                    Label("Add Choice", systemImage: "plus.circle")
                }
            }

            if let challenge = event.miniGameChallenge {
                Section("Mini-Game Challenge (read-only)") {
                    LabeledContent("Challenge", value: String(describing: challenge))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func tooltipBinding(at index: Int) -> Binding<LocalizableText> {
        Binding(
            get: { event.choices[index].tooltip ?? .inline(LocalizedString(en: "", ru: "")) },
            set: { newValue in
                if case .inline(let ls) = newValue, ls.en.isEmpty && ls.ru.isEmpty {
                    event.choices[index].tooltip = nil
                } else {
                    event.choices[index].tooltip = newValue
                }
            }
        )
    }
}
