import SwiftUI
import TwilightEngine

/// Quick Battle mode: pick hero, pick enemy, fight
struct BattleArenaView: View {
    @ObservedObject var engine: TwilightGameEngine
    let onExit: () -> Void

    @State private var selectedHeroId: String?
    @State private var selectedEnemyId: String?
    @State private var showingCombat = false
    @State private var lastOutcome: CombatView.CombatOutcome?

    private var availableHeroes: [HeroDefinition] {
        HeroRegistry.shared.availableHeroes()
    }

    private var availableEnemies: [EnemyDefinition] {
        ContentRegistry.shared.getAllEnemies().sorted { $0.difficulty < $1.difficulty }
    }

    private var selectedEnemy: EnemyDefinition? {
        guard let id = selectedEnemyId else { return nil }
        return ContentRegistry.shared.getEnemy(id: id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onExit) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "chevron.left")
                        Text(L10n.uiBack.localized)
                    }
                    .foregroundColor(AppColors.primary)
                }
                Spacer()
                Text(L10n.arenaTitle.localized)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // MARK: - Hero Selection
                    sectionHeader(L10n.arenaHero.localized, icon: "person.fill")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.lg) {
                            ForEach(availableHeroes, id: \.id) { hero in
                                HeroSelectionCard(
                                    hero: hero,
                                    isSelected: selectedHeroId == hero.id,
                                    onTap: { selectedHeroId = hero.id }
                                )
                                .frame(width: Sizes.cardFrameArenaW, height: Sizes.cardFrameArenaH)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - Enemy Selection
                    sectionHeader(L10n.arenaEnemy.localized, icon: "shield.lefthalf.filled")

                    VStack(spacing: Spacing.sm) {
                        ForEach(availableEnemies, id: \.id) { enemy in
                            EnemySelectionCard(
                                enemy: enemy,
                                isSelected: selectedEnemyId == enemy.id,
                                onTap: { selectedEnemyId = enemy.id }
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Result from last fight
                    if let outcome = lastOutcome {
                        lastOutcomeView(outcome)
                    }

                    Color.clear.frame(height: Sizes.cardHeightSmall)
                }
            }

            // MARK: - Start Button
            VStack(spacing: 0) {
                Divider()
                Button(action: startBattle) {
                    HStack {
                        Image(systemName: "flame.fill")
                        Text(L10n.arenaFight.localized)
                    }
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canStart ? AppColors.danger : AppColors.secondary)
                    .cornerRadius(CornerRadius.lg)
                }
                .disabled(!canStart)
                .padding()
            }
            .background(AppColors.backgroundSystem)
        }
        .background(AppColors.backgroundSystem.ignoresSafeArea())
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingCombat) {
            CombatView(
                engine: engine,
                onCombatEnd: { outcome in
                    lastOutcome = outcome
                    showingCombat = false
                }
            )
        }
    }

    private var canStart: Bool {
        selectedHeroId != nil && selectedEnemyId != nil
    }

    private func startBattle() {
        guard let heroId = selectedHeroId,
              let hero = HeroRegistry.shared.hero(id: heroId),
              let enemy = selectedEnemy else { return }

        // Setup hero with starting deck
        let startingDeckDefs = hero.startingDeckCardIDs.compactMap {
            ContentRegistry.shared.getCard(id: $0)
        }
        let startingDeck = startingDeckDefs.map { $0.toCard() }

        engine.initializeNewGame(
            playerName: hero.name.localized,
            heroId: heroId,
            startingDeck: startingDeck
        )

        // Setup enemy
        engine.combat.setupCombatEnemy(enemy.toCard())

        lastOutcome = nil
        showingCombat = true
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppColors.muted)
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.muted)
            Spacer()
        }
        .padding(.horizontal)
    }

    private func lastOutcomeView(_ outcome: CombatView.CombatOutcome) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: outcome.isVictory ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(outcome.isVictory ? AppColors.success : AppColors.danger)
            Text(outcome.isVictory ? L10n.arenaVictory.localized : L10n.arenaDefeat.localized)
                .font(.headline)
                .foregroundColor(outcome.isVictory ? AppColors.success : AppColors.danger)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            (outcome.isVictory ? AppColors.success : AppColors.danger).opacity(Opacity.faint)
        )
        .cornerRadius(CornerRadius.lg)
        .padding(.horizontal)
    }
}
