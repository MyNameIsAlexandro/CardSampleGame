/// Файл: App/ContentView.swift
/// Назначение: Содержит реализацию файла ContentView.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine

/// Корневой координатор экранов приложения.
/// Управляет маршрутизацией между выбором героя, слотами сохранений, world map и resume боя.
struct ContentView: View {
    let services: AppServices

    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false
    @State private var ambientPulse = false

    // MARK: - Engine-First Architecture
    // Engine is the single source of truth (no legacy GameState)
    // GameEngineObservable wraps pure-logic Engine for SwiftUI binding
    @StateObject private var vm: GameEngineObservable
    @StateObject private var saveManager = SaveManager.shared
    @StateObject private var flow = ContentFlow()

    // Heroes loaded from Content Pack (data-driven)
    private var availableHeroes: [HeroDefinition] {
        services.registry.heroRegistry.availableHeroes()
    }

    // Check if there are any saves
    var hasSaves: Bool {
        saveManager.hasSaves
    }

    init(services: AppServices) {
        self.services = services
        _vm = StateObject(wrappedValue: GameEngineObservable(engineServices: services.engineServices))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundSystem.ignoresSafeArea()

                // UX-11: Ambient background pulse
                AppGradient.ambientDark
                    .ignoresSafeArea()
                    .opacity(ambientPulse ? 0.6 : 0.3)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: ambientPulse)
                    .onAppear { ambientPulse = true }

                rootScreenView
            } // ZStack
        }
        .preferredColorScheme(.dark)
        .sheet(item: $flow.modal) { modal in
            Group {
                switch modal {
                case .rules:
                    RulesView()
                case .statistics:
                    StatisticsView()
                case .settings:
                    SettingsView()
                case .bestiary:
                    BestiaryView(registry: services.registry)
                case .achievements:
                    AchievementsView()
                case .contentManager:
                    #if DEBUG
                    ContentManagerView(
                        contentManager: services.contentManager,
                        registry: services.registry,
                        bundledPackURLs: getBundledPackURLs()
                    )
                    #else
                    EmptyView()
                    #endif
                }
            }
        }
        .alert(L10n.uiContinueGame.localized, isPresented: $flow.showingLoadAlert) {
            Button(L10n.buttonOk.localized) { flow.dismissLoadAlert() }
        } message: {
            Text(flow.loadAlertMessage ?? "")
        }
        .fullScreenCover(isPresented: $flow.resumingCombat) {
            if let simulation = buildResumeSimulation() {
                RitualCombatSceneView(
                    simulation: simulation,
                    onCombatEnd: { result in
                        RitualCombatBridge.applyCombatResult(result, to: vm.engine)
                        flow.resumingCombat = false
                        if let slot = flow.selectedSaveSlot {
                            saveManager.saveGame(to: slot, engine: vm.engine)
                        }
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
        .fullScreenCover(isPresented: $flow.showingTutorial) {
            TutorialOverlayView {
                hasCompletedTutorial = true
                flow.showingTutorial = false
            }
        }
    }

    @ViewBuilder
    private var rootScreenView: some View {
        switch flow.screen {
        case .battleArena:
            BattleArenaView(services: services, onExit: { flow.screen = .characterSelection })
        case .worldMap:
            WorldMapView(
                vm: vm,
                cardFactory: services.cardFactory,
                onExit: {
                    if let slot = flow.selectedSaveSlot {
                        saveManager.saveGame(to: slot, engine: vm.engine)
                    }
                    flow.screen = .characterSelection
                },
                onAutoSave: {
                    if let slot = flow.selectedSaveSlot {
                        saveManager.saveGame(to: slot, engine: vm.engine)
                    }
                }
            )
        case .saveSlots:
            saveSlotSelectionView
        case .loadSlots:
            loadSlotSelectionView
        case .characterSelection:
            characterSelectionView
        }
    }

    private var characterSelectionView: some View {
        CharacterSelectionScreen(
            availableHeroes: availableHeroes,
            registry: services.registry,
            selectedHeroId: $flow.selectedHeroId,
            isSaveManagerLoaded: saveManager.isLoaded,
            hasSaves: hasSaves,
            onOpenContentManager: { flow.modal = .contentManager },
            onOpenSettings: { flow.modal = .settings },
            onOpenBestiary: { flow.modal = .bestiary },
            onOpenAchievements: { flow.modal = .achievements },
            onOpenStatistics: { flow.modal = .statistics },
            onOpenRules: { flow.modal = .rules },
            onContinueGame: { flow.handleContinueGame(saveManager: saveManager, engine: vm.engine, registry: services.registry) },
            onStartAdventure: { flow.screen = .saveSlots },
            onQuickBattle: { flow.screen = .battleArena }
        )
        .background(AppColors.backgroundSystem)
        .navigationBarHidden(true)
    }

    private var saveSlotSelectionView: some View {
        SaveSlotSelectionScreen(
            registry: services.registry,
            selectedHeroId: flow.selectedHeroId,
            saveManager: saveManager,
            onBack: { flow.screen = .characterSelection },
            onNewGame: {
                flow.startGame(
                    in: $0,
                    registry: services.registry,
                    engine: vm.engine,
                    saveManager: saveManager,
                    hasCompletedTutorial: hasCompletedTutorial
                )
            },
            onLoadGame: { flow.loadGame(from: $0, engine: vm.engine, saveManager: saveManager, registry: services.registry) },
            onDelete: { saveManager.deleteSave(from: $0) }
        )
    }

    // MARK: - Combat Resume

    private func buildResumeSimulation() -> CombatSimulation? {
        guard let savedState = vm.engine.pendingEncounterState else { return nil }

        let encounterEnemies = savedState.enemies.map { state in
            EncounterEnemy(
                id: state.id,
                name: state.name,
                hp: state.hp,
                maxHp: state.maxHp,
                wp: state.wp,
                maxWp: state.maxWp,
                power: state.power,
                defense: state.defense,
                spiritDefense: state.spiritDefense,
                resonanceBehavior: state.resonanceBehavior,
                lootCardIds: state.lootCardIds,
                faithReward: state.faithReward,
                weaknesses: state.weaknesses,
                strengths: state.strengths,
                abilities: state.abilities
            )
        }

        return CombatSimulation(
            hand: savedState.context.heroCards,
            heroHP: savedState.heroHP,
            heroStrength: savedState.context.hero.strength,
            heroWisdom: savedState.context.hero.wisdom,
            heroArmor: savedState.context.hero.armor,
            enemies: encounterEnemies,
            fateDeckState: savedState.fateDeckState,
            rngSeed: savedState.rngState,
            worldResonance: savedState.context.worldResonance
        )
    }

    private var loadSlotSelectionView: some View {
        LoadSlotSelectionScreen(
            saveManager: saveManager,
            onBack: { flow.screen = .characterSelection },
            onLoad: { flow.loadGame(from: $0, engine: vm.engine, saveManager: saveManager, registry: services.registry) }
        )
    }
}

#Preview {
    ContentView(
        services: AppServices(
            rng: WorldRNG(seed: 0),
            registry: ContentRegistry(),
            localizationManager: LocalizationManager()
        )
    )
}
