/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Editors/QuestEditor.swift
/// Назначение: Содержит реализацию файла QuestEditor.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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
                ForEach(Array(quest.objectives.enumerated()), id: \.element.id) { index, objective in
                    DisclosureGroup(objective.id) {
                        TextField("ID", text: objectiveBinding(at: index, keyPath: \.id))
                        LocalizedTextField(label: "Description", text: objectiveLocalizedBinding(at: index, keyPath: \.description))
                        if let hint = objective.hint {
                            LabeledContent("Hint", value: hint.displayString)
                        }
                        LabeledContent("Completion Condition", value: completionConditionDescription(objective.completionCondition))
                        IntField(label: "Target Value", value: objectiveIntBinding(at: index, keyPath: \.targetValue))
                        Toggle("Optional", isOn: objectiveBoolBinding(at: index, keyPath: \.isOptional))
                        TextField("Next Objective ID", text: Binding(
                            get: {
                                guard index < quest.objectives.count else { return "" }
                                return quest.objectives[index].nextObjectiveId ?? ""
                            },
                            set: {
                                guard index < quest.objectives.count else { return }
                                quest.objectives[index].nextObjectiveId = $0.isEmpty ? nil : $0
                            }
                        ))
                        StringListEditor(label: "Alternative Next IDs", items: objectiveArrayBinding(at: index, keyPath: \.alternativeNextIds))
                        Button(role: .destructive) {
                            guard index < quest.objectives.count else { return }
                            quest.objectives.remove(at: index)
                        } label: {
                            Label("Remove Objective", systemImage: "minus.circle")
                        }
                    }
                }
                Button {
                    quest.objectives.append(ObjectiveDefinition(
                        id: "obj_new_\(UUID().uuidString.prefix(4))",
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

    // MARK: - Safe Objective Bindings

    private func objectiveBinding(at index: Int, keyPath: WritableKeyPath<ObjectiveDefinition, String>) -> Binding<String> {
        Binding(
            get: {
                guard index < quest.objectives.count else { return "" }
                return quest.objectives[index][keyPath: keyPath]
            },
            set: { newValue in
                guard index < quest.objectives.count else { return }
                quest.objectives[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func objectiveLocalizedBinding(at index: Int, keyPath: WritableKeyPath<ObjectiveDefinition, LocalizableText>) -> Binding<LocalizableText> {
        Binding(
            get: {
                guard index < quest.objectives.count else { return .inline(LocalizedString(en: "", ru: "")) }
                return quest.objectives[index][keyPath: keyPath]
            },
            set: { newValue in
                guard index < quest.objectives.count else { return }
                quest.objectives[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func objectiveIntBinding(at index: Int, keyPath: WritableKeyPath<ObjectiveDefinition, Int>) -> Binding<Int> {
        Binding(
            get: {
                guard index < quest.objectives.count else { return 0 }
                return quest.objectives[index][keyPath: keyPath]
            },
            set: { newValue in
                guard index < quest.objectives.count else { return }
                quest.objectives[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func objectiveBoolBinding(at index: Int, keyPath: WritableKeyPath<ObjectiveDefinition, Bool>) -> Binding<Bool> {
        Binding(
            get: {
                guard index < quest.objectives.count else { return false }
                return quest.objectives[index][keyPath: keyPath]
            },
            set: { newValue in
                guard index < quest.objectives.count else { return }
                quest.objectives[index][keyPath: keyPath] = newValue
            }
        )
    }

    private func objectiveArrayBinding(at index: Int, keyPath: WritableKeyPath<ObjectiveDefinition, [String]>) -> Binding<[String]> {
        Binding(
            get: {
                guard index < quest.objectives.count else { return [] }
                return quest.objectives[index][keyPath: keyPath]
            },
            set: { newValue in
                guard index < quest.objectives.count else { return }
                quest.objectives[index][keyPath: keyPath] = newValue
            }
        )
    }
}
