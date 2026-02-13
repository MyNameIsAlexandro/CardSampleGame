/// Файл: Packages/TwilightEngine/Sources/PackAuthoring/PackValidator+ManifestStructure.swift
/// Назначение: Содержит реализацию файла PackValidator+ManifestStructure.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine

extension PackValidator {
    // MARK: - Phase 1: Manifest Validation

    func validateManifest() {
        let manifestURL = packURL.appendingPathComponent("manifest.json")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            addError("Manifest", "manifest.json not found at pack root")
            return
        }

        do {
            manifest = try PackManifest.load(from: packURL)
        } catch {
            addError("Manifest", "Failed to parse manifest.json: \(error.localizedDescription)")
            return
        }

        guard let manifest = manifest else { return }

        if manifest.packId.isEmpty {
            addError("Manifest", "packId is required")
        }

        if manifest.packId.contains(" ") {
            addWarning("Manifest", "packId should not contain spaces: '\(manifest.packId)'")
        }

        if manifest.displayName.en.isEmpty {
            addError("Manifest", "displayName.en is required")
        }

        if manifest.version.major == 0 && manifest.version.minor == 0 && manifest.version.patch == 0 {
            addWarning("Manifest", "Version 0.0.0 suggests pack is not properly versioned")
        }

        if !manifest.isCompatibleWithCore() {
            addError("Manifest", "Pack requires Core version \(manifest.coreVersionMin), but current is \(CoreVersion.current)")
        }

        if manifest.packType == .campaign || manifest.packType == .full {
            if manifest.entryRegionId == nil {
                addWarning("Manifest", "Campaign pack should specify entryRegionId")
            }
        }

        validateManifestPaths(manifest)
        addInfo("Manifest", "Loaded pack '\(manifest.packId)' v\(manifest.version)")
    }

    func validateManifestPaths(_ manifest: PackManifest) {
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

    func validateFileStructure() {
        guard let manifest = manifest else { return }

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
            break
        }

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

    func checkDirectory(_ name: String, _ path: String?) {
        guard let path = path else {
            addWarning("Structure", "\(name) path not specified in manifest")
            return
        }

        let fullPath = packURL.appendingPathComponent(path)
        var isDirectory: ObjCBool = false

        if !FileManager.default.fileExists(atPath: fullPath.path, isDirectory: &isDirectory) {
            addWarning("Structure", "\(name) directory not found: \(path)")
        } else if !isDirectory.boolValue {
            if !fullPath.pathExtension.isEmpty {
                addInfo("Structure", "\(name) is a file: \(path)")
            }
        }
    }
}
