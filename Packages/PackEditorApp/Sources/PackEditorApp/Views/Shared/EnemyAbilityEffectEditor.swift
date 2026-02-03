import SwiftUI
import TwilightEngine

/// Editor for EnemyAbilityEffect enum
struct EnemyAbilityEffectEditor: View {
    @Binding var effect: EnemyAbilityEffect

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Effect Type", selection: effectTypeBinding) {
                Text("Bonus Damage").tag(EffectType.bonusDamage)
                Text("Regeneration").tag(EffectType.regeneration)
                Text("Armor").tag(EffectType.armor)
                Text("First Strike").tag(EffectType.firstStrike)
                Text("Spell Immune").tag(EffectType.spellImmune)
                Text("Apply Curse").tag(EffectType.applyCurse)
                Text("Custom").tag(EffectType.custom)
            }

            switch effect {
            case .bonusDamage(let value):
                IntField(label: "Damage", value: intBinding(value) { effect = .bonusDamage($0) })
            case .regeneration(let value):
                IntField(label: "Amount", value: intBinding(value) { effect = .regeneration($0) })
            case .armor(let value):
                IntField(label: "Reduction", value: intBinding(value) { effect = .armor($0) })
            case .firstStrike, .spellImmune:
                Text("No additional parameters")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            case .applyCurse(let curse):
                TextField("Curse Type", text: stringBinding(curse) { effect = .applyCurse($0) })
            case .custom(let id):
                TextField("Custom Effect ID", text: stringBinding(id) { effect = .custom($0) })
            }
        }
    }

    // MARK: - Effect Type Enum

    private enum EffectType {
        case bonusDamage, regeneration, armor, firstStrike, spellImmune, applyCurse, custom
    }

    private var effectTypeBinding: Binding<EffectType> {
        Binding(
            get: {
                switch effect {
                case .bonusDamage: return .bonusDamage
                case .regeneration: return .regeneration
                case .armor: return .armor
                case .firstStrike: return .firstStrike
                case .spellImmune: return .spellImmune
                case .applyCurse: return .applyCurse
                case .custom: return .custom
                }
            },
            set: { newType in
                switch newType {
                case .bonusDamage: effect = .bonusDamage(1)
                case .regeneration: effect = .regeneration(1)
                case .armor: effect = .armor(1)
                case .firstStrike: effect = .firstStrike
                case .spellImmune: effect = .spellImmune
                case .applyCurse: effect = .applyCurse("weakness")
                case .custom: effect = .custom("")
                }
            }
        )
    }

    // MARK: - Value Bindings

    private func intBinding(_ value: Int, setter: @escaping (Int) -> Void) -> Binding<Int> {
        Binding(
            get: { value },
            set: { setter($0) }
        )
    }

    private func stringBinding(_ value: String, setter: @escaping (String) -> Void) -> Binding<String> {
        Binding(
            get: { value },
            set: { setter($0) }
        )
    }
}
