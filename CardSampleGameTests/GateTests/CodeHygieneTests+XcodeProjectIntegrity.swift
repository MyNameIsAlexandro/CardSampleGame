/// Файл: CardSampleGameTests/GateTests/CodeHygieneTests+XcodeProjectIntegrity.swift
/// Назначение: Содержит реализацию файла CodeHygieneTests+XcodeProjectIntegrity.swift.
/// Зона ответственности: Фиксирует проверяемый контракт и не содержит production-логики.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import XCTest
@testable import CardSampleGame

extension CodeHygieneTests {

    func testXcodeProjectHasNoDanglingObjectReferences() throws {
        let content = try loadPbxprojContent()

        let allObjectIDs = extractAllObjectIDs(from: content)

        var referencedIDs = Set<String>()
        referencedIDs.formUnion(extractArrayIDs(inSection: "PBXGroup", arrayKey: "children", from: content))
        referencedIDs.formUnion(extractArrayIDs(inSection: "PBXVariantGroup", arrayKey: "children", from: content))
        referencedIDs.formUnion(extractArrayIDs(inSection: "PBXSourcesBuildPhase", arrayKey: "files", from: content))
        referencedIDs.formUnion(extractArrayIDs(inSection: "PBXResourcesBuildPhase", arrayKey: "files", from: content))
        referencedIDs.formUnion(extractArrayIDs(inSection: "PBXFrameworksBuildPhase", arrayKey: "files", from: content))
        referencedIDs.formUnion(extractBuildFileLinkedIDs(from: content))

        let missing = referencedIDs.subtracting(allObjectIDs)
        XCTAssertTrue(
            missing.isEmpty,
            """
            Xcode project integrity failure: found \(missing.count) dangling object references in project.pbxproj.
            First 25 missing IDs:
            \(missing.sorted().prefix(25).joined(separator: "\n"))
            """
        )
    }

    private func extractAllObjectIDs(from content: String) -> Set<String> {
        var ids = Set<String>()

        for rawLine in content.split(separator: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.contains("/*") else { continue }
            guard trimmed.contains(" = {") else { continue }

            guard let firstSpace = trimmed.firstIndex(of: " ") else { continue }
            let id = String(trimmed[..<firstSpace])
            ids.insert(id)
        }

        return ids
    }

    private func extractArrayIDs(inSection sectionName: String, arrayKey: String, from content: String) -> Set<String> {
        guard let section = sliceSection(named: sectionName, from: content) else { return [] }

        var ids = Set<String>()
        var inside = false

        for rawLine in section.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("\(arrayKey) = (") {
                inside = true
                continue
            }

            if inside && trimmed.hasPrefix(");") {
                inside = false
                continue
            }

            guard inside else { continue }
            guard let first = trimmed.first, (first.isLetter || first.isNumber) else { continue }

            let token = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "," || $0 == ";" }).first
            if let token {
                ids.insert(String(token))
            }
        }

        return ids
    }

    private func extractBuildFileLinkedIDs(from content: String) -> Set<String> {
        guard let section = sliceSection(named: "PBXBuildFile", from: content) else { return [] }

        var ids = Set<String>()

        for rawLine in section.split(separator: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.contains("isa = PBXBuildFile") else { continue }

            if let fileRef = captureToken(after: "fileRef = ", in: trimmed) {
                ids.insert(fileRef)
            }
            if let productRef = captureToken(after: "productRef = ", in: trimmed) {
                ids.insert(productRef)
            }
        }

        return ids
    }

    private func sliceSection(named sectionName: String, from content: String) -> String? {
        let begin = "/* Begin \(sectionName) section */"
        let end = "/* End \(sectionName) section */"

        guard let beginRange = content.range(of: begin) else { return nil }
        guard let endRange = content.range(of: end) else { return nil }
        guard beginRange.upperBound < endRange.lowerBound else { return nil }

        return String(content[beginRange.upperBound..<endRange.lowerBound])
    }

    private func captureToken(after marker: String, in line: String) -> String? {
        guard let range = line.range(of: marker) else { return nil }
        let rest = line[range.upperBound...]
        let token = rest.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == ";" }).first
        return token.map(String.init)
    }

    func findFile(named name: String, in directory: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == name {
            return fileURL.path
        }
        return nil
    }

    func findSwiftFiles(in directory: URL) -> [String] {
        var files: [String] = []
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return files }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            files.append(fileURL.path)
        }
        return files
    }

    func makeRelativePath(filePath: String, projectRoot: URL) -> String {
        let rootPath = projectRoot.path.hasSuffix("/") ? projectRoot.path : projectRoot.path + "/"
        if filePath.hasPrefix(rootPath) {
            return String(filePath.dropFirst(rootPath.count))
        }
        return filePath
    }

    /// Find public methods without preceding /// doc comment.
    func findUndocumentedPublicMethods(in content: String) -> [String] {
        var undocumented: [String] = []
        let lines = content.components(separatedBy: .newlines)
        let methodPattern = #"^\s*public\s+(static\s+)?func\s+(\w+)"#
        let methodRegex = try? NSRegularExpression(pattern: methodPattern)
        let attributePattern = #"^\s*@\w+"#

        for (index, line) in lines.enumerated() {
            guard let regex = methodRegex,
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            if let nameRange = Range(match.range(at: 2), in: line) {
                let methodName = String(line[nameRange])
                var prevIndex = index - 1
                var foundDocComment = false

                while prevIndex >= 0 {
                    let prevLine = lines[prevIndex].trimmingCharacters(in: .whitespaces)
                    if prevLine.isEmpty {
                        prevIndex -= 1
                        continue
                    }
                    if prevLine.range(of: attributePattern, options: .regularExpression) != nil {
                        prevIndex -= 1
                        continue
                    }
                    if prevLine.hasPrefix("///") || prevLine.hasPrefix("*/") {
                        foundDocComment = true
                    }
                    break
                }

                if !foundDocComment {
                    undocumented.append(methodName + "()")
                }
            }
        }

        return undocumented
    }

    /// Find public properties without preceding /// doc comment.
    func findUndocumentedPublicProperties(in content: String) -> [String] {
        var undocumented: [String] = []
        let lines = content.components(separatedBy: .newlines)
        let propPattern = #"^\s*public\s+(static\s+)?(let|var)\s+(\w+)"#
        let propRegex = try? NSRegularExpression(pattern: propPattern)
        let attributePattern = #"^\s*@\w+"#

        for (index, line) in lines.enumerated() {
            guard let regex = propRegex,
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            if line.contains("{") && line.contains("return") {
                continue
            }

            if let nameRange = Range(match.range(at: 3), in: line) {
                let propName = String(line[nameRange])
                var prevIndex = index - 1
                var foundDocComment = false

                while prevIndex >= 0 {
                    let prevLine = lines[prevIndex].trimmingCharacters(in: .whitespaces)
                    if prevLine.isEmpty {
                        prevIndex -= 1
                        continue
                    }
                    if prevLine.range(of: attributePattern, options: .regularExpression) != nil {
                        prevIndex -= 1
                        continue
                    }
                    if prevLine.hasPrefix("///") || prevLine.hasPrefix("*/") {
                        foundDocComment = true
                    }
                    break
                }

                if !foundDocComment {
                    undocumented.append(propName)
                }
            }
        }

        return undocumented
    }

    /// Find top-level type declarations (class, struct, enum, protocol, actor) in a Swift file.
    func findTopLevelTypeDeclarations(in content: String) -> [String] {
        var types: [String] = []
        let typePattern = #"^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:(public|open|internal|fileprivate|private)\s+)?(?:final\s+)?(?:indirect\s+)?(class|struct|enum|protocol|actor)\s+([A-Za-z_]\w*)\b"#
        let typeRegex = try? NSRegularExpression(pattern: typePattern)

        var braceDepth = 0
        var blockCommentDepth = 0
        var inMultilineString = false

        for rawLine in content.components(separatedBy: .newlines) {
            let line = sanitizeCodeLine(
                rawLine,
                blockCommentDepth: &blockCommentDepth,
                inMultilineString: &inMultilineString
            )

            if braceDepth == 0, blockCommentDepth == 0, !inMultilineString {
                if let regex = typeRegex,
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let nameRange = Range(match.range(at: 3), in: line) {
                    types.append(String(line[nameRange]))
                }
            }

            braceDepth += line.filter { $0 == "{" }.count
            braceDepth -= line.filter { $0 == "}" }.count
            if braceDepth < 0 { braceDepth = 0 }
        }

        return types
    }

    func sanitizeCodeLine(
        _ line: String,
        blockCommentDepth: inout Int,
        inMultilineString: inout Bool
    ) -> String {
        var result = ""
        var i = line.startIndex
        var inSingleLineString = false

        func advance(_ count: Int = 1) {
            i = line.index(i, offsetBy: count, limitedBy: line.endIndex) ?? line.endIndex
        }

        while i < line.endIndex {
            let ch = line[i]

            if inMultilineString {
                if line[i...].hasPrefix("\"\"\"") {
                    inMultilineString = false
                    advance(3)
                } else {
                    advance()
                }
                continue
            }

            if blockCommentDepth > 0 {
                if line[i...].hasPrefix("/*") {
                    blockCommentDepth += 1
                    advance(2)
                    continue
                }
                if line[i...].hasPrefix("*/") {
                    blockCommentDepth -= 1
                    advance(2)
                    continue
                }
                advance()
                continue
            }

            if inSingleLineString {
                if ch == "\\" {
                    advance(2)
                    continue
                }
                if ch == "\"" {
                    inSingleLineString = false
                }
                advance()
                continue
            }

            if line[i...].hasPrefix("//") {
                break
            }
            if line[i...].hasPrefix("/*") {
                blockCommentDepth += 1
                advance(2)
                continue
            }
            if line[i...].hasPrefix("\"\"\"") {
                inMultilineString = true
                advance(3)
                continue
            }
            if ch == "\"" {
                inSingleLineString = true
                advance()
                continue
            }

            result.append(ch)
            advance()
        }

        return result
    }
}
