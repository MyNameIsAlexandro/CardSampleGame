import SwiftUI
import TwilightEngine

struct EnemyEditor: View {
    @Binding var enemy: EnemyDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: enemy.id)
                LabeledContent("Name (EN)", value: enemy.name.displayString)
                LabeledContent("Type", value: enemy.enemyType.rawValue)
                LabeledContent("Rarity", value: enemy.rarity.rawValue)
                LabeledContent("Difficulty", value: "\(enemy.difficulty)")
            }

            Section("Stats") {
                LabeledContent("Health", value: "\(enemy.health)")
                LabeledContent("Power", value: "\(enemy.power)")
                LabeledContent("Defense", value: "\(enemy.defense)")
                if let will = enemy.will {
                    LabeledContent("Will", value: "\(will)")
                }
                LabeledContent("Faith Reward", value: "\(enemy.faithReward)")
                LabeledContent("Balance Delta", value: "\(enemy.balanceDelta)")
            }

            Section("Loot") {
                if enemy.lootCardIds.isEmpty {
                    Text("No loot cards").foregroundStyle(.secondary)
                } else {
                    ForEach(enemy.lootCardIds, id: \.self) { cardId in
                        Text(cardId)
                    }
                }
            }

            Section("Resonance Behavior") {
                if let behaviors = enemy.resonanceBehavior, !behaviors.isEmpty {
                    ForEach(behaviors.keys.sorted(), id: \.self) { zone in
                        if let mod = behaviors[zone] {
                            HStack {
                                Text(zone).fontWeight(.medium).frame(width: 80, alignment: .leading)
                                Text("P:\(mod.powerDelta)").frame(width: 50)
                                Text("D:\(mod.defenseDelta)").frame(width: 50)
                                Text("H:\(mod.healthDelta)").frame(width: 50)
                                Text("W:\(mod.willDelta)").frame(width: 50)
                            }
                            .font(.caption)
                        }
                    }
                } else {
                    Text("No resonance modifiers").foregroundStyle(.secondary)
                }
            }

            Section("Abilities (\(enemy.abilities.count))") {
                if enemy.abilities.isEmpty {
                    Text("No abilities").foregroundStyle(.secondary)
                } else {
                    ForEach(enemy.abilities) { ability in
                        VStack(alignment: .leading) {
                            Text(ability.name.displayString).fontWeight(.medium)
                            Text(ability.description.displayString).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
