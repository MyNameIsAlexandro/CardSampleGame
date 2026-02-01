import SwiftUI
import TwilightEngine
import PackEditorKit

struct QuestEditor: View {
    @Binding var quest: QuestDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: quest.id)
                LocalizedTextField(label: "Title", text: $quest.title)
                    .validated(quest.title.displayString.isEmpty ? .error("Title is required") : nil)
                LocalizedTextField(label: "Description", text: $quest.description)
                TextField("Quest Kind", text: Binding(
                    get: { quest.questKind.rawValue },
                    set: { if let kind = QuestKind(rawValue: $0) { quest.questKind = kind } }
                ))
                Toggle("Auto Start", isOn: $quest.autoStart)
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
                ForEach(quest.objectives.indices, id: \.self) { index in
                    DisclosureGroup(quest.objectives[index].id) {
                        TextField("ID", text: $quest.objectives[index].id)
                        LocalizedTextField(label: "Description", text: $quest.objectives[index].description)
                        if let hint = quest.objectives[index].hint {
                            LabeledContent("Hint", value: hint.displayString)
                        }
                        LabeledContent("Completion Condition", value: completionConditionDescription(quest.objectives[index].completionCondition))
                        IntField(label: "Target Value", value: $quest.objectives[index].targetValue)
                        Toggle("Optional", isOn: $quest.objectives[index].isOptional)
                        TextField("Next Objective ID", text: Binding(
                            get: { quest.objectives[index].nextObjectiveId ?? "" },
                            set: { quest.objectives[index].nextObjectiveId = $0.isEmpty ? nil : $0 }
                        ))
                        StringListEditor(label: "Alternative Next IDs", items: $quest.objectives[index].alternativeNextIds)
                        Button(role: .destructive) {
                            quest.objectives.remove(at: index)
                        } label: {
                            Label("Remove Objective", systemImage: "minus.circle")
                        }
                    }
                }
                Button {
                    quest.objectives.append(ObjectiveDefinition(
                        id: "obj_new",
                        description: .inline(LocalizedString(en: "New Objective", ru: "Новая цель")),
                        completionCondition: .manual
                    ))
                } label: {
                    Label("Add Objective", systemImage: "plus.circle")
                }
            }

            Section("Completion Rewards") {
                IntField(label: "Balance Delta", value: $quest.completionRewards.balanceDelta)
                StringListEditor(label: "Set Flags", items: $quest.completionRewards.setFlags)
                StringListEditor(label: "Card IDs", items: $quest.completionRewards.cardIds)
                DictEditor(label: "Resource Change", dict: $quest.completionRewards.resourceChanges)
            }

            Section("Failure Penalties") {
                IntField(label: "Balance Delta", value: $quest.failurePenalties.balanceDelta)
                StringListEditor(label: "Set Flags", items: $quest.failurePenalties.setFlags)
                StringListEditor(label: "Card IDs", items: $quest.failurePenalties.cardIds)
                DictEditor(label: "Resource Change", dict: $quest.failurePenalties.resourceChanges)
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
