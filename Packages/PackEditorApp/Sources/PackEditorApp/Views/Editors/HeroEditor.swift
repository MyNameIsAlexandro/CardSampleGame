import SwiftUI
import TwilightEngine
import PackEditorKit

struct HeroEditor: View {
    @Binding var hero: StandardHeroDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: hero.id)
                Picker("Class", selection: $hero.heroClass) {
                    ForEach(HeroClass.allCases, id: \.self) { heroClass in
                        Text(heroClass.rawValue.capitalized).tag(heroClass)
                    }
                }
                LocalizedTextField(label: "Name", text: $hero.name)
                    .validated(hero.name.displayString.isEmpty ? .error("Name is required") : nil)
                LocalizedTextField(label: "Description", text: $hero.description)
                TextField("Icon", text: $hero.icon)
                LabeledContent("Availability", value: availabilityDescription)
            }

            Section("Base Stats") {
                IntField(label: "Health", value: $hero.baseStats.health)
                    .validated(hero.baseStats.health <= 0 ? .error("Health must be positive") : nil)
                IntField(label: "Max Health", value: $hero.baseStats.maxHealth)
                    .validated(hero.baseStats.maxHealth < hero.baseStats.health ? .warning("Max health < health") : nil)
                IntField(label: "Strength", value: $hero.baseStats.strength)
                IntField(label: "Dexterity", value: $hero.baseStats.dexterity)
                IntField(label: "Constitution", value: $hero.baseStats.constitution)
                IntField(label: "Intelligence", value: $hero.baseStats.intelligence)
                IntField(label: "Wisdom", value: $hero.baseStats.wisdom)
                IntField(label: "Charisma", value: $hero.baseStats.charisma)
                IntField(label: "Faith", value: $hero.baseStats.faith)
                IntField(label: "Max Faith", value: $hero.baseStats.maxFaith)
                IntField(label: "Starting Balance", value: $hero.baseStats.startingBalance)
            }

            Section("Special Ability") {
                TextField("ID", text: $hero.specialAbility.id)
                LocalizedTextField(label: "Name", text: $hero.specialAbility.name)
                LocalizedTextField(label: "Description", text: $hero.specialAbility.description)
                TextField("Icon", text: $hero.specialAbility.icon)

                Picker("Type", selection: $hero.specialAbility.type) {
                    Text("passive").tag(HeroAbilityType.passive)
                    Text("active").tag(HeroAbilityType.active)
                    Text("reactive").tag(HeroAbilityType.reactive)
                    Text("ultimate").tag(HeroAbilityType.ultimate)
                }

                Picker("Trigger", selection: $hero.specialAbility.trigger) {
                    ForEach(AbilityTrigger.allCases, id: \.self) { trigger in
                        Text(trigger.rawValue).tag(trigger)
                    }
                }

                IntField(label: "Cooldown", value: $hero.specialAbility.cooldown)

                AbilityConditionEditor(
                    label: "Condition",
                    condition: $hero.specialAbility.condition
                )

                HeroAbilityEffectEditor(
                    label: "Effects",
                    effects: $hero.specialAbility.effects
                )

                AbilityCostEditor(
                    label: "Cost",
                    cost: $hero.specialAbility.cost
                )
            }

            Section("Starting Deck (\(hero.startingDeckCardIDs.count))") {
                StringListEditor(label: "Card IDs", items: $hero.startingDeckCardIDs)
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
