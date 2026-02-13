/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Shared/AbilityConditionEditor.swift
/// Назначение: Содержит реализацию файла AbilityConditionEditor.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI
import TwilightEngine

/// Editor for optional AbilityCondition
struct AbilityConditionEditor: View {
    let label: String
    @Binding var condition: AbilityCondition?

    var body: some View {
        DisclosureGroup(label) {
            Toggle("Has Condition", isOn: hasConditionBinding)

            if condition != nil {
                Picker("Type", selection: conditionTypeBinding) {
                    ForEach(AbilityConditionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                if needsValue {
                    IntField(label: "Value", value: conditionValueBinding)
                }

                if needsStringValue {
                    TextField("String Value", text: conditionStringBinding)
                }
            }
        }
    }

    private var hasConditionBinding: Binding<Bool> {
        Binding(
            get: { condition != nil },
            set: { enabled in
                if enabled {
                    condition = AbilityCondition(type: .hpBelowPercent, value: 50)
                } else {
                    condition = nil
                }
            }
        )
    }

    private var conditionTypeBinding: Binding<AbilityConditionType> {
        Binding(
            get: { condition?.type ?? .hpBelowPercent },
            set: { condition?.type = $0 }
        )
    }

    private var conditionValueBinding: Binding<Int> {
        Binding(
            get: { condition?.value ?? 0 },
            set: { condition?.value = $0 }
        )
    }

    private var conditionStringBinding: Binding<String> {
        Binding(
            get: { condition?.stringValue ?? "" },
            set: { condition?.stringValue = $0.isEmpty ? nil : $0 }
        )
    }

    private var needsValue: Bool {
        guard let type = condition?.type else { return false }
        switch type {
        case .hpBelowPercent, .hpAbovePercent, .balanceAbove, .balanceBelow:
            return true
        default:
            return false
        }
    }

    private var needsStringValue: Bool {
        guard let type = condition?.type else { return false }
        switch type {
        case .hasCurse, .hasCardInHand:
            return true
        default:
            return false
        }
    }
}
