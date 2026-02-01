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
                    ForEach(pattern.indices, id: \.self) { index in
                        HStack {
                            TextField("Type", text: Binding(
                                get: { enemy.pattern?[index].type.rawValue ?? "" },
                                set: { newVal in
                                    if let t = IntentType(rawValue: newVal) {
                                        enemy.pattern?[index].type = t
                                    }
                                }
                            ))
                            IntField(label: "Value", value: Binding(
                                get: { enemy.pattern?[index].value ?? 0 },
                                set: { enemy.pattern?[index].value = $0 }
                            ))
                            Button(role: .destructive) {
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
                ForEach(enemy.abilities.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("ID", text: $enemy.abilities[index].id)
                        LocalizedTextField(label: "Name", text: $enemy.abilities[index].name)
                        LocalizedTextField(label: "Description", text: $enemy.abilities[index].description)
                        LabeledContent("Effect", value: String(describing: enemy.abilities[index].effect))
                        Button(role: .destructive) {
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
                            id: "ability_new",
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
}
