import SwiftUI
import TwilightEngine
import PackAuthoring
import PackEditorKit

// MARK: - Pack Editor State (Multi-Tab Coordinator)

/// Coordinates multiple open pack tabs and the pack browser.
class PackEditorState: ObservableObject {

    @Published var tabs: [EditorTab] = []
    @Published var activeTabId: UUID? = nil
    @Published var showBrowser: Bool = true
    @AppStorage("packEditorProjectRoot") var projectRootPath: String = ""
    @AppStorage("packEditorGamePath") var gameProjectPath: String = ""

    var activeTab: EditorTab? {
        tabs.first { $0.id == activeTabId }
    }

    var packTitle: String {
        if showBrowser { return "Pack Editor" }
        return activeTab?.store.packTitle ?? "Pack Editor"
    }

    // MARK: - Open Pack

    func openPack(from url: URL) {
        // Check if already open
        if let existing = tabs.first(where: { $0.store.packURL == url }) {
            switchToTab(existing)
            return
        }
        let tab = EditorTab()
        do {
            try tab.store.loadPack(from: url)
            tabs.append(tab)
            switchToTab(tab)
        } catch {
            print("PackEditor: Failed to load pack: \(error)")
        }
    }

    func openPackDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a pack source folder (containing manifest.json)"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openPack(from: url)
    }

    // MARK: - Tab Management

    func switchToTab(_ tab: EditorTab) {
        autosaveCurrentTab()
        activeTabId = tab.id
        showBrowser = false
        objectWillChange.send()
    }

    func showPackBrowser() {
        autosaveCurrentTab()
        showBrowser = true
        activeTabId = nil
        objectWillChange.send()
    }

    func closeTab(_ tab: EditorTab) {
        autosaveIfNeeded(tab)
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty {
            showBrowser = true
            activeTabId = nil
        } else if activeTabId == tab.id {
            activeTabId = tabs.last?.id
        }
        objectWillChange.send()
    }

    // MARK: - Autosave

    func autosaveCurrentTab() {
        guard let tab = activeTab else { return }
        autosaveIfNeeded(tab)
    }

    func autosaveIfNeeded(_ tab: EditorTab) {
        guard tab.store.isDirty else { return }
        do {
            try tab.store.savePack()
        } catch {
            print("PackEditor: Autosave failed: \(error)")
        }
    }

    func autosaveAll() {
        for tab in tabs { autosaveIfNeeded(tab) }
    }
}
