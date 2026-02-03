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
                ForEach(Array(event.choices.enumerated()), id: \.element.id) { index, choice in
                    DisclosureGroup(choice.label.displayString) {
                        TextField("ID", text: choiceIdBinding(at: index))

                        LocalizedTextField(label: "Label", text: choiceLabelBinding(at: index))

                        LocalizedTextField(label: "Tooltip", text: tooltipBinding(at: index))

                        LabeledContent("Requirements",
                                       value: String(describing: choice.requirements ?? "None" as Any))

                        LabeledContent("Consequences",
                                       value: String(describing: choice.consequences))

                        Button(role: .destructive) {
                            guard index < event.choices.count else { return }
                            event.choices.remove(at: index)
                        } label: {
                            Label("Remove Choice", systemImage: "minus.circle")
                        }
                    }
                }

                Button {
                    event.choices.append(
                        ChoiceDefinition(
                            id: "choice_new_\(UUID().uuidString.prefix(4))",
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
            get: {
                guard index < event.choices.count else { return .inline(LocalizedString(en: "", ru: "")) }
                return event.choices[index].tooltip ?? .inline(LocalizedString(en: "", ru: ""))
            },
            set: { newValue in
                guard index < event.choices.count else { return }
                if case .inline(let ls) = newValue, ls.en.isEmpty && ls.ru.isEmpty {
                    event.choices[index].tooltip = nil
                } else {
                    event.choices[index].tooltip = newValue
                }
            }
        )
    }

    // MARK: - Safe Choice Bindings

    private func choiceIdBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < event.choices.count else { return "" }
                return event.choices[index].id
            },
            set: { newValue in
                guard index < event.choices.count else { return }
                event.choices[index].id = newValue
            }
        )
    }

    private func choiceLabelBinding(at index: Int) -> Binding<LocalizableText> {
        Binding(
            get: {
                guard index < event.choices.count else { return .inline(LocalizedString(en: "", ru: "")) }
                return event.choices[index].label
            },
            set: { newValue in
                guard index < event.choices.count else { return }
                event.choices[index].label = newValue
            }
        )
    }
}
