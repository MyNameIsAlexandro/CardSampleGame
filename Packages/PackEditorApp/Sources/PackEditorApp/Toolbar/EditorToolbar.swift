import SwiftUI
import TwilightEngine
import PackAuthoring
import PackEditorKit

struct EditorToolbar: ToolbarContent {
    @EnvironmentObject var tab: EditorTab

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                tab.savePack()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(!tab.isDirty)

            Divider()

            Button {
                validatePack()
            } label: {
                Label("Validate", systemImage: "checkmark.shield")
            }
            .disabled(tab.loadedPack == nil)

            Button {
                compilePack()
            } label: {
                Label("Compile", systemImage: "hammer")
            }
            .disabled(tab.loadedPack == nil)
        }
    }

    private func validatePack() {
        guard tab.packURL != nil else { return }
        tab.validate()
        tab.showValidation = true
    }

    private func compilePack() {
        guard let url = tab.packURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "\(tab.loadedPack?.manifest.packId ?? "pack").pack"

        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        do {
            let result = try PackCompiler.compile(from: url, to: outputURL)
            print("PackEditor: Compiled \(result.packId) — \(result.outputSize) bytes")
        } catch {
            print("PackEditor: Compilation failed: \(error)")
        }
    }
}
