import SwiftUI
import TwilightEngine
import PackAuthoring
import PackEditorKit

struct EditorToolbar: ToolbarContent {
    @EnvironmentObject var tab: EditorTab
    @EnvironmentObject var state: PackEditorState

    @State private var exportAlert: ExportAlert?

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

            Divider()

            Button {
                exportToGame()
            } label: {
                Label("Export to Game", systemImage: "square.and.arrow.up")
            }
            .disabled(tab.loadedPack == nil)
            .alert(item: $exportAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func validatePack() {
        guard tab.packURL != nil else { return }
        tab.validate()
        tab.showValidation = true
    }

    private func exportToGame() {
        guard let url = tab.packURL else { return }

        // 1. Save
        tab.savePack()

        // 2. Validate
        tab.validate()
        if let summary = tab.validationSummary, summary.errorCount > 0 {
            exportAlert = ExportAlert(
                title: "Validation Failed",
                message: "\(summary.errorCount) error(s) found. Fix them before exporting."
            )
            tab.showValidation = true
            return
        }

        // 3. Get game project path
        var gamePath = state.gameProjectPath
        if gamePath.isEmpty {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Select the game project root directory"

            guard panel.runModal() == .OK, let selected = panel.url else { return }
            gamePath = selected.path
            state.gameProjectPath = gamePath
        }

        // 4. Compile
        let packId = tab.loadedPack?.manifest.packId ?? "pack"
        let outputDir = URL(fileURLWithPath: gamePath)
            .appendingPathComponent("Resources/ContentPacks/\(packId)")
        let outputFile = outputDir.appendingPathComponent("\(packId).pack")

        do {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            let result = try PackCompiler.compile(from: url, to: outputFile)
            exportAlert = ExportAlert(
                title: "Export Successful",
                message: "Exported \(result.packId) (\(result.outputSize) bytes) to ContentPacks."
            )
        } catch {
            exportAlert = ExportAlert(
                title: "Export Failed",
                message: error.localizedDescription
            )
        }
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

// MARK: - Export Alert Model

private struct ExportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
