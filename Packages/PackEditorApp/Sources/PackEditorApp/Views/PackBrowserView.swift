import SwiftUI
import PackEditorKit
import TwilightEngine

struct PackBrowserView: View {
    @EnvironmentObject var state: PackEditorState
    @State private var scanResults: [PackScanResult] = []
    @State private var showNewPackSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("browser.title", bundle: .module)
                    .font(.title.bold())
                Spacer()
                Button(String(localized: "browser.openOther", bundle: .module)) {
                    state.openPackDialog()
                }
                Button(String(localized: "browser.newPack", bundle: .module)) {
                    showNewPackSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            if scanResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("browser.noPacksFound", bundle: .module)
                        .font(.title3)
                    if state.projectRootPath.isEmpty {
                        Button(String(localized: "browser.setProjectRoot", bundle: .module)) {
                            pickProjectRoot()
                        }
                    } else {
                        Text(String(localized: "browser.scanning \(state.projectRootPath)", bundle: .module))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Button(String(localized: "browser.rescan", bundle: .module)) { rescan() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400))], spacing: 16) {
                        ForEach(scanResults) { result in
                            PackCardView(result: result) {
                                state.openPack(from: result.url)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear { rescan() }
        .sheet(isPresented: $showNewPackSheet) {
            NewPackSheet { url in
                rescan()
                state.openPack(from: url)
            }
        }
    }

    private func rescan() {
        // Auto-detect project root from compile-time file path
        if state.projectRootPath.isEmpty {
            let packageDir = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Views/
                .deletingLastPathComponent() // PackEditorApp/
                .deletingLastPathComponent() // Sources/
                .deletingLastPathComponent() // PackEditorApp/
                .deletingLastPathComponent() // Packages/
            if FileManager.default.fileExists(atPath: packageDir.appendingPathComponent("Packages").path) {
                state.projectRootPath = packageDir.path
            }
        }

        guard !state.projectRootPath.isEmpty else { return }
        let root = URL(fileURLWithPath: state.projectRootPath)
        let roots = [
            root.appendingPathComponent("Packages/CharacterPacks"),
            root.appendingPathComponent("Packages/StoryPacks")
        ]
        scanResults = PackScanner.scan(roots: roots)
    }

    private func pickProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = String(localized: "browser.selectProjectRoot", bundle: .module)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.projectRootPath = url.path
        rescan()
    }
}

// MARK: - Pack Card

struct PackCardView: View {
    let result: PackScanResult
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: result.packType == .character ? "person.2.fill" : "map.fill")
                        .foregroundStyle(result.packType == .character ? .blue : .orange)
                    Text(result.displayName)
                        .font(.headline)
                    Spacer()
                    Text(result.packType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .cornerRadius(4)
                }
                Text(verbatim: "v\(result.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.id)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - New Pack Sheet

struct NewPackSheet: View {
    @EnvironmentObject var state: PackEditorState
    @Environment(\.dismiss) private var dismiss
    @State private var packId = ""
    @State private var displayName = ""
    @State private var packType: PackType = .campaign
    @State private var author = ""
    @State private var errorMessage: String?
    let onCreated: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("newPack.title", bundle: .module).font(.title2.bold())

            Form {
                TextField(String(localized: "newPack.packId", bundle: .module), text: $packId)
                TextField(String(localized: "newPack.displayName", bundle: .module), text: $displayName)
                Picker(String(localized: "newPack.type", bundle: .module), selection: $packType) {
                    Text("newPack.typeCampaign", bundle: .module).tag(PackType.campaign)
                    Text("newPack.typeCharacter", bundle: .module).tag(PackType.character)
                }
                TextField(String(localized: "newPack.author", bundle: .module), text: $author)
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button(String(localized: "newPack.cancel", bundle: .module)) { dismiss() }
                Button(String(localized: "newPack.create", bundle: .module)) { createPack() }
                    .buttonStyle(.borderedProminent)
                    .disabled(packId.isEmpty || displayName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func createPack() {
        // Determine parent directory based on pack type and project root
        let parentURL: URL
        if !state.projectRootPath.isEmpty {
            let root = URL(fileURLWithPath: state.projectRootPath)
            switch packType {
            case .character:
                parentURL = root.appendingPathComponent("Packages/CharacterPacks")
            default:
                parentURL = root.appendingPathComponent("Packages/StoryPacks")
            }
        } else {
            // Fallback: ask user
            let panel = NSSavePanel()
            panel.nameFieldStringValue = packId
            panel.message = String(localized: "newPack.chooseLocation", bundle: .module)
            guard panel.runModal() == .OK, let url = panel.url else { return }
            parentURL = url.deletingLastPathComponent()
        }

        do {
            let options = PackTemplateGenerator.Options(
                packId: packId,
                displayName: displayName,
                packType: packType,
                author: author.isEmpty ? "Pack Editor" : author
            )
            let packURL = try PackTemplateGenerator.generate(at: parentURL, options: options)
            dismiss()
            onCreated(packURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
