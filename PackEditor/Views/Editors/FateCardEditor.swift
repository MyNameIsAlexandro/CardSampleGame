import SwiftUI
import TwilightEngine

struct FateCardEditor: View {
    @Binding var card: FateCard

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: card.id)
                LabeledContent("Name", value: card.name)
                if let nameKey = card.nameKey {
                    LabeledContent("Name Key", value: nameKey)
                }
                if let suit = card.suit {
                    LabeledContent("Suit", value: suit.rawValue)
                }
                if let keyword = card.keyword {
                    LabeledContent("Keyword", value: keyword.rawValue)
                }
                LabeledContent("Card Type", value: card.cardType.rawValue)
            }

            Section("Values") {
                LabeledContent("Base Value", value: "\(card.baseValue)")
                LabeledContent("Critical", value: card.isCritical ? "Yes" : "No")
                LabeledContent("Sticky", value: card.isSticky ? "Yes" : "No")
            }

            Section("Resonance Rules (\(card.resonanceRules.count))") {
                if card.resonanceRules.isEmpty {
                    Text("No resonance rules").foregroundStyle(.secondary)
                } else {
                    ForEach(card.resonanceRules, id: \.self) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Zone").fontWeight(.medium)
                                Spacer()
                                Text(rule.zone.rawValue).foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Modify Value").fontWeight(.medium)
                                Spacer()
                                Text("\(rule.modifyValue)").foregroundStyle(.secondary)
                            }
                            if let effect = rule.visualEffect {
                                HStack {
                                    Text("Visual Effect").fontWeight(.medium)
                                    Spacer()
                                    Text(effect).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("On Draw Effects (\(card.onDrawEffects.count))") {
                if card.onDrawEffects.isEmpty {
                    Text("No draw effects").foregroundStyle(.secondary)
                } else {
                    ForEach(card.onDrawEffects, id: \.self) { effect in
                        HStack {
                            LabeledContent("Type", value: effect.type.rawValue)
                            Spacer()
                            LabeledContent("Value", value: "\(effect.value)")
                        }
                    }
                }
            }

            if let choices = card.choiceOptions, !choices.isEmpty {
                Section("Choice Options (\(choices.count))") {
                    ForEach(choices, id: \.self) { option in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("Label", value: option.label)
                            LabeledContent("Effect", value: option.effect)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
