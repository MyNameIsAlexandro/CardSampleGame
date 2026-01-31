import SwiftUI
import TwilightEngine
import PackEditorKit

struct RegionEditor: View {
    @Binding var region: RegionDefinition

    private var anchorIdBinding: Binding<String> {
        Binding<String>(
            get: { region.anchorId ?? "" },
            set: { region.anchorId = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: region.id)
                LocalizedTextField(label: "Title", text: $region.title)
                    .validated(region.title.displayString.isEmpty ? .error("Title is required") : nil)
                LocalizedTextField(label: "Description", text: $region.description)
                TextField("Region Type", text: $region.regionType)
                    .validated(region.regionType.isEmpty ? .error("Region type is required") : nil)
            }

            Section("Settings") {
                Toggle("Initially Discovered", isOn: $region.initiallyDiscovered)
                Picker("Initial State", selection: $region.initialState) {
                    ForEach(RegionStateType.allCases, id: \.self) { state in
                        Text(state.rawValue).tag(state)
                    }
                }
                IntField(label: "Degradation Weight", value: $region.degradationWeight)
                TextField("Anchor ID", text: anchorIdBinding)
            }

            Section("Connections") {
                StringListEditor(label: "Neighbors", items: $region.neighborIds)
                StringListEditor(label: "Event Pools", items: $region.eventPoolIds)
            }
        }
        .formStyle(.grouped)
    }
}
