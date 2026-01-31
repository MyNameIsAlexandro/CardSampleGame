import SwiftUI
import TwilightEngine
import PackEditorKit

struct CardEditor: View {
    @Binding var card: StandardCardDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: card.id)
                LabeledContent("Name (EN)", value: card.name.displayString)
                LabeledContent("Type", value: card.cardType.rawValue)
                LabeledContent("Rarity", value: card.rarity.rawValue)
                LabeledContent("Description", value: card.description.displayString)
            }

            Section("Stats") {
                LabeledContent("Faith Cost", value: "\(card.faithCost)")
                if let power = card.power { LabeledContent("Power", value: "\(power)") }
                if let defense = card.defense { LabeledContent("Defense", value: "\(defense)") }
                if let wisdom = card.wisdom { LabeledContent("Wisdom", value: "\(wisdom)") }
                if let realm = card.realm { LabeledContent("Realm", value: realm.rawValue) }
                if let balance = card.balance { LabeledContent("Balance", value: balance.rawValue) }
                if let role = card.role { LabeledContent("Role", value: role.rawValue) }
            }

            Section("Meta") {
                LabeledContent("Icon", value: card.icon)
                LabeledContent("Expansion", value: card.expansionSet.rawValue)
            }

            Section("Abilities (\(card.abilities.count))") {
                if card.abilities.isEmpty {
                    Text("No abilities").foregroundStyle(.secondary)
                } else {
                    ForEach(card.abilities) { ability in
                        VStack(alignment: .leading) {
                            Text(ability.name).fontWeight(.medium)
                            Text(ability.description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
