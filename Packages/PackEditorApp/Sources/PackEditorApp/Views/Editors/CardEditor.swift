import SwiftUI
import TwilightEngine
import PackEditorKit

struct CardEditor: View {
    @Binding var card: StandardCardDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: card.id)
                LocalizedTextField(label: "Name", text: $card.name)
                    .validated(card.name.displayString.isEmpty ? .error("Name is required") : nil)
                TextField("Card Type", text: cardTypeBinding)
                TextField("Rarity", text: rarityBinding)
                LocalizedTextField(label: "Description", text: $card.description, multiline: true)
            }

            Section("Stats") {
                IntField(label: "Faith Cost", value: $card.faithCost, range: 0...99)
                    .validated(card.faithCost < 0 ? .error("Faith cost cannot be negative") : nil)
                IntField(label: "Power", value: optionalIntBinding(\.power), range: 0...99)
                IntField(label: "Defense", value: optionalIntBinding(\.defense), range: 0...99)
                IntField(label: "Wisdom", value: optionalIntBinding(\.wisdom), range: 0...99)
                TextField("Realm", text: optionalEnumBinding(
                    get: { card.realm?.rawValue ?? "" },
                    set: { card.realm = $0.isEmpty ? nil : Realm(rawValue: $0) }
                ))
                TextField("Balance", text: optionalEnumBinding(
                    get: { card.balance?.rawValue ?? "" },
                    set: { card.balance = $0.isEmpty ? nil : CardBalance(rawValue: $0) }
                ))
                TextField("Role", text: optionalEnumBinding(
                    get: { card.role?.rawValue ?? "" },
                    set: { card.role = $0.isEmpty ? nil : CardRole(rawValue: $0) }
                ))
            }

            Section("Combat") {
                IntField(label: "Energy Cost", value: optionalIntBinding(\.cost), range: 0...10)
                IntField(label: "Health", value: optionalIntBinding(\.health), range: 0...999)
                Toggle("Exhaust", isOn: $card.exhaust)
                Picker("Curse Type", selection: optionalCurseTypeBinding) {
                    Text("None").tag("")
                    ForEach(Self.curseTypes, id: \.self) { curse in
                        Text(curse).tag(curse)
                    }
                }
            }

            Section("Meta") {
                TextField("Icon", text: $card.icon)
                TextField("Expansion Set", text: expansionSetBinding)
            }

            Section("Abilities (\(card.abilities.count))") {
                ForEach(Array(card.abilities.enumerated()), id: \.element.id) { index, ability in
                    DisclosureGroup(ability.name.isEmpty ? "Ability \(index)" : ability.name) {
                        TextField("ID", text: abilityBinding(at: index, keyPath: \.id))
                        TextField("Name", text: abilityBinding(at: index, keyPath: \.name))
                        TextField("Description", text: abilityBinding(at: index, keyPath: \.description))
                        AbilityEffectEditor(effect: abilityEffectBinding(at: index))
                        Button(role: .destructive) {
                            guard index < card.abilities.count else { return }
                            card.abilities.remove(at: index)
                        } label: {
                            Label("Remove Ability", systemImage: "minus.circle.fill")
                        }
                        .foregroundStyle(.red)
                    }
                }
                Button {
                    card.abilities.append(CardAbility(id: "new_ability_\(UUID().uuidString.prefix(4))", name: "New Ability", description: "", effect: .custom("none")))
                } label: {
                    Label("Add Ability", systemImage: "plus.circle")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Enum raw-value bindings

    private var cardTypeBinding: Binding<String> {
        Binding(
            get: { card.cardType.rawValue },
            set: { if let v = CardType(rawValue: $0) { card.cardType = v } }
        )
    }

    private var rarityBinding: Binding<String> {
        Binding(
            get: { card.rarity.rawValue },
            set: { if let v = CardRarity(rawValue: $0) { card.rarity = v } }
        )
    }

    private var expansionSetBinding: Binding<String> {
        Binding(
            get: { card.expansionSet.rawValue },
            set: { if let v = ExpansionSet(rawValue: $0) { card.expansionSet = v } }
        )
    }

    // MARK: - Optional Int binding

    private func optionalIntBinding(_ keyPath: WritableKeyPath<StandardCardDefinition, Int?>) -> Binding<Int> {
        Binding(
            get: { card[keyPath: keyPath] ?? 0 },
            set: { card[keyPath: keyPath] = $0 == 0 ? nil : $0 }
        )
    }

    // MARK: - Optional enum string binding

    private func optionalEnumBinding(get: @escaping () -> String, set: @escaping (String) -> Void) -> Binding<String> {
        Binding(get: get, set: set)
    }

    // MARK: - Curse Type binding

    private static let curseTypes = [
        "weakness", "fear", "exhaustion", "greed", "shadowOfNav", "bloodCurse", "sealOfNav"
    ]

    private var optionalCurseTypeBinding: Binding<String> {
        Binding(
            get: { card.curseType?.rawValue ?? "" },
            set: { card.curseType = $0.isEmpty ? nil : CurseType(rawValue: $0) }
        )
    }

    // MARK: - Safe Ability Bindings

    private func abilityBinding(at index: Int, keyPath: WritableKeyPath<CardAbility, String>) -> Binding<String> {
        Binding(
            get: {
                guard index < card.abilities.count else { return "" }
                return card.abilities[index][keyPath: keyPath]
            },
            set: { newValue in
                guard index < card.abilities.count else { return }
                card.abilities[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func abilityEffectBinding(at index: Int) -> Binding<AbilityEffect> {
        Binding(
            get: {
                guard index < card.abilities.count else { return .custom("none") }
                return card.abilities[index].effect
            },
            set: { newValue in
                guard index < card.abilities.count else { return }
                card.abilities[index].effect = newValue
            }
        )
    }
}
