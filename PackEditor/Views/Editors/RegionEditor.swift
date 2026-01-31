import SwiftUI
import TwilightEngine
import PackEditorKit

struct RegionEditor: View {
    @Binding var region: RegionDefinition

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("ID", value: region.id)
                LabeledContent("Title (EN)", value: region.title.displayString)
                LabeledContent("Description", value: region.description.displayString)
                LabeledContent("Type", value: region.regionType)
            }

            Section("Settings") {
                LabeledContent("Initially Discovered", value: region.initiallyDiscovered ? "Yes" : "No")
                LabeledContent("Initial State", value: region.initialState.rawValue)
                LabeledContent("Degradation Weight", value: "\(region.degradationWeight)")
                if let anchorId = region.anchorId {
                    LabeledContent("Anchor", value: anchorId)
                }
            }

            Section("Connections") {
                LabeledContent("Neighbors", value: region.neighborIds.joined(separator: ", "))
                LabeledContent("Event Pools", value: region.eventPoolIds.joined(separator: ", "))
            }
        }
        .formStyle(.grouped)
    }
}
