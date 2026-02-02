import Foundation
import TwilightEngine
import PackAuthoring

/// Result of scanning a directory for content packs.
public struct PackScanResult: Identifiable, Equatable {
    public let id: String  // packId
    public let displayName: String
    public let packType: PackType
    public let version: SemanticVersion
    public let url: URL
}

/// Scans directory trees for content packs by locating manifest.json files.
public enum PackScanner {
    public static func scan(roots: [URL]) -> [PackScanResult] {
        var results: [PackScanResult] = []
        let fm = FileManager.default
        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let fileURL as URL in enumerator {
                guard fileURL.lastPathComponent == "manifest.json" else { continue }
                let packDir = fileURL.deletingLastPathComponent()
                guard let manifest = try? PackManifest.load(from: packDir) else { continue }
                results.append(PackScanResult(
                    id: manifest.packId,
                    displayName: manifest.displayName.en,
                    packType: manifest.packType,
                    version: manifest.version,
                    url: packDir
                ))
            }
        }
        return results.sorted { $0.id < $1.id }
    }
}
