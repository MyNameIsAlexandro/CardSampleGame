/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Shared/AbilityCostEditor.swift
/// Назначение: Содержит реализацию файла AbilityCostEditor.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI
import TwilightEngine

/// Editor for optional AbilityCost
struct AbilityCostEditor: View {
    let label: String
    @Binding var cost: AbilityCost?

    var body: some View {
        DisclosureGroup(label) {
            Toggle("Has Cost", isOn: hasCostBinding)

            if cost != nil {
                Picker("Type", selection: costTypeBinding) {
                    Text("Health").tag(AbilityCostType.health)
                    Text("Faith").tag(AbilityCostType.faith)
                    Text("Card").tag(AbilityCostType.card)
                    Text("Action").tag(AbilityCostType.action)
                }

                IntField(label: "Value", value: costValueBinding)
            }
        }
    }

    private var hasCostBinding: Binding<Bool> {
        Binding(
            get: { cost != nil },
            set: { enabled in
                if enabled {
                    cost = AbilityCost(type: .faith, value: 1)
                } else {
                    cost = nil
                }
            }
        )
    }

    private var costTypeBinding: Binding<AbilityCostType> {
        Binding(
            get: { cost?.type ?? .faith },
            set: { cost?.type = $0 }
        )
    }

    private var costValueBinding: Binding<Int> {
        Binding(
            get: { cost?.value ?? 0 },
            set: { cost?.value = $0 }
        )
    }
}
