/// Файл: Views/BattleArenaView.swift
/// Назначение: Содержит реализацию файла BattleArenaView.swift.
/// Зона ответственности: Ограничен задачами слоя представления и пользовательского интерфейса.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Экран тренировочного боя (Arena).
/// Работает в sandbox-режиме: запускает отдельный бой без прямой мутации world-state.
struct BattleArenaView: View {
    let services: AppServices
    let onExit: () -> Void

    @State private var selectedHeroId: String?
    @State private var selectedEnemyId: String?
    @State private var lastOutcome: AppCombatOutcome?
    @State private var activeCombat: ActiveCombat?
    @State private var activeDispositionCombat: ActiveDispositionCombat?
    @State private var useDispositionCombat: Bool = false
    @State private var arenaSeedState: UInt64 = Self.initialArenaSeed

    private var availableHeroes: [HeroDefinition] {
        services.registry.heroRegistry.availableHeroes()
    }

    private var availableEnemies: [EnemyDefinition] {
        services.registry.getAllEnemies().sorted { $0.difficulty < $1.difficulty }
    }

    private var selectedEnemy: EnemyDefinition? {
        guard let id = selectedEnemyId else { return nil }
        return services.registry.getEnemy(id: id)
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
                Spacer()
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

            // MARK: - Combat Mode Toggle
            Toggle(isOn: $useDispositionCombat) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: useDispositionCombat ? "slider.horizontal.3" : "theatermasks")
                    Text(useDispositionCombat ? "Disposition Combat" : "Ritual Combat")
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, Spacing.sm)

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
        .fullScreenCover(item: $activeCombat) { combat in
            RitualCombatSceneView(
                simulation: combat.simulation,
                onCombatEnd: { result in
                    let stats = AppCombatStats(
                        turnsPlayed: result.turnsPlayed,
                        totalDamageDealt: result.totalDamageDealt,
                        totalDamageTaken: result.totalDamageTaken,
                        cardsPlayed: result.cardsPlayed
                    )
                    if case .victory = result.outcome {
                        lastOutcome = .victory(stats: stats)
                    } else {
                        lastOutcome = .defeat(stats: stats)
                    }
                    activeCombat = nil
                },
                onSoundEffect: { SoundManager.shared.play(SoundManager.SoundEffect(rawValue: $0) ?? .buttonTap) },
                onHaptic: { name in
                    let type: HapticManager.HapticType
                    switch name {
                    case "light": type = .light
                    case "medium": type = .medium
                    case "heavy": type = .heavy
                    case "success": type = .success
                    case "error": type = .error
                    default: type = .light
                    }
                    HapticManager.shared.play(type)
                }
            )
        }
        .fullScreenCover(item: $activeDispositionCombat) { combat in
            DispositionCombatSceneView(
                simulation: combat.simulation,
                onCombatEnd: { result in
                    let stats = AppCombatStats(
                        turnsPlayed: result.turnsPlayed,
                        totalDamageDealt: 0,
                        totalDamageTaken: 0,
                        cardsPlayed: result.cardsPlayed
                    )
                    if result.outcome == .defeated {
                        lastOutcome = .defeat(stats: stats)
                    } else {
                        lastOutcome = .victory(stats: stats)
                    }
                    activeDispositionCombat = nil
                },
                onSoundEffect: { SoundManager.shared.play(SoundManager.SoundEffect(rawValue: $0) ?? .buttonTap) },
                onHaptic: { name in
                    let type: HapticManager.HapticType
                    switch name {
                    case "light": type = .light
                    case "medium": type = .medium
                    case "heavy": type = .heavy
                    case "success": type = .success
                    case "error": type = .error
                    default: type = .light
                    }
                    HapticManager.shared.play(type)
                }
            )
        }
    }

    private var canStart: Bool {
        selectedHeroId != nil && selectedEnemyId != nil
    }

    private func nextArenaSeed() -> UInt64 {
        var updatedState = arenaSeedState
        updatedState ^= updatedState << 13
        updatedState ^= updatedState >> 7
        updatedState ^= updatedState << 17

        if updatedState == 0 {
            updatedState = Self.initialArenaSeed
        }

        arenaSeedState = updatedState
        return updatedState
    }

    private func startBattle() {
        guard let heroId = selectedHeroId,
              let hero = services.registry.heroRegistry.hero(id: heroId),
              let enemy = selectedEnemy else { return }

        lastOutcome = nil

        if useDispositionCombat {
            startDispositionBattle(hero: hero, enemy: enemy, heroId: heroId)
        } else {
            startRitualBattle(hero: hero, enemy: enemy, heroId: heroId)
        }
    }

    private func startRitualBattle(hero: HeroDefinition, enemy: EnemyDefinition, heroId: String) {
        let startingDeck = services.cardFactory.createStartingDeck(forHero: heroId)
        let fateCards = services.registry.getAllFateCards()

        let encounterEnemy = EncounterEnemy(
            id: enemy.id,
            name: enemy.name.resolve(using: services.localizationManager),
            hp: enemy.health,
            maxHp: enemy.health,
            wp: enemy.will,
            maxWp: enemy.will,
            power: enemy.power,
            defense: enemy.defense
        )

        let sim = CombatSimulation(
            hand: startingDeck,
            heroHP: hero.baseStats.health,
            heroStrength: hero.baseStats.strength,
            heroArmor: 0,
            enemies: [encounterEnemy],
            fateDeckState: FateDeckState(drawPile: fateCards, discardPile: []),
            rngSeed: nextArenaSeed(),
            worldResonance: 0
        )

        activeCombat = ActiveCombat(simulation: sim)
    }

    private func startDispositionBattle(hero: HeroDefinition, enemy: EnemyDefinition, heroId: String) {
        let startingDeck = services.cardFactory.createStartingDeck(forHero: heroId)
        let seed = nextArenaSeed()

        let sim = DispositionCombatSimulation.create(
            enemyType: enemy.name.resolve(using: services.localizationManager),
            heroHP: hero.baseStats.health,
            heroMaxHP: hero.baseStats.health,
            hand: startingDeck,
            resonanceZone: .yav,
            seed: seed
        )

        activeDispositionCombat = ActiveDispositionCombat(simulation: sim)
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

    private func lastOutcomeView(_ outcome: AppCombatOutcome) -> some View {
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

    private static let initialArenaSeed: UInt64 = 0x0B47_A11C_E000_0001
}

// MARK: - Active Combat Wrapper

private struct ActiveCombat: Identifiable {
    let id = UUID()
    let simulation: CombatSimulation
}

private struct ActiveDispositionCombat: Identifiable {
    let id = UUID()
    let simulation: DispositionCombatSimulation
}
