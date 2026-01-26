import Foundation
import TwilightEngine

// MARK: - Pack Compiler CLI Tool
// Compiles JSON content packs to binary .pack format

/// Print usage information
func printUsage() {
    let programName = CommandLine.arguments[0].components(separatedBy: "/").last ?? "pack-compiler"
    print("""
    Usage: \(programName) <command> [options]

    Commands:
        compile <source-dir> <output-file>
            Compile a JSON pack directory to .pack binary file

        validate <source-dir>
            Validate a JSON pack without compiling

        info <pack-file>
            Show information about a compiled .pack file

        compile-all <packs-dir> [--output-dir <dir>]
            Compile all packs in a directory

    Examples:
        \(programName) compile ./CoreHeroes ./CoreHeroes.pack
        \(programName) validate ./TwilightMarchesActI
        \(programName) info ./CoreHeroes.pack
    """)
}

/// Compile a single pack
func compilePack(source: String, output: String) {
    let sourceURL = URL(fileURLWithPath: source)
    let outputURL = URL(fileURLWithPath: output)

    print("Compiling: \(sourceURL.lastPathComponent) -> \(outputURL.lastPathComponent)")

    do {
        let result = try PackCompiler.compile(from: sourceURL, to: outputURL)
        print(result.summary)
        print("✅ Compilation successful!")
    } catch {
        print("❌ Compilation failed: \(error)")
        exit(1)
    }
}

/// Validate a pack
func validatePack(source: String) {
    let sourceURL = URL(fileURLWithPath: source)

    print("Validating: \(sourceURL.lastPathComponent)")

    do {
        let result = try PackCompiler.validate(at: sourceURL)
        print(result.summary)
        exit(result.isValid ? 0 : 1)
    } catch {
        print("❌ Validation failed: \(error)")
        exit(1)
    }
}

/// Show pack info
func showPackInfo(packFile: String) {
    let packURL = URL(fileURLWithPath: packFile)

    print("Reading: \(packURL.lastPathComponent)")

    do {
        let content = try BinaryPackReader.loadContent(from: packURL)
        let manifest = content.manifest

        print("""

        Pack Information:
        ─────────────────
        ID: \(manifest.packId)
        Version: \(manifest.version)
        Type: \(manifest.packType.rawValue)
        Core Version: \(manifest.coreVersionMin)+

        Content:
        ─────────────────
        Regions: \(content.regions.count)
        Events: \(content.events.count)
        Quests: \(content.quests.count)
        Anchors: \(content.anchors.count)
        Heroes: \(content.heroes.count)
        Cards: \(content.cards.count)
        Enemies: \(content.enemies.count)
        Abilities: \(content.abilities.count)
        """)

        // File size
        let attributes = try FileManager.default.attributesOfItem(atPath: packFile)
        if let fileSize = attributes[.size] as? Int64 {
            let sizeKB = Double(fileSize) / 1024
            print("File Size: \(String(format: "%.1f", sizeKB)) KB")
        }

    } catch {
        print("❌ Failed to read pack: \(error)")
        exit(1)
    }
}

/// Compile all packs in directory
func compileAllPacks(packsDir: String, outputDir: String?) {
    let packsDirURL = URL(fileURLWithPath: packsDir)
    let outputDirURL = outputDir.map { URL(fileURLWithPath: $0) } ?? packsDirURL

    do {
        let contents = try FileManager.default.contentsOfDirectory(
            at: packsDirURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        var compiledCount = 0
        var failedCount = 0

        for item in contents {
            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues.isDirectory == true else { continue }

            // Check if directory has manifest.json
            let manifestURL = item.appendingPathComponent("manifest.json")
            guard FileManager.default.fileExists(atPath: manifestURL.path) else { continue }

            let packName = item.lastPathComponent
            let outputURL = outputDirURL.appendingPathComponent("\(packName).pack")

            print("\nCompiling: \(packName)")

            do {
                let result = try PackCompiler.compile(from: item, to: outputURL)
                print("  ✅ \(result.contentStats.summary)")
                compiledCount += 1
            } catch {
                print("  ❌ Failed: \(error)")
                failedCount += 1
            }
        }

        print("\n═══════════════════════════════════")
        print("Compiled: \(compiledCount) packs")
        if failedCount > 0 {
            print("Failed: \(failedCount) packs")
            exit(1)
        }

    } catch {
        print("❌ Failed to scan directory: \(error)")
        exit(1)
    }
}

// MARK: - Main

let args = CommandLine.arguments

guard args.count >= 2 else {
    printUsage()
    exit(0)
}

let command = args[1]

switch command {
case "compile":
    guard args.count >= 4 else {
        print("Error: compile requires <source-dir> and <output-file>")
        exit(1)
    }
    compilePack(source: args[2], output: args[3])

case "validate":
    guard args.count >= 3 else {
        print("Error: validate requires <source-dir>")
        exit(1)
    }
    validatePack(source: args[2])

case "info":
    guard args.count >= 3 else {
        print("Error: info requires <pack-file>")
        exit(1)
    }
    showPackInfo(packFile: args[2])

case "compile-all":
    guard args.count >= 3 else {
        print("Error: compile-all requires <packs-dir>")
        exit(1)
    }
    var outputDir: String? = nil
    if args.count >= 5 && args[3] == "--output-dir" {
        outputDir = args[4]
    }
    compileAllPacks(packsDir: args[2], outputDir: outputDir)

case "-h", "--help", "help":
    printUsage()

default:
    print("Unknown command: \(command)")
    printUsage()
    exit(1)
}
