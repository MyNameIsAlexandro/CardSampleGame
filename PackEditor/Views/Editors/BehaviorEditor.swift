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
                ForEach(behavior.rules.indices, id: \.self) { ruleIndex in
                    DisclosureGroup("Rule \(ruleIndex + 1): \(behavior.rules[ruleIndex].intentType)") {
                        TextField("Intent Type", text: $behavior.rules[ruleIndex].intentType)
                        TextField("Value Formula", text: $behavior.rules[ruleIndex].valueFormula)

                        Text("Conditions").font(.headline).padding(.top, 4)
                        ForEach(behavior.rules[ruleIndex].conditions.indices, id: \.self) { condIndex in
                            HStack {
                                TextField("Type", text: $behavior.rules[ruleIndex].conditions[condIndex].type)
                                    .frame(maxWidth: 120)
                                TextField("Op", text: $behavior.rules[ruleIndex].conditions[condIndex].op)
                                    .frame(maxWidth: 60)
                                TextField("Value", value: $behavior.rules[ruleIndex].conditions[condIndex].value, format: .number)
                                    .frame(maxWidth: 80)
                                Button(role: .destructive) {
                                    behavior.rules[ruleIndex].conditions.remove(at: condIndex)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        Button("Add Condition") {
                            behavior.rules[ruleIndex].conditions.append(
                                BehaviorCondition(type: "health_pct", op: "<", value: 0.5)
                            )
                        }
                    }
                }
                .onDelete { indexSet in
                    behavior.rules.remove(atOffsets: indexSet)
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
}
