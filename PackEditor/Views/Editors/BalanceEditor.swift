import SwiftUI
import TwilightEngine
import PackEditorKit

struct BalanceEditor: View {
    @Binding var config: BalanceConfiguration

    var body: some View {
        Form {
            Section("Resources") {
                LabeledContent("Starting Health", value: "\(config.resources.startingHealth)")
                LabeledContent("Max Health", value: "\(config.resources.maxHealth)")
                LabeledContent("Starting Faith", value: "\(config.resources.startingFaith)")
                LabeledContent("Max Faith", value: "\(config.resources.maxFaith)")
                LabeledContent("Starting Supplies", value: "\(config.resources.startingSupplies)")
                LabeledContent("Max Supplies", value: "\(config.resources.maxSupplies)")
                LabeledContent("Starting Gold", value: "\(config.resources.startingGold)")
                LabeledContent("Max Gold", value: "\(config.resources.maxGold)")
                if let restHeal = config.resources.restHealAmount {
                    LabeledContent("Rest Heal Amount", value: "\(restHeal)")
                }
                if let startingBalance = config.resources.startingBalance {
                    LabeledContent("Starting Balance", value: "\(startingBalance)")
                }
            }

            Section("Pressure") {
                LabeledContent("Starting Pressure", value: "\(config.pressure.startingPressure)")
                LabeledContent("Min Pressure", value: "\(config.pressure.minPressure)")
                LabeledContent("Max Pressure", value: "\(config.pressure.maxPressure)")
                LabeledContent("Pressure Per Turn", value: "\(config.pressure.pressurePerTurn)")
                if let interval = config.pressure.tensionTickInterval {
                    LabeledContent("Tension Tick Interval", value: "\(interval)")
                }
                if let interval = config.pressure.escalationInterval {
                    LabeledContent("Escalation Interval", value: "\(interval)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Thresholds").fontWeight(.semibold)
                    HStack {
                        Text("Warning")
                        Spacer()
                        Text("\(config.pressure.thresholds.warning)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Critical")
                        Spacer()
                        Text("\(config.pressure.thresholds.critical)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Catastrophic")
                        Spacer()
                        Text("\(config.pressure.thresholds.catastrophic)").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Degradation").fontWeight(.semibold)
                    HStack {
                        Text("Warning Chance")
                        Spacer()
                        Text(String(format: "%.1f%%", config.pressure.degradation.warningChance * 100)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Critical Chance")
                        Spacer()
                        Text(String(format: "%.1f%%", config.pressure.degradation.criticalChance * 100)).foregroundStyle(.secondary)
                    }
                    if let catastrophicChance = config.pressure.degradation.catastrophicChance {
                        HStack {
                            Text("Catastrophic Chance")
                            Spacer()
                            Text(String(format: "%.1f%%", catastrophicChance * 100)).foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Anchor Decay Chance")
                        Spacer()
                        Text(String(format: "%.1f%%", config.pressure.degradation.anchorDecayChance * 100)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if let combat = config.combat {
                Section("Combat") {
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

            Section("Time") {
                LabeledContent("Starting Time", value: "\(config.time.startingTime)")
                if let maxDays = config.time.maxDays {
                    LabeledContent("Max Days", value: "\(maxDays)")
                }
                LabeledContent("Travel Cost", value: "\(config.time.travelCost)")
                LabeledContent("Explore Cost", value: "\(config.time.exploreCost)")
                LabeledContent("Rest Cost", value: "\(config.time.restCost)")
                if let strengthenCost = config.time.strengthenAnchorCost {
                    LabeledContent("Strengthen Anchor Cost", value: "\(strengthenCost)")
                }
                if let instantCost = config.time.instantCost {
                    LabeledContent("Instant Cost", value: "\(instantCost)")
                }
            }

            Section("Anchor") {
                LabeledContent("Max Integrity", value: "\(config.anchor.maxIntegrity)")
                LabeledContent("Strengthen Amount", value: "\(config.anchor.strengthenAmount)")
                LabeledContent("Strengthen Cost", value: "\(config.anchor.strengthenCost)")
                LabeledContent("Stable Threshold", value: "\(config.anchor.stableThreshold)")
                LabeledContent("Breach Threshold", value: "\(config.anchor.breachThreshold)")
                LabeledContent("Decay Per Turn", value: "\(config.anchor.decayPerTurn)")
            }

            Section("End Conditions") {
                LabeledContent("Death Health", value: "\(config.endConditions.deathHealth)")
                if let pressureLoss = config.endConditions.pressureLoss {
                    LabeledContent("Pressure Loss", value: "\(pressureLoss)")
                }
                if let breachLoss = config.endConditions.breachLoss {
                    LabeledContent("Breach Loss", value: "\(breachLoss)")
                }
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

            if let balanceSystem = config.balanceSystem {
                Section("Balance System") {
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
}
