import SwiftUI
import TwilightEngine
import PackEditorKit

struct QuestEditor: View {
    @Binding var quest: QuestDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: quest.id)
                LabeledContent("Title", value: quest.title.displayString)
                LabeledContent("Description", value: quest.description.displayString)
                LabeledContent("Quest Kind", value: quest.questKind.rawValue)
                LabeledContent("Auto Start", value: quest.autoStart ? "Yes" : "No")
            }

            Section("Availability") {
                LabeledContent("Required Flags", value: quest.availability.requiredFlags.isEmpty ? "None" : quest.availability.requiredFlags.joined(separator: ", "))
                LabeledContent("Forbidden Flags", value: quest.availability.forbiddenFlags.isEmpty ? "None" : quest.availability.forbiddenFlags.joined(separator: ", "))
                if let minPressure = quest.availability.minPressure {
                    LabeledContent("Min Pressure", value: "\(minPressure)")
                }
                if let maxPressure = quest.availability.maxPressure {
                    LabeledContent("Max Pressure", value: "\(maxPressure)")
                }
            }

            Section("Objectives (\(quest.objectives.count))") {
                if quest.objectives.isEmpty {
                    Text("No objectives").foregroundStyle(.secondary)
                } else {
                    ForEach(quest.objectives, id: \.id) { objective in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("ID", value: objective.id)
                            LabeledContent("Description", value: objective.description.displayString)
                            LabeledContent("Completion Condition", value: completionConditionDescription(objective.completionCondition))
                            if objective.targetValue > 0 {
                                LabeledContent("Target Value", value: "\(objective.targetValue)")
                            }
                            LabeledContent("Optional", value: objective.isOptional ? "Yes" : "No")
                            if let nextId = objective.nextObjectiveId {
                                LabeledContent("Next Objective", value: nextId)
                            }
                            if !objective.alternativeNextIds.isEmpty {
                                LabeledContent("Alternatives", value: objective.alternativeNextIds.joined(separator: ", "))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Completion Rewards") {
                if quest.completionRewards.resourceChanges.isEmpty &&
                   quest.completionRewards.setFlags.isEmpty &&
                   quest.completionRewards.cardIds.isEmpty &&
                   quest.completionRewards.balanceDelta == 0 {
                    Text("No rewards").foregroundStyle(.secondary)
                } else {
                    if !quest.completionRewards.resourceChanges.isEmpty {
                        LabeledContent("Resource Changes", value: resourceChangesDescription(quest.completionRewards.resourceChanges))
                    }
                    if !quest.completionRewards.setFlags.isEmpty {
                        LabeledContent("Set Flags", value: quest.completionRewards.setFlags.joined(separator: ", "))
                    }
                    if !quest.completionRewards.cardIds.isEmpty {
                        LabeledContent("Card IDs", value: quest.completionRewards.cardIds.joined(separator: ", "))
                    }
                    if quest.completionRewards.balanceDelta != 0 {
                        LabeledContent("Balance Delta", value: "\(quest.completionRewards.balanceDelta)")
                    }
                }
            }

            Section("Failure Penalties") {
                if quest.failurePenalties.resourceChanges.isEmpty &&
                   quest.failurePenalties.setFlags.isEmpty &&
                   quest.failurePenalties.cardIds.isEmpty &&
                   quest.failurePenalties.balanceDelta == 0 {
                    Text("No penalties").foregroundStyle(.secondary)
                } else {
                    if !quest.failurePenalties.resourceChanges.isEmpty {
                        LabeledContent("Resource Changes", value: resourceChangesDescription(quest.failurePenalties.resourceChanges))
                    }
                    if !quest.failurePenalties.setFlags.isEmpty {
                        LabeledContent("Set Flags", value: quest.failurePenalties.setFlags.joined(separator: ", "))
                    }
                    if !quest.failurePenalties.cardIds.isEmpty {
                        LabeledContent("Card IDs", value: quest.failurePenalties.cardIds.joined(separator: ", "))
                    }
                    if quest.failurePenalties.balanceDelta != 0 {
                        LabeledContent("Balance Delta", value: "\(quest.failurePenalties.balanceDelta)")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func completionConditionDescription(_ condition: CompletionCondition) -> String {
        switch condition {
        case .flagSet(let flag):
            return "Flag Set: \(flag)"
        case .visitRegion(let region):
            return "Visit Region: \(region)"
        case .eventCompleted(let event):
            return "Event Completed: \(event)"
        case .choiceMade(let eventId, let choiceId):
            return "Choice Made: \(eventId) → \(choiceId)"
        case .resourceThreshold(let resourceId, let minValue):
            return "Resource Threshold: \(resourceId) ≥ \(minValue)"
        case .defeatEnemy(let enemy):
            return "Defeat Enemy: \(enemy)"
        case .collectItem(let item):
            return "Collect Item: \(item)"
        case .manual:
            return "Manual"
        }
    }

    private func resourceChangesDescription(_ changes: [String: Int]) -> String {
        changes.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }
}
