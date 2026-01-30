import SwiftUI
import TwilightEngine
import PackAuthoring

struct EditorToolbar: ToolbarContent {
    @EnvironmentObject var state: PackEditorState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                state.openPack()
            } label: {
                Label("Open", systemImage: "folder")
            }

            Button {
                state.savePack()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(!state.isDirty)

            Divider()

            Button {
                validatePack()
            } label: {
                Label("Validate", systemImage: "checkmark.shield")
            }
            .disabled(state.loadedPack == nil)

            Button {
                compilePack()
            } label: {
                Label("Compile", systemImage: "hammer")
            }
            .disabled(state.loadedPack == nil)
        }
    }

    private func validatePack() {
        guard let url = state.packURL else { return }
        let validator = PackValidator(packURL: url)
        let summary = validator.validate()
        state.validationSummary = summary
        state.showValidation = true
    }

    private func compilePack() {
        guard let url = state.packURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "\(state.loadedPack?.manifest.packId ?? "pack").pack"

        guard panel.runModal() == .OK, let outputURL = panel.url else { return }

        do {
            let result = try PackCompiler.compile(from: url, to: outputURL)
            print("PackEditor: Compiled \(result.packId) — \(result.outputSize) bytes")
        } catch {
            print("PackEditor: Compilation failed: \(error)")
        }
    }
}
