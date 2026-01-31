import SwiftUI
import TwilightEngine

// MARK: - Bestiary View (Epic 13)
// Witcher 3-style creature compendium with progressive knowledge reveal

struct BestiaryView: View {
    @StateObject private var profileManager = ProfileManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    private var allEnemies: [EnemyDefinition] {
        ContentRegistry.shared.getAllEnemies()
    }

    private var filteredEnemies: [EnemyDefinition] {
        if searchText.isEmpty { return allEnemies }
        return allEnemies.filter { enemy in
            let knowledge = profileManager.knowledgeLevel(for: enemy.id)
            guard knowledge >= .encountered else { return false }
            return enemy.name.resolved.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Manual list — EnemyType is not CaseIterable
    private let enemyTypes: [EnemyType] = [.beast, .spirit, .undead, .demon, .human, .boss]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.muted)
                        TextField(L10n.bestiarySearch.localized, text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(Spacing.sm)
                    .background(AppColors.cardBackground)
                    .cornerRadius(CornerRadius.lg)
                    .padding(.horizontal)

                    // Discovery progress
                    let total = allEnemies.count
                    let discovered = allEnemies.filter { profileManager.knowledgeLevel(for: $0.id) >= .encountered }.count

                    if total > 0 {
                        Text(L10n.bestiaryProgress.localized(with: discovered, total))
                            .font(.caption)
                            .foregroundColor(AppColors.muted)
                    }

                    // Grouped by enemy type
                    ForEach(enemyTypes, id: \.self) { type in
                        let enemies = filteredEnemies.filter { $0.enemyType == type }
                        if !enemies.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(displayName(for: type))
                                    .font(.headline)
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal)

                                ForEach(enemies, id: \.id) { enemy in
                                    NavigationLink(destination: CreatureDetailView(enemy: enemy)) {
                                        BestiaryRow(
                                            enemy: enemy,
                                            knowledge: profileManager.knowledge(for: enemy.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, Spacing.sm)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(AppColors.backgroundSystem)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(AppColors.backgroundSystem, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppColors.primary)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.bestiaryTitle.localized)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.statsDone.localized) { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

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

// MARK: - Bestiary Row

struct BestiaryRow: View {
    let enemy: EnemyDefinition
    let knowledge: CreatureKnowledge

    private var isKnown: Bool { knowledge.level >= .encountered }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Type icon
            Image(systemName: iconForType(enemy.enemyType))
                .font(.title3)
                .foregroundColor(isKnown ? colorForType(enemy.enemyType) : AppColors.muted)
                .frame(width: Sizes.iconLarge)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(isKnown ? enemy.name.resolved : "???")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isKnown ? .white : AppColors.muted)

                if isKnown {
                    Text(enemy.description.resolved)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Knowledge level dots (3 levels above unknown)
            HStack(spacing: Spacing.xxs) {
                ForEach(1...3, id: \.self) { level in
                    Circle()
                        .fill(knowledge.level.rawValue >= level ? AppColors.primary : AppColors.muted.opacity(Opacity.light))
                        .frame(width: Sizes.dotIndicator, height: Sizes.dotIndicator)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.muted)
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(AppColors.cardBackground)
        .opacity(isKnown ? Opacity.opaque : Opacity.medium)
    }

    // MARK: - Type Mapping

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
}
