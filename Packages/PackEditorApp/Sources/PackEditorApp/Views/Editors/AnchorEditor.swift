/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Editors/AnchorEditor.swift
/// Назначение: Содержит реализацию файла AnchorEditor.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI
import TwilightEngine
import PackEditorKit

struct AnchorEditor: View {
    @Binding var anchor: AnchorDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: anchor.id)
                LocalizedTextField(label: "Title", text: $anchor.title)
                LocalizedTextField(label: "Description", text: $anchor.description)
            }

            Section("Location") {
                TextField("Region ID", text: $anchor.regionId)
                TextField("Anchor Type", text: $anchor.anchorType)
            }

            Section("Influence") {
                Picker("Initial Influence", selection: $anchor.initialInfluence) {
                    Text("Light").tag(AnchorInfluence.light)
                    Text("Neutral").tag(AnchorInfluence.neutral)
                    Text("Dark").tag(AnchorInfluence.dark)
                }
                IntField(label: "Power", value: $anchor.power)
            }

            Section("Integrity") {
                IntField(label: "Max Integrity", value: $anchor.maxIntegrity)
                IntField(label: "Initial Integrity", value: $anchor.initialIntegrity)
                IntField(label: "Strengthen Amount", value: $anchor.strengthenAmount)
                IntField(label: "Resistance Divisor", value: $anchor.resistanceDivisor)
            }

            Section("Strengthen Cost") {
                LabeledContent("Cost", value: String(describing: anchor.strengthenCost))
            }
        }
        .formStyle(.grouped)
    }
}
