/// Файл: Packages/TwilightEngine/Sources/TwilightEngine/ContentPacks/ExpressionParser.swift
/// Назначение: Содержит реализацию файла ExpressionParser.swift.
/// Зона ответственности: Реализует контракт движка TwilightEngine в пределах модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation

// MARK: - Expression Parser
// Validates string-based condition expressions in pack content.
// Ensures no typos in variable names or unknown functions.
// Reference: Audit v2.1, Section 3.1

/// Parses and validates condition expression strings from pack content.
/// Rejects unknown variables and functions at load time to prevent silent content defects.
public final class ExpressionParser {

    // MARK: - Known Variables

    /// Whitelisted variable names that can appear in condition expressions
    public static let knownVariables: Set<String> = [
        // World state
        "WorldTension", "worldTension",
        "LightDarkBalance", "lightDarkBalance",
        "CurrentDay", "currentDay",
        "WorldResonance", "worldResonance",

        // Player state
        "PlayerHealth", "playerHealth",
        "PlayerMaxHealth", "playerMaxHealth",
        "PlayerFaith", "playerFaith",
        "PlayerMaxFaith", "playerMaxFaith",
        "PlayerBalance", "playerBalance",

        // Region state
        "RegionState", "regionState",
        "RegionType", "regionType",

        // Quest state
        "MainQuestStage", "mainQuestStage",

        // Deck state
        "DeckSize", "deckSize",
        "HandSize", "handSize",
        "DiscardSize", "discardSize"
    ]

    // MARK: - Known Functions

    /// Whitelisted function names that can appear in condition expressions
    public static let knownFunctions: Set<String> = [
        "hasFlag",
        "notFlag",
        "hasQuest",
        "completedQuest",
        "visitedRegion",
        "hasCard",
        "hasAbility",
        "regionIs",
        "dayIs",
        "random"
    ]

    // MARK: - Errors

    /// Errors produced during expression parsing
    public enum ExpressionError: Error, Equatable {
        case invalidSyntax(String)
        case unknownVariable(String)
        case unknownFunction(String)
        case emptyExpression
    }

    // MARK: - Validation

    /// Validate a condition expression string.
    /// Returns nil if valid, or an ExpressionError if invalid.
    public static func validate(_ expression: String) -> ExpressionError? {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .emptyExpression
        }

        // Tokenize the expression
        let tokens = tokenize(trimmed)

        // Check each identifier token against known variables and functions
        for token in tokens {
            switch token {
            case .identifier(let name):
                if !knownVariables.contains(name) && !knownFunctions.contains(name) {
                    return .unknownVariable(name)
                }
            case .function(let name):
                if !knownFunctions.contains(name) {
                    return .unknownFunction(name)
                }
            case .operator_, .number, .string, .boolean, .paren:
                continue
            case .invalid(let text):
                return .invalidSyntax("Invalid token: \(text)")
            }
        }

        return nil // Valid
    }

    /// Validate all condition expressions in a collection.
    /// Returns array of (expression, error) pairs for invalid ones.
    public static func validateAll(_ expressions: [String]) -> [(String, ExpressionError)] {
        var errors: [(String, ExpressionError)] = []
        for expr in expressions {
            if let error = validate(expr) {
                errors.append((expr, error))
            }
        }
        return errors
    }

    // MARK: - Tokenization

    enum Token {
        case identifier(String)
        case function(String)
        case number(String)
        case string(String)
        case boolean(String)
        case operator_(String)
        case paren(String)
        case invalid(String)
    }

    static func tokenize(_ expression: String) -> [Token] {
        var tokens: [Token] = []
        var remaining = expression[expression.startIndex...]

        let operators: Set<String> = ["<", ">", "<=", ">=", "==", "!=", "&&", "||", "!", "+", "-", "*", "/"]

        while !remaining.isEmpty {
            // Skip whitespace
            if let first = remaining.first, first.isWhitespace {
                remaining = remaining.drop(while: { $0.isWhitespace })
                continue
            }

            guard let first = remaining.first else { break }

            // Parentheses
            if first == "(" || first == ")" {
                tokens.append(.paren(String(first)))
                remaining = remaining.dropFirst()
                continue
            }

            // String literals
            if first == "\"" {
                remaining = remaining.dropFirst()
                if let endQuote = remaining.firstIndex(of: "\"") {
                    let content = String(remaining[remaining.startIndex..<endQuote])
                    tokens.append(.string(content))
                    remaining = remaining[remaining.index(after: endQuote)...]
                } else {
                    tokens.append(.invalid("Unterminated string"))
                    break
                }
                continue
            }

            // Numbers (including negative)
            if first.isNumber || (first == "-" && remaining.dropFirst().first?.isNumber == true) {
                let numChars = remaining.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" })
                tokens.append(.number(String(numChars)))
                remaining = remaining.dropFirst(numChars.count)
                continue
            }

            // Two-char operators
            if remaining.count >= 2 {
                let twoChar = String(remaining.prefix(2))
                if operators.contains(twoChar) {
                    tokens.append(.operator_(twoChar))
                    remaining = remaining.dropFirst(2)
                    continue
                }
            }

            // Single-char operators
            if operators.contains(String(first)) {
                tokens.append(.operator_(String(first)))
                remaining = remaining.dropFirst()
                continue
            }

            // Identifiers (variable names, function names, booleans)
            if first.isLetter || first == "_" {
                let ident = remaining.prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" })
                let name = String(ident)
                remaining = remaining.dropFirst(ident.count)

                // Check for boolean literals
                if name == "true" || name == "false" {
                    tokens.append(.boolean(name))
                }
                // Check if followed by '(' — it's a function call
                else if remaining.first == "(" {
                    tokens.append(.function(name))
                }
                else {
                    tokens.append(.identifier(name))
                }
                continue
            }

            // Comma (used in function args)
            if first == "," {
                remaining = remaining.dropFirst()
                continue
            }

            // Unknown character
            tokens.append(.invalid(String(first)))
            remaining = remaining.dropFirst()
        }

        return tokens
    }
}
