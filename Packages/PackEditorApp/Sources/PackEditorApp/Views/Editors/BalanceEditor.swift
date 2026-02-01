import SwiftUI
import TwilightEngine
import PackEditorKit

struct BalanceEditor: View {
    @Binding var config: BalanceConfiguration

    var body: some View {
        Form {
            // MARK: - Resources
            Section("Resources") {
                IntField(label: "Starting Health", value: $config.resources.startingHealth)
                IntField(label: "Max Health", value: $config.resources.maxHealth)
                IntField(label: "Starting Faith", value: $config.resources.startingFaith)
                IntField(label: "Max Faith", value: $config.resources.maxFaith)
                IntField(label: "Starting Supplies", value: $config.resources.startingSupplies)
                IntField(label: "Max Supplies", value: $config.resources.maxSupplies)
                IntField(label: "Starting Gold", value: $config.resources.startingGold)
                IntField(label: "Max Gold", value: $config.resources.maxGold)
                IntField(label: "Rest Heal Amount", value: optionalIntBinding($config.resources.restHealAmount))
                IntField(label: "Starting Balance", value: optionalIntBinding($config.resources.startingBalance))
            }

            // MARK: - Pressure
            Section("Pressure") {
                IntField(label: "Starting Pressure", value: $config.pressure.startingPressure)
                IntField(label: "Min Pressure", value: $config.pressure.minPressure)
                IntField(label: "Max Pressure", value: $config.pressure.maxPressure)
                IntField(label: "Pressure Per Turn", value: $config.pressure.pressurePerTurn)
                IntField(label: "Tension Tick Interval", value: optionalIntBinding($config.pressure.tensionTickInterval))
                IntField(label: "Escalation Interval", value: optionalIntBinding($config.pressure.escalationInterval))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Thresholds").fontWeight(.semibold)
                    IntField(label: "Warning", value: $config.pressure.thresholds.warning)
                    IntField(label: "Critical", value: $config.pressure.thresholds.critical)
                    IntField(label: "Catastrophic", value: $config.pressure.thresholds.catastrophic)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Degradation").fontWeight(.semibold)
                    TextField("Warning Chance", value: $config.pressure.degradation.warningChance, format: .number)
                    TextField("Critical Chance", value: $config.pressure.degradation.criticalChance, format: .number)
                    TextField("Catastrophic Chance", value: optionalDoubleBinding($config.pressure.degradation.catastrophicChance), format: .number)
                    TextField("Anchor Decay Chance", value: $config.pressure.degradation.anchorDecayChance, format: .number)
                }
                .padding(.vertical, 4)
            }

            // MARK: - Combat (read-only, optional struct)
            if let combat = config.combat {
                Section("Combat (read-only)") {
                    LabeledContent("Base Damage", value: "\(combat.baseDamage)")
                    LabeledContent("Power Modifier", value: String(format: "%.2f", combat.powerModifier))
                    LabeledContent("Defense Reduction", value: String(format: "%.2f", combat.defenseReduction))
                    if let diceMax = combat.diceMax {
                        LabeledContent("Dice Max", value: "\(diceMax)")
                    }
                    if let actionsPerTurn = combat.actionsPerTurn {
                        LabeledContent("Actions Per Turn", value: "\(actionsPerTurn)")
                    }
                    if let cardsPerTurn = combat.cardsDrawnPerTurn {
                        LabeledContent("Cards Drawn Per Turn", value: "\(cardsPerTurn)")
                    }
                    if let maxHandSize = combat.maxHandSize {
                        LabeledContent("Max Hand Size", value: "\(maxHandSize)")
                    }
                    if let escalationShift = combat.escalationResonanceShift {
                        LabeledContent("Escalation Resonance Shift", value: String(format: "%.1f", escalationShift))
                    }
                    if let surpriseBonus = combat.escalationSurpriseBonus {
                        LabeledContent("Escalation Surprise Bonus", value: "\(surpriseBonus)")
                    }
                    if let rageShield = combat.deEscalationRageShield {
                        LabeledContent("De-escalation Rage Shield", value: "\(rageShield)")
                    }
                    if let matchMult = combat.matchMultiplier {
                        LabeledContent("Match Multiplier", value: String(format: "%.2f", matchMult))
                    }
                }
            }

            // MARK: - Time
            Section("Time") {
                IntField(label: "Starting Time", value: $config.time.startingTime)
                IntField(label: "Max Days", value: optionalIntBinding($config.time.maxDays))
                IntField(label: "Travel Cost", value: $config.time.travelCost)
                IntField(label: "Explore Cost", value: $config.time.exploreCost)
                IntField(label: "Rest Cost", value: $config.time.restCost)
                IntField(label: "Strengthen Anchor Cost", value: optionalIntBinding($config.time.strengthenAnchorCost))
                IntField(label: "Instant Cost", value: optionalIntBinding($config.time.instantCost))
            }

            // MARK: - Anchor
            Section("Anchor") {
                IntField(label: "Max Integrity", value: $config.anchor.maxIntegrity)
                IntField(label: "Strengthen Amount", value: $config.anchor.strengthenAmount)
                IntField(label: "Strengthen Cost", value: $config.anchor.strengthenCost)
                IntField(label: "Stable Threshold", value: $config.anchor.stableThreshold)
                IntField(label: "Breach Threshold", value: $config.anchor.breachThreshold)
                IntField(label: "Decay Per Turn", value: $config.anchor.decayPerTurn)
            }

            // MARK: - End Conditions
            Section("End Conditions") {
                IntField(label: "Death Health", value: $config.endConditions.deathHealth)
                IntField(label: "Pressure Loss", value: optionalIntBinding($config.endConditions.pressureLoss))
                IntField(label: "Breach Loss", value: optionalIntBinding($config.endConditions.breachLoss))
                if !config.endConditions.victoryQuests.isEmpty {
                    LabeledContent("Victory Quests", value: config.endConditions.victoryQuests.joined(separator: ", "))
                }
                if let mainQuestFlag = config.endConditions.mainQuestCompleteFlag {
                    LabeledContent("Main Quest Complete Flag", value: mainQuestFlag)
                }
                if let criticalAnchorFlag = config.endConditions.criticalAnchorDestroyedFlag {
                    LabeledContent("Critical Anchor Destroyed Flag", value: criticalAnchorFlag)
                }
            }

            // MARK: - Balance System (read-only, optional struct)
            if let balanceSystem = config.balanceSystem {
                Section("Balance System (read-only)") {
                    LabeledContent("Min", value: "\(balanceSystem.min)")
                    LabeledContent("Max", value: "\(balanceSystem.max)")
                    LabeledContent("Initial", value: "\(balanceSystem.initial)")
                    LabeledContent("Light Threshold", value: "\(balanceSystem.lightThreshold)")
                    LabeledContent("Dark Threshold", value: "\(balanceSystem.darkThreshold)")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helper Bindings

    /// Converts an optional Int binding to a non-optional Int binding (nil ↔ 0).
    private func optionalIntBinding(_ source: Binding<Int?>) -> Binding<Int> {
        Binding<Int>(
            get: { source.wrappedValue ?? 0 },
            set: { newValue in source.wrappedValue = newValue == 0 ? nil : newValue }
        )
    }

    /// Converts an optional Double binding to a non-optional Double binding (nil ↔ 0.0).
    private func optionalDoubleBinding(_ source: Binding<Double?>) -> Binding<Double> {
        Binding<Double>(
            get: { source.wrappedValue ?? 0.0 },
            set: { newValue in source.wrappedValue = newValue == 0.0 ? nil : newValue }
        )
    }
}
