import SwiftUI
import TwilightEngine
import CoreHeroesContent
import TwilightMarchesActIContent

struct ContentView: View {
    @State private var showingWorldMap = false
    @State private var showingRules = false
    @State private var showingSaveSlots = false
    @State private var showingLoadSlots = false  // New: for "Continue" flow
    @State private var showingStatistics = false
    @State private var showingContentManager = false
    @State private var showingBattleArena = false
    @State private var selectedHeroId: String?
    @State private var selectedSaveSlot: Int?

    // MARK: - Engine-First Architecture
    // Engine is the single source of truth (no legacy GameState)
    @StateObject private var engine = TwilightGameEngine()
    @StateObject private var saveManager = SaveManager.shared

    // Heroes loaded from Content Pack (data-driven)
    private var availableHeroes: [HeroDefinition] {
        HeroRegistry.shared.availableHeroes()
    }

    // Check if there are any saves
    var hasSaves: Bool {
        saveManager.hasSaves
    }

    // Get the most recent save slot (for single-save auto-load)
    var mostRecentSaveSlot: Int? {
        guard let mostRecent = saveManager.allSaves.first else {
            return nil
        }
        // Find the slot for this save
        for (slot, save) in saveManager.saveSlots {
            if save.savedAt == mostRecent.savedAt {
                return slot
            }
        }
        return nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundSystem.ignoresSafeArea()

            if showingBattleArena {
                BattleArenaView(engine: engine, onExit: {
                    showingBattleArena = false
                })
            } else if showingWorldMap {
                // MARK: - Engine-First: Pass engine directly to WorldMapView
                WorldMapView(
                    engine: engine,
                    onExit: {
                        // Save game on exit
                        if let slot = selectedSaveSlot {
                            saveManager.saveGame(to: slot, engine: engine)
                        }
                        showingWorldMap = false
                        showingSaveSlots = false
                        showingLoadSlots = false
                    }
                )
            } else if showingSaveSlots {
                saveSlotSelectionView
            } else if showingLoadSlots {
                loadSlotSelectionView
            } else {
                characterSelectionView
            }
            } // ZStack
        }
    }

    var characterSelectionView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with rules and statistics buttons
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tmGameTitle.localized)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(2)
                                Text(L10n.tmGameSubtitle.localized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            #if DEBUG
                            Button(action: { showingContentManager = true }) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.title3)
                                    .padding(8)
                                    .background(AppColors.dark.opacity(0.2))
                                    .foregroundColor(AppColors.dark)
                                    .cornerRadius(8)
                            }
                            #endif

                            Button(action: { showingStatistics = true }) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .padding(8)
                                    .background(AppColors.warning.opacity(0.2))
                                    .foregroundColor(AppColors.warning)
                                    .cornerRadius(8)
                            }
                            Button(action: { showingRules = true }) {
                                Image(systemName: "book.fill")
                                    .font(.title3)
                                    .padding(8)
                                    .background(AppColors.info.opacity(0.2))
                                    .foregroundColor(AppColors.info)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        Text(L10n.characterSelectTitle.localized)
                            .font(.title2)
                            .foregroundColor(.secondary)

                        // Hero cards scroll (data-driven from HeroRegistry)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(availableHeroes, id: \.id) { hero in
                                    HeroSelectionCard(
                                        hero: hero,
                                        isSelected: selectedHeroId == hero.id,
                                        onTap: {
                                            selectedHeroId = hero.id
                                        }
                                    )
                                    .frame(width: min(geometry.size.width * 0.65, 240), height: 280)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        .frame(height: 320)

                        // Hero stats (data-driven from HeroRegistry)
                        if let heroId = selectedHeroId,
                           let hero = HeroRegistry.shared.hero(id: heroId) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text(L10n.characterStats.localized)
                                    .font(.headline)

                                Text(hero.description.localized)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 24) {
                                    StatDisplay(icon: "heart.fill", label: L10n.statHealth.localized, value: hero.baseStats.health, color: AppColors.health)
                                    StatDisplay(icon: "bolt.fill", label: L10n.statPower.localized, value: hero.baseStats.strength, color: AppColors.power)
                                    StatDisplay(icon: "shield.fill", label: L10n.statDefense.localized, value: hero.baseStats.constitution, color: AppColors.defense)
                                }

                                // Hero special ability
                                Divider()
                                Text(L10n.characterAbilities.localized)
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(hero.specialAbility.icon)
                                        Text(hero.specialAbility.name.localized)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.power)
                                    }
                                    Text(hero.specialAbility.description.localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 4)
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        // Extra space for button
                        Color.clear.frame(height: 90)
                    }
                    .padding(.bottom, 20)
                }

                // Fixed buttons at bottom with shadow
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, AppColors.backgroundSystem]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 30)

                    VStack(spacing: 12) {
                        // Continue button (only if saves exist)
                        if hasSaves {
                            Button(action: { handleContinueGame() }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text(L10n.uiContinue.localized)
                                }
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.success)
                                .cornerRadius(12)
                            }
                        }

                        // New game button - requires hero selection
                        Button(action: { showingSaveSlots = true }) {
                            HStack {
                                Image(systemName: hasSaves ? "plus.circle.fill" : "play.fill")
                                Text(selectedHeroId == nil
                                    ? L10n.buttonSelectHeroFirst.localized
                                    : L10n.buttonStartAdventure.localized)
                            }
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedHeroId == nil ? AppColors.secondary : AppColors.primary)
                            .cornerRadius(12)
                        }
                        .disabled(selectedHeroId == nil)

                        // Quick Battle button
                        Button(action: { showingBattleArena = true }) {
                            HStack {
                                Image(systemName: "flame.fill")
                                Text(L10n.arenaTitle.localized)
                            }
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.danger.opacity(Opacity.high))
                            .cornerRadius(CornerRadius.lg)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .background(AppColors.backgroundSystem)
                }
            }
        }
        .background(AppColors.backgroundSystem)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingRules) {
            RulesView()
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView()
        }
        #if DEBUG
        .sheet(isPresented: $showingContentManager) {
            ContentManagerView(bundledPackURLs: getBundledPackURLs())
        }
        #endif
        .preferredColorScheme(.dark)
    }

    var saveSlotSelectionView: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: { showingSaveSlots = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L10n.uiBack.localized)
                    }
                    .foregroundColor(AppColors.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.uiSlotSelection.localized)
                        .font(.title2)
                        .fontWeight(.bold)
                    if let heroId = selectedHeroId,
                       let hero = HeroRegistry.shared.hero(id: heroId) {
                        Text(hero.name.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()

            // Save slots
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(1...3, id: \.self) { slotNumber in
                        SaveSlotCard(
                            slotNumber: slotNumber,
                            saveData: saveManager.getSave(from: slotNumber),
                            onNewGame: { startGame(in: slotNumber) },
                            onLoadGame: { loadGame(from: slotNumber) },
                            onDelete: { saveManager.deleteSave(from: slotNumber) }
                        )
                    }
                }
                .padding()
            }
        }
        .background(AppColors.backgroundSystem)
        .navigationBarHidden(true)
    }

    func startGame(in slot: Int) {
        guard let heroId = selectedHeroId,
              let hero = HeroRegistry.shared.hero(id: heroId) else {
            return
        }

        // Get starting deck from hero's card IDs
        let startingDeckDefs = hero.startingDeckCardIDs.compactMap { ContentRegistry.shared.getCard(id: $0) }
        let startingDeck = startingDeckDefs.map { $0.toCard() }

        // Initialize new game in engine
        engine.initializeNewGame(
            playerName: hero.name.localized,
            heroId: heroId,
            startingDeck: startingDeck
        )

        // Save to selected slot
        selectedSaveSlot = slot
        saveManager.saveGame(to: slot, engine: engine)

        showingWorldMap = true
        showingSaveSlots = false
    }

    func loadGame(from slot: Int) {
        if saveManager.loadGame(from: slot, engine: engine) {
            selectedHeroId = engine.heroId
            selectedSaveSlot = slot
            showingWorldMap = true
            showingSaveSlots = false
            showingLoadSlots = false
        }
    }

    // MARK: - Continue Game

    func handleContinueGame() {
        let count = saveManager.saveCount

        if count == 0 {
            // No saves - shouldn't happen as button is hidden
            return
        } else if count == 1 {
            // Only one save - load it directly
            if let slot = mostRecentSaveSlot {
                loadGame(from: slot)
            }
        } else {
            // Multiple saves - show selection screen
            showingLoadSlots = true
        }
    }

    // MARK: - Load Slot Selection View

    var loadSlotSelectionView: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: { showingLoadSlots = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L10n.uiBack.localized)
                    }
                    .foregroundColor(AppColors.primary)
                }
                Spacer()
                Text(L10n.uiContinueGame.localized)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()

            // Load slots - show all saves
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(saveManager.saveSlots.keys.sorted()), id: \.self) { slot in
                        if let save = saveManager.getSave(from: slot) {
                            LoadSlotCard(
                                slot: slot,
                                saveData: save,
                                onLoad: { loadGame(from: slot) }
                            )
                        }
                    }

                    // Empty state
                    if !saveManager.hasSaves {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(L10n.uiNoSaves.localized)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    }
                }
                .padding()
            }
        }
        .background(AppColors.backgroundSystem)
        .navigationBarHidden(true)
    }
}

struct StatDisplay: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Save Slot Card

struct SaveSlotCard: View {
    let slotNumber: Int
    let saveData: EngineSave?
    let onNewGame: () -> Void
    let onLoadGame: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false
    @State private var showingOverwriteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.uiSlotNumber.localized(with: slotNumber))
                    .font(.headline)
                Spacer()
                if saveData != nil {
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.danger)
                    }
                }
            }

            if let save = saveData {
                // Existing save
                VStack(alignment: .leading, spacing: 8) {
                    Text(save.playerName)
                        .font(.title3)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        Label("\(save.playerHealth)/\(save.playerMaxHealth)", systemImage: "heart.fill")
                            .foregroundColor(AppColors.danger)
                        Label("\(save.playerFaith)", systemImage: "sparkles")
                            .foregroundColor(AppColors.faith)
                        Label("\(save.playerBalance)", systemImage: "scale.3d")
                            .foregroundColor(AppColors.dark)
                    }
                    .font(.subheadline)

                    Text(L10n.dayNumber.localized(with: save.currentDay))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatDate(save.savedAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Divider()

                    HStack(spacing: 12) {
                        Button(action: onLoadGame) {
                            Text(L10n.uiLoad.localized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppColors.primary)
                                .cornerRadius(8)
                        }

                        Button(action: { showingOverwriteAlert = true }) {
                            Text(L10n.uiNewGame.localized)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppColors.primary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            } else {
                // Empty slot
                VStack(spacing: 12) {
                    Image(systemName: "square.dashed")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text(L10n.uiEmptySlot.localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: onNewGame) {
                        Text(L10n.uiStartNewGame.localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.success)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .alert(L10n.uiDeleteSave.localized, isPresented: $showingDeleteAlert) {
            Button(L10n.uiCancel.localized, role: .cancel) { }
            Button(L10n.uiDelete.localized, role: .destructive) {
                onDelete()
            }
        } message: {
            Text(L10n.uiDeleteConfirm.localized)
        }
        .alert(L10n.uiOverwriteSave.localized, isPresented: $showingOverwriteAlert) {
            Button(L10n.uiCancel.localized, role: .cancel) { }
            Button(L10n.uiOverwrite.localized, role: .destructive) {
                onDelete()
                onNewGame()
            }
        } message: {
            Text(L10n.uiOverwriteConfirm.localized)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Load Slot Card (for Continue flow)

struct LoadSlotCard: View {
    let slot: Int
    let saveData: EngineSave
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.uiSlotNumber.localized(with: slot))
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(saveData.playerName)
                    .font(.title3)
                    .fontWeight(.bold)

                HStack(spacing: 16) {
                    Label("\(saveData.playerHealth)/\(saveData.playerMaxHealth)", systemImage: "heart.fill")
                        .foregroundColor(AppColors.danger)
                    Label("\(saveData.playerFaith)", systemImage: "sparkles")
                        .foregroundColor(AppColors.faith)
                    Label("\(saveData.playerBalance)", systemImage: "scale.3d")
                        .foregroundColor(AppColors.dark)
                }
                .font(.subheadline)

                Text(L10n.dayNumber.localized(with: saveData.currentDay))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatDate(saveData.savedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .onTapGesture {
            onLoad()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Hero Selection Card (data-driven)

struct HeroSelectionCard: View {
    let hero: HeroDefinition
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Hero icon/name header
            VStack(spacing: 4) {
                Image(systemName: hero.icon)
                    .font(.system(size: 40))

                Text(hero.name.localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.dark.opacity(0.8))
            .foregroundColor(.white)

            // Stats
            Text(L10n.cardTypeCharacter.localized)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                StatMini(icon: "heart.fill", value: hero.baseStats.health, color: AppColors.health)
                StatMini(icon: "bolt.fill", value: hero.baseStats.strength, color: AppColors.power)
                StatMini(icon: "shield.fill", value: hero.baseStats.constitution, color: AppColors.defense)
            }
            .padding(.bottom, 8)
        }
        .background(AppColors.backgroundSystem)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? AppColors.primary : AppColors.secondary.opacity(0.3), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(radius: isSelected ? 8 : 2)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

struct StatMini: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Content Manager Helpers

#if DEBUG
/// Get bundled pack URLs for Content Manager
private func getBundledPackURLs() -> [URL] {
    var urls: [URL] = []
    if let heroesURL = CoreHeroesContent.packURL {
        urls.append(heroesURL)
    }
    if let storyURL = TwilightMarchesActIContent.packURL {
        urls.append(storyURL)
    }
    return urls
}
#endif

#Preview {
    ContentView()
}
