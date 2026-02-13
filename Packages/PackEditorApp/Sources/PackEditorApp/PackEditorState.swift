/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/PackEditorState.swift
/// Назначение: Содержит реализацию файла PackEditorState.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

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
            #if DEBUG
            print("PackEditor: Successfully loaded pack from \(url.lastPathComponent)")
            print("  - Enemies: \(tab.store.enemies.count)")
            print("  - Cards: \(tab.store.cards.count)")
            print("  - Events: \(tab.store.events.count)")
            print("  - Regions: \(tab.store.regions.count)")
            print("  - Heroes: \(tab.store.heroes.count)")
            print("  - FateCards: \(tab.store.fateCards.count)")
            print("  - Quests: \(tab.store.quests.count)")
            print("  - Behaviors: \(tab.store.behaviors.count)")
            print("  - Anchors: \(tab.store.anchors.count)")
            #endif
            tabs.append(tab)
            switchToTab(tab)
        } catch {
            print("PackEditor: Failed to load pack: \(error)")
            #if DEBUG
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("  → typeMismatch: expected \(type)")
                    print("  → path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("  → description: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("  → valueNotFound: \(type)")
                    print("  → path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .keyNotFound(let key, let context):
                    print("  → keyNotFound: \(key.stringValue)")
                    print("  → path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("  → dataCorrupted: \(context.debugDescription)")
                @unknown default:
                    print("  → unknown decoding error")
                }
            }
            #endif
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
