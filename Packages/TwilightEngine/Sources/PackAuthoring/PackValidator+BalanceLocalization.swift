/// Файл: Packages/TwilightEngine/Sources/PackAuthoring/PackValidator+BalanceLocalization.swift
/// Назначение: Содержит реализацию файла PackValidator+BalanceLocalization.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine

extension PackValidator {
    // MARK: - Phase 5: Balance Validation

    func validateBalanceConfig() {
        guard let pack = loadedPack, let balance = pack.balanceConfig else { return }

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

        if balance.pressure.maxPressure <= 0 {
            addError("Balance", "maxPressure must be positive: \(balance.pressure.maxPressure)")
        }

        if balance.pressure.startingPressure < 0 {
            addWarning("Balance", "startingPressure is negative: \(balance.pressure.startingPressure)")
        }

        if balance.pressure.startingPressure > balance.pressure.maxPressure {
            addError("Balance", "startingPressure (\(balance.pressure.startingPressure)) exceeds maxPressure (\(balance.pressure.maxPressure))")
        }

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

    func validateLocalization(_ pack: LoadedPack) {
        guard let manifest = manifest else { return }

        var referencedKeys = Set<String>()
        collectStringKeys(from: pack, into: &referencedKeys)

        guard let locPath = manifest.localizationPath else {
            if referencedKeys.isEmpty {
                addInfo("Localization", "Pack uses inline LocalizedString (legacy mode)")
            } else {
                addError("Localization", "Pack uses \(referencedKeys.count) StringKey references but has no localizationPath in manifest")
            }
            return
        }

        let locURL = packURL.appendingPathComponent(locPath)
        var allTableKeys: [String: Set<String>] = [:]

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

        let englishKeys = allTableKeys["en"] ?? []
        for (locale, localeKeys) in allTableKeys {
            let missingReferenced = referencedKeys.subtracting(localeKeys)
            for key in missingReferenced.sorted().prefix(10) {
                addWarning("Localization", "StringKey '\(key)' referenced in content but not found in \(locale).json")
            }
            if missingReferenced.count > 10 {
                addWarning("Localization", "... and \(missingReferenced.count - 10) more missing keys in \(locale).json")
            }

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

    func collectStringKeys(from pack: LoadedPack, into keys: inout Set<String>) {
        for (_, region) in pack.regions {
            if case .key(let key) = region.title { keys.insert(key.rawValue) }
            if case .key(let key) = region.description { keys.insert(key.rawValue) }
        }

        for (_, event) in pack.events {
            if case .key(let key) = event.title { keys.insert(key.rawValue) }
            if case .key(let key) = event.body { keys.insert(key.rawValue) }
            for choice in event.choices {
                if case .key(let key) = choice.label { keys.insert(key.rawValue) }
                if let tooltip = choice.tooltip, case .key(let key) = tooltip { keys.insert(key.rawValue) }
            }
        }

        for (_, hero) in pack.heroes {
            if case .key(let key) = hero.name { keys.insert(key.rawValue) }
            if case .key(let key) = hero.description { keys.insert(key.rawValue) }
            if case .key(let key) = hero.specialAbility.name { keys.insert(key.rawValue) }
            if case .key(let key) = hero.specialAbility.description { keys.insert(key.rawValue) }
        }

        for (_, card) in pack.cards {
            if case .key(let key) = card.name { keys.insert(key.rawValue) }
            if case .key(let key) = card.description { keys.insert(key.rawValue) }
        }

        for (_, enemy) in pack.enemies {
            if case .key(let key) = enemy.name { keys.insert(key.rawValue) }
            if case .key(let key) = enemy.description { keys.insert(key.rawValue) }
            for ability in enemy.abilities {
                if case .key(let key) = ability.name { keys.insert(key.rawValue) }
                if case .key(let key) = ability.description { keys.insert(key.rawValue) }
            }
        }

        for (_, anchor) in pack.anchors {
            if case .key(let key) = anchor.title { keys.insert(key.rawValue) }
            if case .key(let key) = anchor.description { keys.insert(key.rawValue) }
        }

        for (_, quest) in pack.quests {
            if case .key(let key) = quest.title { keys.insert(key.rawValue) }
            if case .key(let key) = quest.description { keys.insert(key.rawValue) }
            for objective in quest.objectives {
                if case .key(let key) = objective.description { keys.insert(key.rawValue) }
                if let hint = objective.hint, case .key(let key) = hint { keys.insert(key.rawValue) }
            }
        }
    }

    // MARK: - Helpers

    func addError(_ category: String, _ message: String, file: String? = nil, line: Int? = nil) {
        results.append(ValidationResult(severity: .error, category: category, message: message, file: file, line: line))
    }

    func addWarning(_ category: String, _ message: String, file: String? = nil, line: Int? = nil) {
        results.append(ValidationResult(severity: .warning, category: category, message: message, file: file, line: line))
    }

    func addInfo(_ category: String, _ message: String, file: String? = nil, line: Int? = nil) {
        results.append(ValidationResult(severity: .info, category: category, message: message, file: file, line: line))
    }
}
