/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Editors/BehaviorEditor.swift
/// Назначение: Содержит реализацию файла BehaviorEditor.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI
import TwilightEngine

struct BehaviorEditor: View {
    @Binding var behavior: BehaviorDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: behavior.id)
            }

            Section("Defaults") {
                TextField("Default Intent", text: Binding(
                    get: { behavior.defaultIntent ?? "" },
                    set: { behavior.defaultIntent = $0.isEmpty ? nil : $0 }
                ))
                TextField("Default Value", text: Binding(
                    get: { behavior.defaultValue ?? "" },
                    set: { behavior.defaultValue = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Rules") {
                ForEach(Array(behavior.rules.enumerated()), id: \.offset) { ruleIndex, rule in
                    DisclosureGroup("Rule \(ruleIndex + 1): \(rule.intentType)") {
                        TextField("Intent Type", text: ruleIntentTypeBinding(at: ruleIndex))
                        TextField("Value Formula", text: ruleValueFormulaBinding(at: ruleIndex))

                        Text("Conditions").font(.headline).padding(.top, 4)
                        ForEach(Array((behavior.rules[safe: ruleIndex]?.conditions ?? []).enumerated()), id: \.offset) { condIndex, _ in
                            HStack {
                                TextField("Type", text: conditionTypeBinding(ruleIndex: ruleIndex, condIndex: condIndex))
                                    .frame(maxWidth: 120)
                                TextField("Op", text: conditionOpBinding(ruleIndex: ruleIndex, condIndex: condIndex))
                                    .frame(maxWidth: 60)
                                TextField("Value", value: conditionValueBinding(ruleIndex: ruleIndex, condIndex: condIndex), format: .number)
                                    .frame(maxWidth: 80)
                                Button(role: .destructive) {
                                    guard ruleIndex < behavior.rules.count,
                                          condIndex < behavior.rules[ruleIndex].conditions.count else { return }
                                    behavior.rules[ruleIndex].conditions.remove(at: condIndex)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        Button("Add Condition") {
                            guard ruleIndex < behavior.rules.count else { return }
                            behavior.rules[ruleIndex].conditions.append(
                                BehaviorCondition(type: "health_pct", op: "<", value: 0.5)
                            )
                        }
                    }
                }

                Button("Add Rule") {
                    behavior.rules.append(
                        BehaviorRule(conditions: [], intentType: "attack", valueFormula: "1")
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Safe Rule Bindings

    private func ruleIntentTypeBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < behavior.rules.count else { return "" }
                return behavior.rules[index].intentType
            },
            set: { newValue in
                guard index < behavior.rules.count else { return }
                behavior.rules[index].intentType = newValue
            }
        )
    }

    private func ruleValueFormulaBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < behavior.rules.count else { return "" }
                return behavior.rules[index].valueFormula
            },
            set: { newValue in
                guard index < behavior.rules.count else { return }
                behavior.rules[index].valueFormula = newValue
            }
        )
    }

    // MARK: - Safe Condition Bindings

    private func conditionTypeBinding(ruleIndex: Int, condIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard ruleIndex < behavior.rules.count,
                      condIndex < behavior.rules[ruleIndex].conditions.count else { return "" }
                return behavior.rules[ruleIndex].conditions[condIndex].type
            },
            set: { newValue in
                guard ruleIndex < behavior.rules.count,
                      condIndex < behavior.rules[ruleIndex].conditions.count else { return }
                behavior.rules[ruleIndex].conditions[condIndex].type = newValue
            }
        )
    }

    private func conditionOpBinding(ruleIndex: Int, condIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard ruleIndex < behavior.rules.count,
                      condIndex < behavior.rules[ruleIndex].conditions.count else { return "" }
                return behavior.rules[ruleIndex].conditions[condIndex].op
            },
            set: { newValue in
                guard ruleIndex < behavior.rules.count,
                      condIndex < behavior.rules[ruleIndex].conditions.count else { return }
                behavior.rules[ruleIndex].conditions[condIndex].op = newValue
            }
        )
    }

    private func conditionValueBinding(ruleIndex: Int, condIndex: Int) -> Binding<Double> {
        Binding(
            get: {
                guard ruleIndex < behavior.rules.count,
                      condIndex < behavior.rules[ruleIndex].conditions.count else { return 0.0 }
                return behavior.rules[ruleIndex].conditions[condIndex].value
            },
            set: { newValue in
                guard ruleIndex < behavior.rules.count,
                      condIndex < behavior.rules[ruleIndex].conditions.count else { return }
                behavior.rules[ruleIndex].conditions[condIndex].value = newValue
            }
        )
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
