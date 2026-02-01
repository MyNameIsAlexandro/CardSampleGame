import TwilightEngine

/// Rich result from drawing and resolving a Fate Card with keyword interpretation.
public struct FateResolution {
    public let card: FateCard
    public let effectiveValue: Int
    public let keyword: FateKeyword?
    public let keywordEffect: KeywordEffect
    public let suitMatch: Bool
    public let isCritical: Bool
    public let drawEffects: [FateDrawEffect]
    public let appliedRule: FateResonanceRule?

    public init(
        card: FateCard,
        effectiveValue: Int,
        keyword: FateKeyword?,
        keywordEffect: KeywordEffect,
        suitMatch: Bool,
        isCritical: Bool,
        drawEffects: [FateDrawEffect],
        appliedRule: FateResonanceRule?
    ) {
        self.card = card
        self.effectiveValue = effectiveValue
        self.keyword = keyword
        self.keywordEffect = keywordEffect
        self.suitMatch = suitMatch
        self.isCritical = isCritical
        self.drawEffects = drawEffects
        self.appliedRule = appliedRule
    }
}

/// Draws a fate card and resolves it with full keyword interpretation and suit matching.
public struct FateResolutionService {

    public init() {}

    /// Determine if card suit matches the action context alignment.
    /// Nav suit → combatPhysical, Prav suit → combatSpiritual, Yav → neutral (no match/mismatch).
    public static func suitMatches(suit: FateCardSuit?, context: ActionContext) -> Bool {
        switch (suit, context) {
        case (.nav, .combatPhysical): return true
        case (.prav, .combatSpiritual): return true
        case (.nav, .defense), (.prav, .defense): return true
        default: return false
        }
    }

    /// Determine if card suit opposes the action context (mismatch).
    public static func suitMismatches(suit: FateCardSuit?, context: ActionContext) -> Bool {
        switch (suit, context) {
        case (.prav, .combatPhysical): return true
        case (.nav, .combatSpiritual): return true
        default: return false
        }
    }

    /// Draw a fate card and resolve with full keyword + suit matching.
    public func resolve(
        context: ActionContext,
        baseValue: Int = 0,
        fateDeck: FateDeckManager,
        worldResonance: Float
    ) -> FateResolution? {
        guard let drawResult = fateDeck.drawAndResolve(worldResonance: worldResonance) else {
            return nil
        }

        let card = drawResult.card
        let isMatch = Self.suitMatches(suit: card.suit, context: context)
        let isMismatch = Self.suitMismatches(suit: card.suit, context: context)

        let keywordEffect: KeywordEffect
        if let keyword = card.keyword {
            keywordEffect = KeywordInterpreter.resolveWithAlignment(
                keyword: keyword,
                context: context,
                baseValue: baseValue,
                isMatch: isMatch,
                isMismatch: isMismatch
            )
        } else {
            keywordEffect = .none
        }

        return FateResolution(
            card: card,
            effectiveValue: drawResult.effectiveValue,
            keyword: card.keyword,
            keywordEffect: keywordEffect,
            suitMatch: isMatch,
            isCritical: drawResult.isCritical,
            drawEffects: drawResult.drawEffects,
            appliedRule: drawResult.appliedRule
        )
    }
}
