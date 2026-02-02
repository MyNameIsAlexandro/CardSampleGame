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
                Text("Pack Browser")
                    .font(.title.bold())
                Spacer()
                Button("Open Other...") {
                    state.openPackDialog()
                }
                Button("New Pack...") {
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
                    Text("No packs found")
                        .font(.title3)
                    if state.projectRootPath.isEmpty {
                        Button("Set Project Root...") {
                            pickProjectRoot()
                        }
                    } else {
                        Text("Scanning: \(state.projectRootPath)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Button("Rescan") { rescan() }
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
        panel.message = "Select the CardSampleGame project root directory"
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
            Text("New Pack").font(.title2.bold())

            Form {
                TextField("Pack ID (e.g. my-adventure)", text: $packId)
                TextField("Display Name", text: $displayName)
                Picker("Type", selection: $packType) {
                    Text("Campaign").tag(PackType.campaign)
                    Text("Character").tag(PackType.character)
                }
                TextField("Author", text: $author)
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Button("Create...") { createPack() }
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
            panel.message = "Choose location for the new pack"
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
