/// Файл: Views/Components/EnemyCardView.swift
/// Назначение: Содержит реализацию файла EnemyCardView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Combat feedback visual effect overlay
enum CombatFeedback: Equatable {
    case weakness(keyword: String)
    case resistance(keyword: String)
    case abilityRegen(amount: Int)
    case abilityArmor
    case abilityBonusDamage
}

/// Card-style enemy panel for combat display
/// Replaces inline EnemyPanel with a more compact, card-based design
struct EnemyCardView: View {
    let enemy: EncounterEnemyState
    let intent: EnemyIntent?
    let isSelected: Bool
    let feedbackType: CombatFeedback?
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // 1. Header: name + ability icons
            HStack {
                Text(enemy.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)

                Spacer()

                // Ability icons row
                HStack(spacing: Spacing.xxxs) {
                    ForEach(enemy.abilities) { ability in
                        abilityIcon(for: ability.effect)
                    }
                }
            }

            // 2. Dual health bar
            DualHealthBar(
                currentHP: enemy.hp,
                maxHP: enemy.maxHp,
                currentWill: enemy.wp ?? 0,
                maxWill: enemy.maxWp ?? 0
            )

            // 3. Intent badge
            if let intent = intent {
                EnemyIntentBadge(intent: intent)
                    .transition(.scale.combined(with: .opacity))
            }

            // 4. Indicators row (weaknesses/strengths)
            if !enemy.weaknesses.isEmpty || !enemy.strengths.isEmpty {
                HStack(spacing: Spacing.xxs) {
                    // Weaknesses
                    ForEach(enemy.weaknesses, id: \.self) { weakness in
                        keywordBadge(text: weakness, color: AppColors.success)
                    }

                    // Strengths
                    ForEach(enemy.strengths, id: \.self) { strength in
                        keywordBadge(text: strength, color: AppColors.danger)
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .background(AppColors.backgroundTertiary)
        .cornerRadius(CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(isSelected ? AppColors.warning : Color.clear, lineWidth: 2)
        )
        .frame(width: Sizes.cardFrameRevealW)
        .overlay(
            feedbackOverlay
        )
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - Ability Icon

    @ViewBuilder
    private func abilityIcon(for effect: EnemyAbilityEffect) -> some View {
        let (icon, color) = abilityIconData(for: effect)

        Image(systemName: icon)
            .font(.caption2)
            .foregroundColor(color)
    }

    private func abilityIconData(for effect: EnemyAbilityEffect) -> (String, Color) {
        switch effect {
        case .bonusDamage:
            return ("flame.fill", AppColors.danger)
        case .regeneration:
            return ("heart.fill", AppColors.success)
        case .armor:
            return ("shield.fill", AppColors.primary)
        case .firstStrike:
            return ("bolt.fill", AppColors.warning)
        case .spellImmune:
            return ("sparkles", AppColors.info)
        default:
            return ("star.fill", AppColors.muted)
        }
    }

    // MARK: - Keyword Badge

    private func keywordBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: Sizes.tinyCaption))
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.xxs)
            .padding(.vertical, Spacing.xxxs)
            .background(color)
            .cornerRadius(CornerRadius.sm)
    }

    // MARK: - Feedback Overlay

    @ViewBuilder
    private var feedbackOverlay: some View {
        if let feedback = feedbackType {
            ZStack {
                switch feedback {
                case .weakness(let keyword):
                    weaknessFlash(keyword: keyword)

                case .resistance(let keyword):
                    resistanceFlash(keyword: keyword)

                case .abilityRegen(let amount):
                    regenIndicator(amount: amount)

                case .abilityArmor:
                    armorIndicator

                case .abilityBonusDamage:
                    bonusDamageGlow
                }
            }
        }
    }

    private func weaknessFlash(keyword: String) -> some View {
        ZStack {
            AppColors.success.opacity(Opacity.light)

            Text("WEAK!")
                .font(.headline.bold())
                .foregroundColor(AppColors.success)
        }
        .transition(.opacity)
    }

    private func resistanceFlash(keyword: String) -> some View {
        ZStack {
            AppColors.muted.opacity(Opacity.light)

            Text("RESIST")
                .font(.headline.bold())
                .foregroundColor(AppColors.muted)
        }
        .transition(.opacity)
    }

    private func regenIndicator(amount: Int) -> some View {
        VStack {
            Spacer()
            Text("+\(amount) HP")
                .font(.caption.bold())
                .foregroundColor(AppColors.success)
                .padding(Spacing.xxs)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var armorIndicator: some View {
        Image(systemName: "shield.fill")
            .font(.largeTitle)
            .foregroundColor(AppColors.primary.opacity(Opacity.medium))
    }

    private var bonusDamageGlow: some View {
        AppColors.danger.opacity(Opacity.light)
    }
}

// MARK: - Preview

#Preview("Enemy Card - Standard") {
    let sampleEnemy = EncounterEnemyState(
        from: EncounterEnemy(
            id: "preview_wolf",
            name: "Shadow Wolf",
            hp: 12,
            maxHp: 20,
            wp: 8,
            maxWp: 10,
            power: 5,
            defense: 2,
            spiritDefense: 1,
            behaviorId: nil,
            resonanceBehavior: nil,
            lootCardIds: [],
            faithReward: 10,
            weaknesses: ["fire", "light"],
            strengths: ["dark"],
            abilities: [
                EnemyAbility(
                    id: "regen1",
                    name: LocalizableText("Regeneration"),
                    description: LocalizableText("Heal 2 HP per turn"),
                    effect: .regeneration(2)
                ),
                EnemyAbility(
                    id: "armor1",
                    name: LocalizableText("Thick Hide"),
                    description: LocalizableText("+1 Armor"),
                    effect: .armor(1)
                )
            ]
        )
    )

    VStack(spacing: Spacing.lg) {
        // Normal state
        EnemyCardView(
            enemy: sampleEnemy,
            intent: .attack(damage: 8),
            isSelected: false,
            feedbackType: nil,
            onTap: {}
        )

        // Selected state
        EnemyCardView(
            enemy: sampleEnemy,
            intent: .ritual(resonanceShift: -5),
            isSelected: true,
            feedbackType: nil,
            onTap: {}
        )

        // Weakness feedback
        EnemyCardView(
            enemy: sampleEnemy,
            intent: .attack(damage: 8),
            isSelected: true,
            feedbackType: .weakness(keyword: "fire"),
            onTap: {}
        )
    }
    .padding()
    .background(AppColors.backgroundSystem)
}

#Preview("Enemy Card - No Spirit Track") {
    let basicEnemy = EncounterEnemyState(
        from: EncounterEnemy(
            id: "preview_bandit",
            name: "Bandit",
            hp: 15,
            maxHp: 15,
            wp: nil,
            maxWp: nil,
            power: 4,
            defense: 1,
            spiritDefense: 0,
            behaviorId: nil,
            resonanceBehavior: nil,
            lootCardIds: [],
            faithReward: 5,
            weaknesses: [],
            strengths: [],
            abilities: []
        )
    )

    EnemyCardView(
        enemy: basicEnemy,
        intent: .attack(damage: 6),
        isSelected: false,
        feedbackType: nil,
        onTap: {}
    )
    .padding()
    .background(AppColors.backgroundSystem)
}
