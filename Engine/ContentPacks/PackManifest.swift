import Foundation

// MARK: - Pack Manifest

/// Metadata describing a content pack
/// This is the entry point for pack loading - every pack must have a manifest
struct PackManifest: Codable {
    // MARK: - Identity

    /// Unique pack identifier (e.g., "twilight-marches-act1")
    let packId: String

    /// Human-readable display name
    let displayName: LocalizedString

    /// Pack description
    let description: LocalizedString

    /// Pack version
    let version: SemanticVersion

    /// Type of content this pack provides
    let packType: PackType

    // MARK: - Compatibility

    /// Minimum required Core engine version
    let coreVersionMin: SemanticVersion

    /// Maximum tested Core version (nil = any future version)
    let coreVersionMax: SemanticVersion?

    /// Required dependencies on other packs
    let dependencies: [PackDependency]

    /// Capabilities this pack requires from Core (for rules extensions)
    let requiredCapabilities: [String]

    // MARK: - Content Entry Points

    /// Starting region ID for campaign packs
    let entryRegionId: String?

    /// Starting quest ID for campaign packs
    let entryQuestId: String?

    /// Recommended hero IDs for this campaign
    let recommendedHeroes: [String]

    // MARK: - Metadata

    /// Pack author/publisher
    let author: String

    /// License identifier
    let license: String?

    /// Release date
    let releaseDate: Date?

    /// Supported locales
    let supportedLocales: [String]

    /// File checksums for integrity verification
    let checksums: [String: String]?

    // MARK: - Content Paths (relative to pack root)

    /// Path to regions content
    let regionsPath: String?

    /// Path to events content
    let eventsPath: String?

    /// Path to quests content
    let questsPath: String?

    /// Path to anchors content
    let anchorsPath: String?

    /// Path to heroes content
    let heroesPath: String?

    /// Path to hero abilities content
    let abilitiesPath: String?

    /// Path to cards content
    let cardsPath: String?

    /// Path to enemies content
    let enemiesPath: String?

    /// Path to balance configuration
    let balancePath: String?

    /// Path to localization files
    let localizationPath: String?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case packId = "id"
        case displayName = "name"
        case description
        case version
        case packType = "type"
        case coreVersionMin = "core_version_min"
        case coreVersionMax = "core_version_max"
        case dependencies
        case requiredCapabilities = "required_capabilities"
        case entryRegionId = "entry_region"
        case entryQuestId = "entry_quest"
        case recommendedHeroes = "recommended_heroes"
        case author
        case license
        case releaseDate = "release_date"
        case supportedLocales = "locales"
        case checksums
        case regionsPath = "regions_path"
        case eventsPath = "events_path"
        case questsPath = "quests_path"
        case anchorsPath = "anchors_path"
        case heroesPath = "heroes_path"
        case abilitiesPath = "abilities_path"
        case cardsPath = "cards_path"
        case enemiesPath = "enemies_path"
        case balancePath = "balance_path"
        case localizationPath = "localization_path"
    }

    // MARK: - Initialization

    init(
        packId: String,
        displayName: LocalizedString,
        description: LocalizedString,
        version: SemanticVersion,
        packType: PackType,
        coreVersionMin: SemanticVersion,
        coreVersionMax: SemanticVersion? = nil,
        dependencies: [PackDependency] = [],
        requiredCapabilities: [String] = [],
        entryRegionId: String? = nil,
        entryQuestId: String? = nil,
        recommendedHeroes: [String] = [],
        author: String,
        license: String? = nil,
        releaseDate: Date? = nil,
        supportedLocales: [String] = ["en"],
        checksums: [String: String]? = nil,
        regionsPath: String? = nil,
        eventsPath: String? = nil,
        questsPath: String? = nil,
        anchorsPath: String? = nil,
        heroesPath: String? = nil,
        abilitiesPath: String? = nil,
        cardsPath: String? = nil,
        enemiesPath: String? = nil,
        balancePath: String? = nil,
        localizationPath: String? = nil
    ) {
        self.packId = packId
        self.displayName = displayName
        self.description = description
        self.version = version
        self.packType = packType
        self.coreVersionMin = coreVersionMin
        self.coreVersionMax = coreVersionMax
        self.dependencies = dependencies
        self.requiredCapabilities = requiredCapabilities
        self.entryRegionId = entryRegionId
        self.entryQuestId = entryQuestId
        self.recommendedHeroes = recommendedHeroes
        self.author = author
        self.license = license
        self.releaseDate = releaseDate
        self.supportedLocales = supportedLocales
        self.checksums = checksums
        self.regionsPath = regionsPath
        self.eventsPath = eventsPath
        self.questsPath = questsPath
        self.anchorsPath = anchorsPath
        self.heroesPath = heroesPath
        self.abilitiesPath = abilitiesPath
        self.cardsPath = cardsPath
        self.enemiesPath = enemiesPath
        self.balancePath = balancePath
        self.localizationPath = localizationPath
    }

    // MARK: - Validation

    /// Validate manifest structure
    func validate() -> [ContentValidationError] {
        var errors: [ContentValidationError] = []

        // Check required fields
        if packId.isEmpty {
            errors.append(ContentValidationError(
                type: .missingRequired,
                definitionId: "manifest",
                message: "Pack ID is required"
            ))
        }

        if displayName.localized.isEmpty {
            errors.append(ContentValidationError(
                type: .missingRequired,
                definitionId: "manifest",
                message: "Display name is required"
            ))
        }

        // Validate pack ID format (lowercase, alphanumeric, hyphens)
        let validIdPattern = "^[a-z0-9][a-z0-9-]*[a-z0-9]$"
        if !packId.isEmpty,
           let regex = try? NSRegularExpression(pattern: validIdPattern),
           regex.firstMatch(in: packId, range: NSRange(packId.startIndex..., in: packId)) == nil {
            errors.append(ContentValidationError(
                type: .invalidRange,
                definitionId: "manifest.packId",
                message: "Pack ID must be lowercase alphanumeric with hyphens"
            ))
        }

        // Validate locales
        if supportedLocales.isEmpty {
            errors.append(ContentValidationError(
                type: .missingRequired,
                definitionId: "manifest.locales",
                message: "At least one locale must be supported"
            ))
        }

        // Campaign packs should have entry points (informational)
        // Note: This is a warning, not a blocking error

        return errors
    }

    /// Check if this pack is compatible with current Core version
    func isCompatibleWithCore() -> Bool {
        let current = CoreVersion.current

        // Must meet minimum requirement
        guard current >= coreVersionMin else { return false }

        // If max is specified, must not exceed it
        if let max = coreVersionMax, current > max {
            return false
        }

        return true
    }
}

// MARK: - Manifest File Loading

extension PackManifest {
    /// Standard manifest filename
    static let filename = "manifest.json"

    /// Custom date formatter that handles both "2026-01-01" and "2026-01-01T00:00:00Z"
    private static let flexibleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Load manifest from URL
    static func load(from url: URL) throws -> PackManifest {
        let manifestURL = url.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PackLoadError.manifestNotFound(path: manifestURL.path)
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            // Use custom strategy that handles both date-only and ISO8601 formats
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Try ISO8601 first
                if let date = ISO8601DateFormatter().date(from: dateString) {
                    return date
                }

                // Fallback to date-only format "yyyy-MM-dd"
                if let date = flexibleDateFormatter.date(from: dateString) {
                    return date
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(dateString)"
                )
            }
            return try decoder.decode(PackManifest.self, from: data)
        } catch let error as DecodingError {
            throw PackLoadError.invalidManifest(reason: error.localizedDescription)
        }
    }

    /// Save manifest to URL
    func save(to url: URL) throws {
        let manifestURL = url.appendingPathComponent(Self.filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: manifestURL)
    }
}
