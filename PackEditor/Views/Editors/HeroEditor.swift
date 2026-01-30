import SwiftUI
import TwilightEngine

struct HeroEditor: View {
    @Binding var hero: StandardHeroDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: hero.id)
                LabeledContent("Name", value: hero.name.displayString)
                LabeledContent("Description", value: hero.description.displayString)
                LabeledContent("Icon", value: hero.icon)
                LabeledContent("Availability", value: availabilityDescription)
            }

            Section("Base Stats") {
                LabeledContent("Health", value: "\(hero.baseStats.health)")
                LabeledContent("Max Health", value: "\(hero.baseStats.maxHealth)")
                LabeledContent("Strength", value: "\(hero.baseStats.strength)")
                LabeledContent("Dexterity", value: "\(hero.baseStats.dexterity)")
                LabeledContent("Constitution", value: "\(hero.baseStats.constitution)")
                LabeledContent("Intelligence", value: "\(hero.baseStats.intelligence)")
                LabeledContent("Wisdom", value: "\(hero.baseStats.wisdom)")
                LabeledContent("Charisma", value: "\(hero.baseStats.charisma)")
                LabeledContent("Faith", value: "\(hero.baseStats.faith)")
                LabeledContent("Max Faith", value: "\(hero.baseStats.maxFaith)")
                LabeledContent("Starting Balance", value: "\(hero.baseStats.startingBalance)")
            }

            Section("Special Ability") {
                LabeledContent("ID", value: hero.specialAbility.id)
                LabeledContent("Name", value: hero.specialAbility.name.displayString)
                LabeledContent("Description", value: hero.specialAbility.description.displayString)
                LabeledContent("Icon", value: hero.specialAbility.icon)
                LabeledContent("Type", value: hero.specialAbility.type.rawValue)
                LabeledContent("Trigger", value: hero.specialAbility.trigger.rawValue)
                LabeledContent("Cooldown", value: "\(hero.specialAbility.cooldown)")
            }

            Section("Starting Deck (\(hero.startingDeckCardIDs.count))") {
                if hero.startingDeckCardIDs.isEmpty {
                    Text("No cards").foregroundStyle(.secondary)
                } else {
                    ForEach(hero.startingDeckCardIDs, id: \.self) { cardId in
                        Text(cardId)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var availabilityDescription: String {
        switch hero.availability {
        case .alwaysAvailable:
            return "Always Available"
        case .requiresUnlock(let condition):
            return "Requires Unlock: \(condition)"
        case .dlc(let packID):
            return "DLC: \(packID)"
        }
    }
}
