import SwiftUI
import TwilightEngine
import PackEditorKit

struct EnemyEditor: View {
    @Binding var enemy: EnemyDefinition

    private var enemyTypeBinding: Binding<String> {
        Binding<String>(
            get: { enemy.enemyType.rawValue },
            set: { if let t = EnemyType(rawValue: $0) { enemy.enemyType = t } }
        )
    }

    private var rarityBinding: Binding<String> {
        Binding<String>(
            get: { enemy.rarity.rawValue },
            set: { if let r = CardRarity(rawValue: $0) { enemy.rarity = r } }
        )
    }

    private var willBinding: Binding<Int> {
        Binding<Int>(
            get: { enemy.will ?? 0 },
            set: { enemy.will = $0 == 0 ? nil : $0 }
        )
    }

    // MARK: - Resonance Helpers

    private var resonanceKeys: [String] {
        (enemy.resonanceBehavior ?? [:]).keys.sorted()
    }

    private func modifierBinding(for key: String) -> Binding<EnemyModifier> {
        Binding(
            get: { enemy.resonanceBehavior?[key] ?? EnemyModifier() },
            set: { enemy.resonanceBehavior?[key] = $0 }
        )
    }

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: enemy.id)
                LocalizedTextField(label: "Name", text: $enemy.name)
                    .validated(enemy.name.displayString.isEmpty ? .error("Name is required") : nil)
                LocalizedTextField(label: "Description", text: $enemy.description)
                TextField("Enemy Type", text: enemyTypeBinding)
                TextField("Rarity", text: rarityBinding)
                IntField(label: "Difficulty", value: $enemy.difficulty)
            }

            Section("Stats") {
                IntField(label: "Health", value: $enemy.health)
                    .validated(enemy.health <= 0 ? .error("Health must be positive") : nil)
                IntField(label: "Power", value: $enemy.power)
                IntField(label: "Defense", value: $enemy.defense)
                IntField(label: "Will", value: willBinding)
                IntField(label: "Faith Reward", value: $enemy.faithReward)
                IntField(label: "Balance Delta", value: $enemy.balanceDelta)
            }

            Section("Loot") {
                StringListEditor(label: "Loot Card IDs", items: $enemy.lootCardIds)
            }

            Section("Resonance Behavior") {
                if enemy.resonanceBehavior == nil {
                    Text("No resonance modifiers").foregroundStyle(.secondary)
                    Button("Add Zone") {
                        enemy.resonanceBehavior = [:]
                    }
                } else {
                    ForEach(resonanceKeys, id: \.self) { zone in
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledContent("Zone", value: zone)
                            IntField(label: "Power Delta", value: Binding(
                                get: { modifierBinding(for: zone).wrappedValue.powerDelta },
                                set: { modifierBinding(for: zone).wrappedValue.powerDelta = $0 }
                            ))
                            IntField(label: "Defense Delta", value: Binding(
                                get: { modifierBinding(for: zone).wrappedValue.defenseDelta },
                                set: { modifierBinding(for: zone).wrappedValue.defenseDelta = $0 }
                            ))
                            IntField(label: "Health Delta", value: Binding(
                                get: { modifierBinding(for: zone).wrappedValue.healthDelta },
                                set: { modifierBinding(for: zone).wrappedValue.healthDelta = $0 }
                            ))
                            IntField(label: "Will Delta", value: Binding(
                                get: { modifierBinding(for: zone).wrappedValue.willDelta },
                                set: { modifierBinding(for: zone).wrappedValue.willDelta = $0 }
                            ))
                            Button(role: .destructive) {
                                enemy.resonanceBehavior?.removeValue(forKey: zone)
                            } label: {
                                Label("Remove Zone", systemImage: "minus.circle")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Button("Add Zone") {
                        enemy.resonanceBehavior?["newZone"] = EnemyModifier()
                    }
                }
            }

            Section("Behavior Pattern (\(enemy.pattern?.count ?? 0) steps)") {
                if let pattern = enemy.pattern {
                    ForEach(Array(pattern.enumerated()), id: \.offset) { index, _ in
                        HStack {
                            TextField("Type", text: patternTypeBinding(at: index))
                            IntField(label: "Value", value: patternValueBinding(at: index))
                            Button(role: .destructive) {
                                guard enemy.pattern != nil, index < (enemy.pattern?.count ?? 0) else { return }
                                enemy.pattern?.remove(at: index)
                                if enemy.pattern?.isEmpty == true { enemy.pattern = nil }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                        }
                    }
                    Button {
                        enemy.pattern?.append(EnemyPatternStep(type: .attack, value: 0))
                    } label: {
                        Label("Add Step", systemImage: "plus.circle")
                    }
                } else {
                    Text("No pattern defined").foregroundStyle(.secondary)
                    Button("Add Pattern") {
                        enemy.pattern = [EnemyPatternStep(type: .attack, value: 4)]
                    }
                }
            }

            Section("Abilities (\(enemy.abilities.count))") {
                ForEach(Array(enemy.abilities.enumerated()), id: \.element.id) { index, ability in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("ID", text: abilityIdBinding(at: index))
                        LocalizedTextField(label: "Name", text: abilityNameBinding(at: index))
                        LocalizedTextField(label: "Description", text: abilityDescBinding(at: index))
                        LabeledContent("Effect", value: String(describing: ability.effect))
                        Button(role: .destructive) {
                            guard index < enemy.abilities.count else { return }
                            enemy.abilities.remove(at: index)
                        } label: {
                            Label("Remove Ability", systemImage: "minus.circle")
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button {
                    enemy.abilities.append(
                        EnemyAbility(
                            id: "ability_new_\(UUID().uuidString.prefix(4))",
                            name: .inline(LocalizedString(en: "New Ability", ru: "Новая способность")),
                            description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                            effect: .bonusDamage(0)
                        )
                    )
                } label: {
                    Label("Add Ability", systemImage: "plus.circle")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Safe Pattern Bindings

    private func patternTypeBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let p = enemy.pattern, index < p.count else { return "" }
                return p[index].type.rawValue
            },
            set: { newVal in
                guard enemy.pattern != nil, index < (enemy.pattern?.count ?? 0) else { return }
                if let t = IntentType(rawValue: newVal) {
                    enemy.pattern?[index].type = t
                }
            }
        )
    }

    private func patternValueBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard let p = enemy.pattern, index < p.count else { return 0 }
                return p[index].value
            },
            set: { newValue in
                guard enemy.pattern != nil, index < (enemy.pattern?.count ?? 0) else { return }
                enemy.pattern?[index].value = newValue
            }
        )
    }

    // MARK: - Safe Ability Bindings

    private func abilityIdBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < enemy.abilities.count else { return "" }
                return enemy.abilities[index].id
            },
            set: { newValue in
                guard index < enemy.abilities.count else { return }
                enemy.abilities[index].id = newValue
            }
        )
    }

    private func abilityNameBinding(at index: Int) -> Binding<LocalizableText> {
        Binding(
            get: {
                guard index < enemy.abilities.count else { return .inline(LocalizedString(en: "", ru: "")) }
                return enemy.abilities[index].name
            },
            set: { newValue in
                guard index < enemy.abilities.count else { return }
                enemy.abilities[index].name = newValue
            }
        )
    }

    private func abilityDescBinding(at index: Int) -> Binding<LocalizableText> {
        Binding(
            get: {
                guard index < enemy.abilities.count else { return .inline(LocalizedString(en: "", ru: "")) }
                return enemy.abilities[index].description
            },
            set: { newValue in
                guard index < enemy.abilities.count else { return }
                enemy.abilities[index].description = newValue
            }
        )
    }
}
