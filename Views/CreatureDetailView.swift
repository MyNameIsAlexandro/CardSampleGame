import SwiftUI
import TwilightEngine

// MARK: - Creature Detail View (Epic 13)
// Witcher 3-style progressive reveal: more knowledge = more sections visible

struct CreatureDetailView: View {
    let enemy: EnemyDefinition
    @StateObject private var profileManager = ProfileManager.shared

    private var knowledge: CreatureKnowledge {
        profileManager.knowledge(for: enemy.id)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                headerSection
                knowledgeLevelBar

                if knowledge.level >= .encountered {
                    descriptionSection
                }

                if knowledge.level >= .studied {
                    statsSection
                }

                if knowledge.level >= .studied && !enemy.abilities.isEmpty {
                    abilitiesSection
                }

                if knowledge.level >= .studied, let lore = enemy.lore {
                    loreSection(lore: lore)
                }

                if knowledge.level >= .mastered {
                    combatInfoSection
                }

                if knowledge.level >= .mastered {
                    tacticsSection
                }

                if knowledge.level >= .encountered {
                    personalStatsSection
                }

                if knowledge.level < .mastered {
                    lockedSectionsHint
                }
            }
            .padding()
        }
        .background(AppColors.backgroundSystem)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: iconForType(enemy.enemyType))
                .font(.system(size: Sizes.iconXXL))
                .foregroundColor(knowledge.level >= .encountered ? colorForType(enemy.enemyType) : AppColors.muted)

            Text(knowledge.level >= .encountered ? enemy.name.resolved : "???")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            HStack(spacing: Spacing.md) {
                // Type badge
                Text(displayName(for: enemy.enemyType))
                    .font(.caption)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxxs)
                    .background(AppColors.cardBackground)
                    .cornerRadius(CornerRadius.sm)
                    .foregroundColor(AppColors.muted)

                // Rarity badge
                Text(enemy.rarity.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxxs)
                    .background(AppColors.cardBackground)
                    .cornerRadius(CornerRadius.sm)
                    .foregroundColor(AppColors.primary)

                // Difficulty stars
                HStack(spacing: Spacing.xxxs) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= enemy.difficulty ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(AppColors.warning)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Knowledge Level Bar

    private var knowledgeLevelBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text(L10n.bestiaryKnowledge.localized)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
                Spacer()
                Text(knowledgeLevelName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.muted.opacity(Opacity.faint))
                        .frame(height: Sizes.progressMedium)
                        .cornerRadius(CornerRadius.sm)

                    Rectangle()
                        .fill(AppColors.primary)
                        .frame(width: geo.size.width * knowledgeProgress, height: Sizes.progressMedium)
                        .cornerRadius(CornerRadius.sm)
                }
            }
            .frame(height: Sizes.progressMedium)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    private var knowledgeLevelName: String {
        switch knowledge.level {
        case .unknown: return L10n.bestiaryLevelUnknown.localized
        case .encountered: return L10n.bestiaryLevelEncountered.localized
        case .studied: return L10n.bestiaryLevelStudied.localized
        case .mastered: return L10n.bestiaryLevelMastered.localized
        }
    }

    private var knowledgeProgress: CGFloat {
        CGFloat(knowledge.level.rawValue) / 3.0
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(enemy.description.resolved)
                .font(.body)
                .foregroundColor(AppColors.muted)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "chart.bar.fill", title: L10n.bestiaryStats.localized)

            HStack(spacing: Spacing.lg) {
                StatPill(icon: "heart.fill", label: L10n.statHealth.localized, value: "\(enemy.health)", color: AppColors.health)
                StatPill(icon: "bolt.fill", label: L10n.statPower.localized, value: "\(enemy.power)", color: AppColors.power)
                StatPill(icon: "shield.fill", label: L10n.statDefense.localized, value: "\(enemy.defense)", color: AppColors.defense)
                if let will = enemy.will {
                    StatPill(icon: "sparkles", label: L10n.combatFaithLabel.localized, value: "\(will)", color: AppColors.spirit)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Abilities

    private var abilitiesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "sparkle", title: L10n.characterAbilities.localized)

            ForEach(enemy.abilities) { ability in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.warning)
                        .padding(.top, Spacing.xxs)
                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                        Text(ability.name.resolved)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text(ability.description.resolved)
                            .font(.caption)
                            .foregroundColor(AppColors.muted)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Lore

    private func loreSection(lore: LocalizableText) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "book.fill", title: L10n.bestiaryLore.localized)

            Text("\"\(lore.resolved)\"")
                .font(.body)
                .italic()
                .foregroundColor(AppColors.muted)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.backgroundSystem.opacity(Opacity.medium))
                .cornerRadius(CornerRadius.lg)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Combat Info (Weaknesses + Strengths)

    private var combatInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "shield.lefthalf.filled", title: L10n.bestiaryCombatInfo.localized)

            if let weaknesses = enemy.weaknesses, !weaknesses.isEmpty {
                HStack {
                    Text(L10n.bestiaryWeaknesses.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                    Spacer()
                    ForEach(weaknesses, id: \.self) { w in
                        Text(w)
                            .font(.caption)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxxs)
                            .background(AppColors.success.opacity(Opacity.faint))
                            .foregroundColor(AppColors.success)
                            .cornerRadius(CornerRadius.sm)
                    }
                }
            }

            if let strengths = enemy.strengths, !strengths.isEmpty {
                HStack {
                    Text(L10n.bestiaryStrengths.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                    Spacer()
                    ForEach(strengths, id: \.self) { s in
                        Text(s)
                            .font(.caption)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxxs)
                            .background(AppColors.danger.opacity(Opacity.faint))
                            .foregroundColor(AppColors.danger)
                            .cornerRadius(CornerRadius.sm)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Faction Tactics

    private var tacticsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "map.fill", title: L10n.bestiaryTactics.localized)

            if let nav = enemy.tacticsNav {
                tacticRow(faction: L10n.resonanceNav.localized, text: nav.resolved, color: AppColors.dark)
            }
            if let yav = enemy.tacticsYav {
                tacticRow(faction: L10n.resonanceYav.localized, text: yav.resolved, color: AppColors.neutral)
            }
            if let prav = enemy.tacticsPrav {
                tacticRow(faction: L10n.resonancePrav.localized, text: prav.resolved, color: AppColors.info)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    private func tacticRow(faction: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(faction)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(AppColors.muted)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Personal Stats

    private var personalStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader(icon: "person.crop.circle", title: L10n.bestiaryPersonalStats.localized)

            HStack(spacing: Spacing.lg) {
                statItem(label: L10n.bestiaryEncountered.localized, value: "\(knowledge.timesEncountered)")
                statItem(label: L10n.bestiaryDefeated.localized, value: "\(knowledge.timesDefeated)")
                statItem(label: L10n.bestiaryPacified.localized, value: "\(knowledge.timesPacified)")
            }

            if knowledge.lastMetDay > 0 {
                Text(L10n.bestiaryLastMet.localized(with: knowledge.lastMetDay))
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: Spacing.xxxs) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Locked Hint

    private var lockedSectionsHint: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundColor(AppColors.muted)

            if knowledge.level < .studied {
                Text(L10n.bestiaryUnlockStudied.localized)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
                    .multilineTextAlignment(.center)
            } else if knowledge.level < .mastered {
                Text(L10n.bestiaryUnlockMastered.localized)
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .cornerRadius(CornerRadius.lg)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(AppColors.primary)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
    }

    private func iconForType(_ type: EnemyType) -> String {
        switch type {
        case .beast: return "pawprint.fill"
        case .spirit: return "wind"
        case .undead: return "figure.stand"
        case .demon: return "flame.fill"
        case .human: return "person.fill"
        case .boss: return "crown.fill"
        }
    }

    private func colorForType(_ type: EnemyType) -> Color {
        switch type {
        case .beast: return AppColors.success
        case .spirit: return AppColors.info
        case .undead: return AppColors.muted
        case .demon: return AppColors.danger
        case .human: return AppColors.warning
        case .boss: return AppColors.primary
        }
    }

    private func displayName(for type: EnemyType) -> String {
        switch type {
        case .beast: return L10n.enemyTypeBeast.localized
        case .spirit: return L10n.enemyTypeSpirit.localized
        case .undead: return L10n.enemyTypeUndead.localized
        case .demon: return L10n.enemyTypeDemon.localized
        case .human: return L10n.enemyTypeHuman.localized
        case .boss: return L10n.enemyTypeBoss.localized
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xxxs) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
