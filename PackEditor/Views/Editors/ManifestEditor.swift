import SwiftUI
import TwilightEngine

struct ManifestEditor: View {
    @Binding var manifest: PackManifest

    var body: some View {
        Form {
            // MARK: - Identity

            Section("Identity") {
                TextField("Pack ID", text: $manifest.packId)
                TextField("Name (EN)", text: Binding(
                    get: { manifest.displayName.en },
                    set: { manifest.displayName.en = $0 }
                ))
                TextField("Name (RU)", text: Binding(
                    get: { manifest.displayName.ru },
                    set: { manifest.displayName.ru = $0 }
                ))
                TextField("Description (EN)", text: Binding(
                    get: { manifest.description.en },
                    set: { manifest.description = LocalizedString(en: $0, ru: manifest.description.ru) }
                ))
                TextField("Description (RU)", text: Binding(
                    get: { manifest.description.ru },
                    set: { manifest.description = LocalizedString(en: manifest.description.en, ru: $0) }
                ))
                IntField(label: "Major", value: Binding(
                    get: { manifest.version.major },
                    set: { manifest.version = SemanticVersion(major: $0, minor: manifest.version.minor, patch: manifest.version.patch) }
                ))
                IntField(label: "Minor", value: Binding(
                    get: { manifest.version.minor },
                    set: { manifest.version = SemanticVersion(major: manifest.version.major, minor: $0, patch: manifest.version.patch) }
                ))
                IntField(label: "Patch", value: Binding(
                    get: { manifest.version.patch },
                    set: { manifest.version = SemanticVersion(major: manifest.version.major, minor: manifest.version.minor, patch: $0) }
                ))
                Picker("Type", selection: $manifest.packType) {
                    ForEach([PackType.campaign, .character, .balance, .rulesExtension, .full], id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                TextField("Author", text: $manifest.author)
            }

            // MARK: - Compatibility

            Section("Compatibility") {
                IntField(label: "Core Min Major", value: Binding(
                    get: { manifest.coreVersionMin.major },
                    set: { manifest.coreVersionMin = SemanticVersion(major: $0, minor: manifest.coreVersionMin.minor, patch: manifest.coreVersionMin.patch) }
                ))
                IntField(label: "Core Min Minor", value: Binding(
                    get: { manifest.coreVersionMin.minor },
                    set: { manifest.coreVersionMin = SemanticVersion(major: manifest.coreVersionMin.major, minor: $0, patch: manifest.coreVersionMin.patch) }
                ))
                IntField(label: "Core Min Patch", value: Binding(
                    get: { manifest.coreVersionMin.patch },
                    set: { manifest.coreVersionMin = SemanticVersion(major: manifest.coreVersionMin.major, minor: manifest.coreVersionMin.minor, patch: $0) }
                ))
                IntField(label: "Core Max Major", value: Binding(
                    get: { manifest.coreVersionMax?.major ?? 0 },
                    set: {
                        let current = manifest.coreVersionMax ?? SemanticVersion(major: 0, minor: 0, patch: 0)
                        manifest.coreVersionMax = SemanticVersion(major: $0, minor: current.minor, patch: current.patch)
                    }
                ))
                IntField(label: "Core Max Minor", value: Binding(
                    get: { manifest.coreVersionMax?.minor ?? 0 },
                    set: {
                        let current = manifest.coreVersionMax ?? SemanticVersion(major: 0, minor: 0, patch: 0)
                        manifest.coreVersionMax = SemanticVersion(major: current.major, minor: $0, patch: current.patch)
                    }
                ))
                IntField(label: "Core Max Patch", value: Binding(
                    get: { manifest.coreVersionMax?.patch ?? 0 },
                    set: {
                        let current = manifest.coreVersionMax ?? SemanticVersion(major: 0, minor: 0, patch: 0)
                        manifest.coreVersionMax = SemanticVersion(major: current.major, minor: current.minor, patch: $0)
                    }
                ))
                StringListEditor(label: "Locale", items: $manifest.supportedLocales)
            }

            // MARK: - Story

            Section("Story") {
                TextField("Entry Region ID", text: Binding(
                    get: { manifest.entryRegionId ?? "" },
                    set: { manifest.entryRegionId = $0.isEmpty ? nil : $0 }
                ))
                TextField("Entry Quest ID", text: Binding(
                    get: { manifest.entryQuestId ?? "" },
                    set: { manifest.entryQuestId = $0.isEmpty ? nil : $0 }
                ))
                StringListEditor(label: "Recommended Hero", items: $manifest.recommendedHeroes)
                Picker("Mission Type", selection: Binding(
                    get: { manifest.missionType ?? .campaign },
                    set: { manifest.missionType = $0 }
                )) {
                    Text("Campaign").tag(MissionType.campaign)
                    Text("Standalone").tag(MissionType.standalone)
                }
                IntField(label: "Difficulty (1-5)", value: Binding(
                    get: { manifest.difficultyRating ?? 1 },
                    set: { manifest.difficultyRating = $0 }
                ), range: 1...5)
                IntField(label: "Est. Playtime (min)", value: Binding(
                    get: { manifest.estimatedPlaytimeMinutes ?? 0 },
                    set: { manifest.estimatedPlaytimeMinutes = $0 == 0 ? nil : $0 }
                ))
                IntField(label: "Min Heroes Required", value: Binding(
                    get: { manifest.minHeroesRequired ?? 0 },
                    set: { manifest.minHeroesRequired = $0 == 0 ? nil : $0 }
                ))
                IntField(label: "Max Heroes Supported", value: Binding(
                    get: { manifest.maxHeroesSupported ?? 0 },
                    set: { manifest.maxHeroesSupported = $0 == 0 ? nil : $0 }
                ))
            }

            // MARK: - Organization

            Section("Organization") {
                TextField("Season", text: Binding(
                    get: { manifest.season ?? "" },
                    set: { manifest.season = $0.isEmpty ? nil : $0 }
                ))
                TextField("Campaign ID", text: Binding(
                    get: { manifest.campaignId ?? "" },
                    set: { manifest.campaignId = $0.isEmpty ? nil : $0 }
                ))
                IntField(label: "Campaign Order", value: Binding(
                    get: { manifest.campaignOrder ?? 0 },
                    set: { manifest.campaignOrder = $0 == 0 ? nil : $0 }
                ))
                TextField("Bundle ID", text: Binding(
                    get: { manifest.bundleId ?? "" },
                    set: { manifest.bundleId = $0.isEmpty ? nil : $0 }
                ))
                StringListEditor(label: "Required Pack", items: Binding(
                    get: { manifest.requiresPacks ?? [] },
                    set: { manifest.requiresPacks = $0.isEmpty ? nil : $0 }
                ))
            }

            // MARK: - Content Paths

            Section("Content Paths") {
                contentPathRow("Regions", path: manifest.regionsPath)
                contentPathRow("Events", path: manifest.eventsPath)
                contentPathRow("Quests", path: manifest.questsPath)
                contentPathRow("Anchors", path: manifest.anchorsPath)
                contentPathRow("Heroes", path: manifest.heroesPath)
                contentPathRow("Abilities", path: manifest.abilitiesPath)
                contentPathRow("Cards", path: manifest.cardsPath)
                contentPathRow("Enemies", path: manifest.enemiesPath)
                contentPathRow("Fate Deck", path: manifest.fateDeckPath)
                contentPathRow("Balance", path: manifest.balancePath)
                contentPathRow("Behaviors", path: manifest.behaviorsPath)
                contentPathRow("Localization", path: manifest.localizationPath)
            }
        }
    }

    @ViewBuilder
    private func contentPathRow(_ label: String, path: String?) -> some View {
        if let path {
            LabeledContent(label) {
                Text(path)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

