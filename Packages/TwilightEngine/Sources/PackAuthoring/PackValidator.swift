import Foundation
import TwilightEngine

// MARK: - Pack Validator

/// Comprehensive validator for content packs
/// Validates structure, references, balance, and content integrity
public final class PackValidator {
    // MARK: - Types

    /// Validation severity level
    public enum Severity: String, CaseIterable {
        case error = "ERROR"      // Pack cannot be loaded
        case warning = "WARNING"  // Pack loads but may have issues
        case info = "INFO"        // Informational, not a problem
    }

    /// Validation result for a single check
    public struct ValidationResult {
        public let severity: Severity
        public let category: String
        public let message: String
        public let file: String?
        public let line: Int?

        public var description: String {
            var desc = "[\(severity.rawValue)] \(category): \(message)"
            if let file = file {
                desc += " (in \(file)"
                if let line = line {
                    desc += ":\(line)"
                }
                desc += ")"
            }
            return desc
        }
    }

    /// Summary of validation results
    public struct ValidationSummary {
        public let packId: String
        public let results: [ValidationResult]
        public let duration: TimeInterval

        public var errorCount: Int { results.filter { $0.severity == .error }.count }
        public var warningCount: Int { results.filter { $0.severity == .warning }.count }
        public var infoCount: Int { results.filter { $0.severity == .info }.count }

        public var isValid: Bool { errorCount == 0 }

        var description: String {
            var lines: [String] = []
            lines.append("=== Pack Validation: \(packId) ===")
            lines.append("Duration: \(String(format: "%.2f", duration))s")
            lines.append("Errors: \(errorCount), Warnings: \(warningCount), Info: \(infoCount)")
            lines.append("")

            if !results.isEmpty {
                for result in results {
                    lines.append(result.description)
                }
            } else {
                lines.append("No issues found.")
            }

            lines.append("")
            lines.append(isValid ? "VALIDATION PASSED" : "VALIDATION FAILED")
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Properties

    private var results: [ValidationResult] = []
    private let packURL: URL
    private var manifest: PackManifest?
    private var loadedPack: LoadedPack?

    // MARK: - Initialization

    public init(packURL: URL) {
        self.packURL = packURL
    }

    // MARK: - Public API

    /// Validate a pack at the given URL
    /// - Returns: Validation summary with all results
    public func validate() -> ValidationSummary {
        let startTime = Date()
        results.removeAll()

        // Phase 1: Validate manifest
        validateManifest()

        // Phase 2: Validate file structure
        if manifest != nil {
            validateFileStructure()
        }

        // Phase 3: Load and validate content
        if manifest != nil {
            validateContent()
        }

        // Phase 4: Validate cross-references
        if loadedPack != nil {
            validateCrossReferences()
        }

        // Phase 5: Validate balance configuration
        if let pack = loadedPack, pack.balanceConfig != nil {
            validateBalanceConfig()
        }

        // Phase 6: Validate localization
        if let pack = loadedPack {
            validateLocalization(pack)
        }

        let duration = Date().timeIntervalSince(startTime)
        return ValidationSummary(
            packId: manifest?.packId ?? "unknown",
            results: results,
            duration: duration
        )
    }

    /// Validate pack and return just the error/warning count
    public static func quickValidate(packURL: URL) -> (errors: Int, warnings: Int) {
        let validator = PackValidator(packURL: packURL)
        let summary = validator.validate()
        return (summary.errorCount, summary.warningCount)
    }

    // MARK: - Phase 1: Manifest Validation

    private func validateManifest() {
        let manifestURL = packURL.appendingPathComponent("manifest.json")

        // Check manifest exists
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            addError("Manifest", "manifest.json not found at pack root")
            return
        }

        // Try to load manifest
        do {
            manifest = try PackManifest.load(from: packURL)
        } catch {
            addError("Manifest", "Failed to parse manifest.json: \(error.localizedDescription)")
            return
        }

        guard let manifest = manifest else { return }

        // Validate required fields
        if manifest.packId.isEmpty {
            addError("Manifest", "packId is required")
        }

        if manifest.packId.contains(" ") {
            addWarning("Manifest", "packId should not contain spaces: '\(manifest.packId)'")
        }

        if manifest.displayName.en.isEmpty {
            addError("Manifest", "displayName.en is required")
        }

        // Validate version
        if manifest.version.major == 0 && manifest.version.minor == 0 && manifest.version.patch == 0 {
            addWarning("Manifest", "Version 0.0.0 suggests pack is not properly versioned")
        }

        // Validate Core compatibility
        if !manifest.isCompatibleWithCore() {
            addError("Manifest", "Pack requires Core version \(manifest.coreVersionMin), but current is \(CoreVersion.current)")
        }

        // Validate entry points for campaign packs
        if manifest.packType == .campaign || manifest.packType == .full {
            if manifest.entryRegionId == nil {
                addWarning("Manifest", "Campaign pack should specify entryRegionId")
            }
        }

        // Validate paths exist
        validateManifestPaths(manifest)

        addInfo("Manifest", "Loaded pack '\(manifest.packId)' v\(manifest.version)")
    }

    private func validateManifestPaths(_ manifest: PackManifest) {
        let paths = [
            ("regionsPath", manifest.regionsPath),
            ("eventsPath", manifest.eventsPath),
            ("heroesPath", manifest.heroesPath),
            ("cardsPath", manifest.cardsPath),
            ("balancePath", manifest.balancePath),
            ("localizationPath", manifest.localizationPath)
        ]

        for (name, path) in paths {
            if let path = path {
                let fullPath = packURL.appendingPathComponent(path)
                if !FileManager.default.fileExists(atPath: fullPath.path) {
                    addWarning("Manifest", "\(name) points to non-existent path: \(path)")
                }
            }
        }
    }

    // MARK: - Phase 2: File Structure Validation

    private func validateFileStructure() {
        guard let manifest = manifest else { return }

        // Check for required directories based on pack type
        switch manifest.packType {
        case .campaign, .full:
            checkDirectory("Campaign content", manifest.regionsPath)
            checkDirectory("Events", manifest.eventsPath)

        case .character:
            checkDirectory("Heroes", manifest.heroesPath)
            checkDirectory("Cards", manifest.cardsPath)

        case .balance:
            checkDirectory("Balance", manifest.balancePath)

        case .rulesExtension:
            break // No specific requirements
        }

        // Check localization
        if let locPath = manifest.localizationPath {
            let locURL = packURL.appendingPathComponent(locPath)
            if FileManager.default.fileExists(atPath: locURL.path) {
                for locale in manifest.supportedLocales {
                    let localeFile = locURL.appendingPathComponent("\(locale).json")
                    if !FileManager.default.fileExists(atPath: localeFile.path) {
                        addWarning("Localization", "Missing localization file for locale '\(locale)'")
                    }
                }
            }
        }
    }

    private func checkDirectory(_ name: String, _ path: String?) {
        guard let path = path else {
            addWarning("Structure", "\(name) path not specified in manifest")
            return
        }

        let fullPath = packURL.appendingPathComponent(path)
        var isDirectory: ObjCBool = false

        if !FileManager.default.fileExists(atPath: fullPath.path, isDirectory: &isDirectory) {
            addWarning("Structure", "\(name) directory not found: \(path)")
        } else if !isDirectory.boolValue {
            // Check if it's a file (like regions.json instead of regions/)
            if !fullPath.pathExtension.isEmpty {
                addInfo("Structure", "\(name) is a file: \(path)")
            }
        }
    }

    // MARK: - Phase 3: Content Validation

    private func validateContent() {
        guard let manifest = manifest else { return }

        do {
            loadedPack = try PackLoader.load(manifest: manifest, from: packURL)
            addInfo("Content", "Loaded \(loadedPack?.regions.count ?? 0) regions, \(loadedPack?.events.count ?? 0) events, \(loadedPack?.heroes.count ?? 0) heroes, \(loadedPack?.cards.count ?? 0) cards")
        } catch {
            addError("Content", "Failed to load pack content: \(error.localizedDescription)")
            return
        }

        guard let pack = loadedPack else { return }

        // Validate regions
        for (id, region) in pack.regions {
            validateRegion(id: id, region: region)
        }

        // Validate events
        for (id, event) in pack.events {
            validateEvent(id: id, event: event)
        }

        // Validate heroes
        for (id, hero) in pack.heroes {
            validateHero(id: id, hero: hero)
        }

        // Validate cards
        for (id, card) in pack.cards {
            validateCard(id: id, card: card)
        }

        // Validate anchors
        for (id, anchor) in pack.anchors {
            validateAnchor(id: id, anchor: anchor)
        }
    }

    private func validateRegion(id: String, region: RegionDefinition) {
        if region.title.en.isEmpty {
            addError("Region", "Region '\(id)' has empty English title")
        }

        if region.neighborIds.isEmpty {
            addWarning("Region", "Region '\(id)' has no neighbors (isolated)")
        }

        // Check for self-reference
        if region.neighborIds.contains(id) {
            addError("Region", "Region '\(id)' lists itself as neighbor")
        }
    }

    private func validateEvent(id: String, event: EventDefinition) {
        if event.title.en.isEmpty {
            addError("Event", "Event '\(id)' has empty English title")
        }

        if event.choices.isEmpty {
            addWarning("Event", "Event '\(id)' has no choices")
        }

        // Validate choices
        var choiceIds = Set<String>()
        for choice in event.choices {
            if choiceIds.contains(choice.id) {
                addError("Event", "Event '\(id)' has duplicate choice ID: \(choice.id)")
            }
            choiceIds.insert(choice.id)

            if choice.label.en.isEmpty {
                addWarning("Event", "Event '\(id)' choice '\(choice.id)' has empty label")
            }
        }

        // Validate weight
        if event.weight <= 0 {
            addWarning("Event", "Event '\(id)' has non-positive weight: \(event.weight)")
        }
    }

    private func validateHero(id: String, hero: StandardHeroDefinition) {
        if hero.name.isEmpty {
            addError("Hero", "Hero '\(id)' has empty name")
        }

        if hero.startingDeckCardIDs.isEmpty {
            addWarning("Hero", "Hero '\(id)' has empty starting deck")
        }

        // Check for duplicate cards in starting deck
        let uniqueCards = Set(hero.startingDeckCardIDs)
        if uniqueCards.count != hero.startingDeckCardIDs.count {
            addInfo("Hero", "Hero '\(id)' has duplicate cards in starting deck")
        }
    }

    private func validateCard(id: String, card: StandardCardDefinition) {
        if card.name.isEmpty {
            addError("Card", "Card '\(id)' has empty name")
        }

        if card.faithCost < 0 {
            addError("Card", "Card '\(id)' has negative faith cost: \(card.faithCost)")
        }
    }

    private func validateAnchor(id: String, anchor: AnchorDefinition) {
        if anchor.title.en.isEmpty {
            addError("Anchor", "Anchor '\(id)' has empty English title")
        }

        if anchor.initialIntegrity < 0 || anchor.initialIntegrity > anchor.maxIntegrity {
            addError("Anchor", "Anchor '\(id)' has invalid initial integrity: \(anchor.initialIntegrity) (max: \(anchor.maxIntegrity))")
        }

        if anchor.maxIntegrity <= 0 {
            addError("Anchor", "Anchor '\(id)' has non-positive max integrity: \(anchor.maxIntegrity)")
        }
    }

    // MARK: - Phase 4: Cross-Reference Validation

    private func validateCrossReferences() {
        guard let pack = loadedPack else { return }

        // Region neighbor references
        for (id, region) in pack.regions {
            for neighborId in region.neighborIds {
                if pack.regions[neighborId] == nil {
                    addError("Reference", "Region '\(id)' references non-existent neighbor '\(neighborId)'")
                }
            }
        }

        // Check bidirectional neighbors
        for (id, region) in pack.regions {
            for neighborId in region.neighborIds {
                if let neighbor = pack.regions[neighborId] {
                    if !neighbor.neighborIds.contains(id) {
                        addWarning("Reference", "Region '\(id)' → '\(neighborId)' is not bidirectional")
                    }
                }
            }
        }

        // Anchor region references
        for (id, anchor) in pack.anchors {
            if pack.regions[anchor.regionId] == nil {
                addError("Reference", "Anchor '\(id)' references non-existent region '\(anchor.regionId)'")
            }
        }

        // Event region references
        for (id, event) in pack.events {
            if let regionIds = event.availability.regionIds {
                for regionId in regionIds {
                    if pack.regions[regionId] == nil {
                        addError("Reference", "Event '\(id)' references non-existent region '\(regionId)'")
                    }
                }
            }
        }

        // Hero starting deck references
        for (id, hero) in pack.heroes {
            for cardId in hero.startingDeckCardIDs {
                if pack.cards[cardId] == nil {
                    addError("Reference", "Hero '\(id)' references non-existent card '\(cardId)'")
                }
            }
        }

        // Entry region validation
        if let manifest = manifest, let entryRegionId = manifest.entryRegionId {
            if pack.regions[entryRegionId] == nil {
                addError("Reference", "Manifest entryRegionId '\(entryRegionId)' not found in regions")
            }
        }
    }

    // MARK: - Phase 5: Balance Validation

    private func validateBalanceConfig() {
        guard let pack = loadedPack, let balance = pack.balanceConfig else { return }

        // Resource validation
        if balance.resources.maxHealth <= 0 {
            addError("Balance", "maxHealth must be positive: \(balance.resources.maxHealth)")
        }

        if balance.resources.startingHealth > balance.resources.maxHealth {
            addError("Balance", "startingHealth (\(balance.resources.startingHealth)) exceeds maxHealth (\(balance.resources.maxHealth))")
        }

        if balance.resources.startingHealth <= 0 {
            addWarning("Balance", "startingHealth is non-positive: \(balance.resources.startingHealth)")
        }

        if balance.resources.maxFaith <= 0 {
            addError("Balance", "maxFaith must be positive: \(balance.resources.maxFaith)")
        }

        if balance.resources.startingFaith > balance.resources.maxFaith {
            addError("Balance", "startingFaith (\(balance.resources.startingFaith)) exceeds maxFaith (\(balance.resources.maxFaith))")
        }

        // Pressure validation
        if balance.pressure.maxPressure <= 0 {
            addError("Balance", "maxPressure must be positive: \(balance.pressure.maxPressure)")
        }

        if balance.pressure.startingPressure < 0 {
            addWarning("Balance", "startingPressure is negative: \(balance.pressure.startingPressure)")
        }

        if balance.pressure.startingPressure > balance.pressure.maxPressure {
            addError("Balance", "startingPressure (\(balance.pressure.startingPressure)) exceeds maxPressure (\(balance.pressure.maxPressure))")
        }

        // Anchor validation
        if balance.anchor.maxIntegrity <= 0 {
            addError("Balance", "anchor.maxIntegrity must be positive: \(balance.anchor.maxIntegrity)")
        }

        if balance.anchor.strengthenCost < 0 {
            addError("Balance", "anchor.strengthenCost cannot be negative: \(balance.anchor.strengthenCost)")
        }

        if balance.anchor.strengthenAmount <= 0 {
            addWarning("Balance", "anchor.strengthenAmount is non-positive: \(balance.anchor.strengthenAmount)")
        }

        addInfo("Balance", "Balance configuration validated")
    }

    // MARK: - Phase 6: Localization Validation

    private func validateLocalization(_ pack: LoadedPack) {
        guard let manifest = manifest else { return }

        // Collect all StringKey references from entities
        var referencedKeys = Set<String>()
        collectStringKeys(from: pack, into: &referencedKeys)

        // If no localization path and no string keys, skip detailed validation
        guard let locPath = manifest.localizationPath else {
            // Report info if pack uses no string keys
            if referencedKeys.isEmpty {
                addInfo("Localization", "Pack uses inline LocalizedString (legacy mode)")
            } else {
                addError("Localization", "Pack uses \(referencedKeys.count) StringKey references but has no localizationPath in manifest")
            }
            return
        }

        let locURL = packURL.appendingPathComponent(locPath)

        // Validate string tables exist for each declared locale
        var allTableKeys: [String: Set<String>] = [:]  // [locale: keys]

        for locale in manifest.supportedLocales {
            let localeFile = locURL.appendingPathComponent("\(locale).json")

            guard FileManager.default.fileExists(atPath: localeFile.path) else {
                addError("Localization", "Missing string table for declared locale '\(locale)' at \(locPath)/\(locale).json")
                continue
            }

            do {
                let data = try Data(contentsOf: localeFile)
                let table = try JSONDecoder().decode([String: String].self, from: data)
                allTableKeys[locale] = Set(table.keys)

                // Validate key format
                for key in table.keys {
                    let stringKey = StringKey(key)
                    if !stringKey.isValid {
                        addWarning("Localization", "Invalid key format '\(key)' in \(locale).json. Expected: lowercase.dot.separated")
                    }
                }

                addInfo("Localization", "Loaded \(table.count) keys from \(locale).json")
            } catch {
                addError("Localization", "Failed to parse \(locale).json: \(error.localizedDescription)")
            }
        }

        // Check for missing keys in each locale
        let englishKeys = allTableKeys["en"] ?? []

        for (locale, localeKeys) in allTableKeys {
            // Check referenced keys that are missing
            let missingReferenced = referencedKeys.subtracting(localeKeys)
            for key in missingReferenced.sorted().prefix(10) {
                addWarning("Localization", "StringKey '\(key)' referenced in content but not found in \(locale).json")
            }
            if missingReferenced.count > 10 {
                addWarning("Localization", "... and \(missingReferenced.count - 10) more missing keys in \(locale).json")
            }

            // Check for incomplete translations (present in en but not in other locales)
            if locale != "en" {
                let missingTranslations = englishKeys.subtracting(localeKeys)
                if !missingTranslations.isEmpty {
                    addWarning("Localization", "\(locale).json missing \(missingTranslations.count) translations present in en.json")
                }
            }
        }

        if referencedKeys.isEmpty && allTableKeys.values.allSatisfy({ $0.isEmpty }) {
            addInfo("Localization", "Pack has localization structure but no string keys used yet")
        } else {
            addInfo("Localization", "Localization validation complete: \(referencedKeys.count) keys referenced")
        }
    }

    /// Collect all StringKey values from pack entities
    private func collectStringKeys(from pack: LoadedPack, into keys: inout Set<String>) {
        // Collect from regions
        for (_, region) in pack.regions {
            if case .key(let k) = region.title { keys.insert(k.rawValue) }
            if case .key(let k) = region.description { keys.insert(k.rawValue) }
        }

        // Collect from events
        for (_, event) in pack.events {
            if case .key(let k) = event.title { keys.insert(k.rawValue) }
            if case .key(let k) = event.body { keys.insert(k.rawValue) }
            for choice in event.choices {
                if case .key(let k) = choice.label { keys.insert(k.rawValue) }
                if let tooltip = choice.tooltip, case .key(let k) = tooltip { keys.insert(k.rawValue) }
            }
        }

        // Collect from heroes
        for (_, hero) in pack.heroes {
            if case .key(let k) = hero.name { keys.insert(k.rawValue) }
            if case .key(let k) = hero.description { keys.insert(k.rawValue) }
            if case .key(let k) = hero.specialAbility.name { keys.insert(k.rawValue) }
            if case .key(let k) = hero.specialAbility.description { keys.insert(k.rawValue) }
        }

        // Collect from cards
        for (_, card) in pack.cards {
            if case .key(let k) = card.name { keys.insert(k.rawValue) }
            if case .key(let k) = card.description { keys.insert(k.rawValue) }
        }

        // Collect from enemies
        for (_, enemy) in pack.enemies {
            if case .key(let k) = enemy.name { keys.insert(k.rawValue) }
            if case .key(let k) = enemy.description { keys.insert(k.rawValue) }
            for ability in enemy.abilities {
                if case .key(let k) = ability.name { keys.insert(k.rawValue) }
                if case .key(let k) = ability.description { keys.insert(k.rawValue) }
            }
        }

        // Collect from anchors
        for (_, anchor) in pack.anchors {
            if case .key(let k) = anchor.title { keys.insert(k.rawValue) }
            if case .key(let k) = anchor.description { keys.insert(k.rawValue) }
        }

        // Collect from quests
        for (_, quest) in pack.quests {
            if case .key(let k) = quest.title { keys.insert(k.rawValue) }
            if case .key(let k) = quest.description { keys.insert(k.rawValue) }
            for objective in quest.objectives {
                if case .key(let k) = objective.description { keys.insert(k.rawValue) }
                if let hint = objective.hint, case .key(let k) = hint { keys.insert(k.rawValue) }
            }
        }
    }

    // MARK: - Helper Methods

    private func addError(_ category: String, _ message: String, file: String? = nil, line: Int? = nil) {
        results.append(ValidationResult(severity: .error, category: category, message: message, file: file, line: line))
    }

    private func addWarning(_ category: String, _ message: String, file: String? = nil, line: Int? = nil) {
        results.append(ValidationResult(severity: .warning, category: category, message: message, file: file, line: line))
    }

    private func addInfo(_ category: String, _ message: String, file: String? = nil, line: Int? = nil) {
        results.append(ValidationResult(severity: .info, category: category, message: message, file: file, line: line))
    }
}

// MARK: - CLI Support

extension PackValidator {
    /// Run validation and print results to console (DEBUG only)
    public static func validateAndPrint(packURL: URL) -> Bool {
        let validator = PackValidator(packURL: packURL)
        let summary = validator.validate()
        #if DEBUG
        print(summary.description)
        #endif
        return summary.isValid
    }

    /// Validate multiple packs (DEBUG only for console output)
    public static func validateMultiple(packURLs: [URL]) -> Bool {
        var allValid = true

        for url in packURLs {
            #if DEBUG
            print("\n" + String(repeating: "=", count: 60))
            #endif
            let isValid = validateAndPrint(packURL: url)
            allValid = allValid && isValid
        }

        #if DEBUG
        print("\n" + String(repeating: "=", count: 60))
        print(allValid ? "ALL PACKS VALID" : "SOME PACKS HAVE ERRORS")
        #endif

        return allValid
    }
}
