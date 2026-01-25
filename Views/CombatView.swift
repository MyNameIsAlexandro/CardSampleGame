import SwiftUI
import TwilightEngine

/// Боевой экран - реализация по документации GAME_DESIGN_DOCUMENT.md
/// Цикл: PlayerTurn → EnemyTurn → EndTurn (повтор до победы/поражения)
/// Действия: 3 за ход. Играть карту = 1 действие, Атаковать = 1 действие
///
/// Engine-First Architecture:
/// - All player mutations go through engine.performAction()
/// - UI reads state from engine properties
struct CombatView: View {
    // MARK: - Engine-First Architecture
    @ObservedObject var engine: TwilightGameEngine
    let onCombatEnd: (CombatOutcome) -> Void

    enum CombatOutcome: Equatable {
        case victory(stats: CombatStats)
        case defeat(stats: CombatStats)
        case fled

        var isVictory: Bool {
            if case .victory = self { return true }
            return false
        }
    }

    struct CombatStats: Equatable {
        let turnsPlayed: Int
        let totalDamageDealt: Int
        let totalDamageTaken: Int
        let cardsPlayed: Int

        var summary: String {
            L10n.combatTurnsStats.localized(with: turnsPlayed, totalDamageDealt, totalDamageTaken)
        }
    }

    enum CombatPhase {
        case playerTurn
        case enemyTurn
        case endTurn
        case combatOver
    }

    @State private var phase: CombatPhase = .playerTurn
    @State private var turnNumber: Int = 1
    @State private var actionsRemaining: Int = 3
    @State private var combatLog: [String] = []
    @State private var lastMessage: String = ""
    @State private var showingMessage = false

    // Боевые бонусы (сбрасываются в конце хода/после атаки)
    @State private var bonusDice: Int = 0          // Дополнительные кубики от карт
    @State private var bonusDamage: Int = 0        // Бонусный урон
    @State private var canReroll: Bool = false     // Возможность перебросить кубик
    @State private var summonedSpirits: [(power: Int, realm: Realm)] = []  // Призванные духи
    @State private var isFirstAttackThisCombat: Bool = true  // Для способности Следопыта
    @State private var lastCombatResult: CombatResult? = nil  // Последний результат атаки

    // NEW: Temporary Shield (защита от карт, поглощает урон, сбрасывается в конце раунда)
    @State private var temporaryShield: Int = 0

    // Combat statistics tracking
    @State private var totalDamageDealt: Int = 0
    @State private var totalDamageTaken: Int = 0
    @State private var cardsPlayedCount: Int = 0

    // Combat end state (for victory/defeat screen)
    @State private var finalCombatStats: CombatStats? = nil
    @State private var isVictory: Bool = false
    @State private var defeatedMonsterName: String = ""  // Saved before combat ends for UI
    @State private var savedMonsterCard: Card? = nil     // Saved monster for display after combat ends

    // Dice roll animation state
    @State private var showDiceRollOverlay: Bool = false
    @State private var animatingDiceValues: [Int] = []
    @State private var diceAnimationPhase: Int = 0
    @State private var pendingDamageApplication: (() -> Void)? = nil  // Deferred damage application

    // MARK: - Computed Properties (Engine-First)

    /// Monster from engine combat state
    /// Uses savedMonsterCard when combat is over to avoid "Unknown" display
    private var monster: Card {
        get {
            // After combat ends, use saved monster card to display correct info
            if phase == .combatOver, let saved = savedMonsterCard {
                return saved
            }
            return engine.combatState?.enemy ?? savedMonsterCard ?? Card(
                name: "Unknown",
                type: .monster,
                description: "Unknown enemy"
            )
        }
    }

    /// Monster health from engine (reads @Published property directly for SwiftUI reactivity)
    private var monsterHealth: Int {
        // After combat ends with victory, show 0 HP
        if phase == .combatOver {
            // Check if it was a victory (enemy defeated)
            if engine.combatEnemyHealth <= 0 {
                return 0
            }
            // Otherwise return last known value or monster's base health
            return engine.combatEnemyHealth > 0 ? engine.combatEnemyHealth : (monster.health ?? 10)
        }
        // During active combat, use engine value directly
        if engine.isInCombat {
            return engine.combatEnemyHealth
        }
        // Fallback for when combat hasn't started yet
        return monster.health ?? 10
    }

    // MARK: - Initialization (Engine-First only)

    init(engine: TwilightGameEngine, onCombatEnd: @escaping (CombatOutcome) -> Void) {
        self.engine = engine
        self.onCombatEnd = onCombatEnd
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hero Panel (persistent, consistent design)
            HeroPanel(engine: engine, compact: true, showAvatar: true)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.xxs)

            // Верхняя панель
            combatHeader

            // Основная область боя
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Монстр
                    monsterCard

                    // VS разделитель
                    vsIndicator

                    // Игрок
                    playerStats

                    // Инструкции и действия
                    if phase == .playerTurn {
                        playerTurnControls
                    } else if phase == .enemyTurn {
                        enemyTurnView
                    } else if phase == .endTurn {
                        endTurnView
                    } else if phase == .combatOver {
                        combatOverView
                    }

                    // Лог боя
                    combatLogView
                }
                .padding()
            }

            Divider()

            // Рука игрока
            playerHandView
        }
        .background(Color(UIColor.systemBackground))
        .accessibilityIdentifier(AccessibilityIdentifiers.Combat.view)
        .overlay {
            // Dice roll animation overlay
            if showDiceRollOverlay {
                diceRollOverlay
            }
        }
        .alert(L10n.combatTitle.localized, isPresented: $showingMessage) {
            Button(L10n.buttonOk.localized) { }
        } message: {
            Text(lastMessage)
        }
        .onAppear {
            startCombat()
        }
    }

    // MARK: - Header

    var combatHeader: some View {
        HStack {
            // Ход и фаза
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(L10n.combatTurnNumber.localized(with: turnNumber))
                    .font(.headline)
                Text(phaseText)
                    .font(.subheadline)
                    .foregroundColor(phaseColor)
            }

            Spacer()

            // Действия (показываем только в ход игрока)
            if phase == .playerTurn {
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < actionsRemaining ? AppColors.power : AppColors.secondary.opacity(Opacity.light))
                            .frame(width: Sizes.iconTiny, height: Sizes.iconTiny)
                    }
                }

                Text("\(actionsRemaining)/3")
                    .font(.headline)
                    .foregroundColor(AppColors.power)
                    .padding(.leading, Spacing.xxs)
            }

            Spacer()

            // Кнопка побега
            Button(action: flee) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "figure.run")
                    Text(L10n.combatFleeButton.localized)
                        .font(.caption)
                }
                .foregroundColor(AppColors.secondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(AppColors.secondary.opacity(Opacity.faint))
                .cornerRadius(CornerRadius.md)
            }
            .disabled(phase != .playerTurn)
        }
        .padding()
        .background(AppColors.cardBackground)
    }

    // MARK: - Monster Card

    var monsterCard: some View {
        VStack(spacing: Spacing.sm) {
            Text(monster.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.danger)

            HStack(spacing: Spacing.xxxl) {
                // HP монстра (Engine-First: read from engine.combatState)
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundColor(AppColors.health)
                    Text("\(monsterHealth)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(L10n.combatHP.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }

                // Атака монстра
                VStack {
                    Image(systemName: "burst.fill")
                        .font(.title)
                        .foregroundColor(AppColors.power)
                    Text("\(monster.power ?? 3)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(L10n.combatAttack.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }

                // Защита монстра
                VStack {
                    Image(systemName: "shield.fill")
                        .font(.title)
                        .foregroundColor(AppColors.defense)
                    Text("\(monster.defense ?? 10)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(L10n.combatDefense.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.danger.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(AppColors.danger, lineWidth: 2)
                )
        )
    }

    var vsIndicator: some View {
        HStack {
            Rectangle().fill(AppColors.danger.opacity(Opacity.medium)).frame(height: Spacing.xxxs)
            Text("⚔️ VS ⚔️")
                .font(.headline)
                .padding(.horizontal, Spacing.sm)
            Rectangle().fill(AppColors.danger.opacity(Opacity.medium)).frame(height: Spacing.xxxs)
        }
    }

    // MARK: - Player Stats (Engine-First: reads from engine.player*)

    var playerStats: some View {
        VStack(spacing: Spacing.sm) {
            // Main stats row
            HStack(spacing: Spacing.xl) {
                VStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(AppColors.health)
                    Text("\(engine.playerHealth)/\(engine.playerMaxHealth)")
                        .fontWeight(.bold)
                    Text(L10n.combatHP.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }

                VStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(AppColors.power)
                    Text("\(engine.playerStrength)")
                        .fontWeight(.bold)
                    Text(L10n.combatStrength.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }

                VStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppColors.faith)
                    Text("\(engine.playerFaith)")
                        .fontWeight(.bold)
                    Text(L10n.tmResourceFaith.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }

                // NEW: Shield display
                if temporaryShield > 0 {
                    VStack {
                        Image(systemName: "shield.fill")
                            .foregroundColor(.cyan)
                        Text("\(temporaryShield)")
                            .fontWeight(.bold)
                        Text(L10n.combatShield.localized)
                            .font(.caption)
                            .foregroundColor(AppColors.muted)
                    }
                }
            }

            // Combat bonuses indicator (if any)
            if bonusDice > 0 || bonusDamage > 0 {
                HStack(spacing: Spacing.md) {
                    if bonusDice > 0 {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "dice.fill")
                                .foregroundColor(AppColors.dark)
                            Text("+\(bonusDice)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.dark)
                        }
                    }
                    if bonusDamage > 0 {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(AppColors.power)
                            Text("+\(bonusDamage)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.power)
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(AppColors.dark.opacity(0.1))
                .cornerRadius(CornerRadius.md)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(AppColors.defense.opacity(0.1))
        )
    }

    // MARK: - Player Turn Controls

    var playerTurnControls: some View {
        VStack(spacing: Spacing.lg) {
            // Инструкция
            VStack(spacing: Spacing.xxs) {
                Text(L10n.combatPlayerTurn.localized)
                    .font(.headline)
                    .foregroundColor(AppColors.success)

                if actionsRemaining > 0 {
                    Text(L10n.combatActionsRemaining.localized(with: actionsRemaining))
                        .font(.subheadline)
                    Text(L10n.combatTapToPlay.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                } else {
                    Text(L10n.combatActionsRemaining.localized(with: 0))
                        .font(.subheadline)
                        .foregroundColor(AppColors.power)
                    Text(L10n.combatEndTurnButton.localized)
                        .font(.caption)
                        .foregroundColor(AppColors.muted)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppColors.success.opacity(0.1))
            .cornerRadius(CornerRadius.lg)

            // Кнопки действий (каждое действие тратит 1 из 3)
            HStack(spacing: Spacing.sm) {
                // Базовая атака
                Button(action: performBasicAttack) {
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                        Text(L10n.combatAttackButton.localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                        // Show accumulated bonuses
                        if bonusDamage > 0 || bonusDice > 0 {
                            Text("+\(bonusDamage)💥 +\(bonusDice)🎲")
                                .font(.system(size: 9))
                                .foregroundColor(AppColors.faith)
                        } else {
                            Text(L10n.combatActionCost.localized)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(Opacity.high))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(actionsRemaining > 0 ? AppColors.power : AppColors.secondary)
                    .foregroundColor(.white)
                    .cornerRadius(CornerRadius.lg)
                }
                .disabled(actionsRemaining <= 0)
                .accessibilityIdentifier(AccessibilityIdentifiers.Combat.attackButton)

                // NEW: Укрытие (Defend/Take Cover)
                Button(action: performDefend) {
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: "shield.fill")
                            .font(.title2)
                        Text(L10n.combatDefend.localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("+3🛡️ (-1)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(Opacity.high))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(actionsRemaining > 0 ? Color.cyan : AppColors.secondary)
                    .foregroundColor(.white)
                    .cornerRadius(CornerRadius.lg)
                }
                .disabled(actionsRemaining <= 0)

                // Завершить ход
                Button(action: endPlayerTurn) {
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text(L10n.combatEndTurnButton.localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.dark)
                    .foregroundColor(.white)
                    .cornerRadius(CornerRadius.lg)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.Combat.endTurnButton)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.Combat.actionBar)
        }
    }

    // MARK: - Enemy Turn View

    var enemyTurnView: some View {
        VStack(spacing: Spacing.md) {
            Text(L10n.combatEnemyTurn.localized)
                .font(.headline)
                .foregroundColor(AppColors.danger)

            HStack {
                Image(systemName: "burst.fill")
                    .foregroundColor(AppColors.danger)
                Text(L10n.combatLogEnemyAttacks.localized(with: monster.name))
            }

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.danger))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.danger.opacity(0.1))
        .cornerRadius(CornerRadius.lg)
        .onAppear {
            performEnemyAttack()
        }
    }

    // MARK: - End Turn View

    var endTurnView: some View {
        VStack(spacing: Spacing.md) {
            Text(L10n.combatEndTurn.localized)
                .font(.headline)
                .foregroundColor(AppColors.dark)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.dark))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.dark.opacity(0.1))
        .cornerRadius(CornerRadius.lg)
        .onAppear {
            performEndTurn()
        }
    }

    // MARK: - Combat Over View (Full-screen victory/defeat display)
    // Player must tap "Continue" to dismiss - no auto-dismiss

    var combatOverView: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            // Victory/Defeat Icon and Title
            if isVictory {
                VStack(spacing: Spacing.md) {
                    Text("🎉")
                        .font(.system(size: Sizes.iconRegion + Spacing.md))

                    Text(L10n.combatVictory.localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.success)

                    Text(L10n.combatMonsterDefeated.localized(with: defeatedMonsterName))
                        .font(.title3)
                        .foregroundColor(AppColors.muted)
                }
            } else {
                VStack(spacing: Spacing.md) {
                    Text("💀")
                        .font(.system(size: Sizes.iconRegion + Spacing.md))

                    Text(L10n.combatDefeat.localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.danger)

                    Text(L10n.combatFallen.localized)
                        .font(.title3)
                        .foregroundColor(AppColors.muted)
                }
            }

            // Combat Statistics
            if let stats = finalCombatStats {
                VStack(spacing: Spacing.lg) {
                    Text("📊 " + L10n.combatLogTitle.localized)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: Spacing.xxxl) {
                        // Turns
                        VStack {
                            Text("\(stats.turnsPlayed)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.defense)
                            Text(L10n.combatStatsTurns.localized)
                                .font(.caption)
                                .foregroundColor(AppColors.muted)
                        }

                        // Damage dealt
                        VStack {
                            Text("\(stats.totalDamageDealt)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.power)
                            Text(L10n.combatStatsDamageDealt.localized)
                                .font(.caption)
                                .foregroundColor(AppColors.muted)
                        }

                        // Damage taken
                        VStack {
                            Text("\(stats.totalDamageTaken)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.danger)
                            Text(L10n.combatStatsDamageTaken.localized)
                                .font(.caption)
                                .foregroundColor(AppColors.muted)
                        }

                        // Cards played
                        VStack {
                            Text("\(stats.cardsPlayed)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.dark)
                            Text(L10n.combatStatsCardsPlayed.localized)
                                .font(.caption)
                                .foregroundColor(AppColors.muted)
                        }
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(CornerRadius.lg)
            }

            Spacer()

            // Continue Button - player controls when to dismiss
            Button(action: {
                let stats = finalCombatStats ?? CombatStats(
                    turnsPlayed: turnNumber,
                    totalDamageDealt: totalDamageDealt,
                    totalDamageTaken: totalDamageTaken,
                    cardsPlayed: cardsPlayedCount
                )
                let outcome: CombatOutcome = isVictory ? .victory(stats: stats) : .defeat(stats: stats)
                onCombatEnd(outcome)
            }) {
                HStack {
                    Image(systemName: isVictory ? "arrow.right.circle.fill" : "arrow.counterclockwise.circle.fill")
                    Text(isVictory ? L10n.combatContinue.localized : L10n.combatReturn.localized)
                }
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isVictory ? AppColors.success : AppColors.defense)
                .cornerRadius(CornerRadius.lg)
            }
            .padding(.horizontal)
            .padding(.bottom, Spacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: isVictory
                    ? [AppColors.success.opacity(0.1), Color.black.opacity(Opacity.light)]
                    : [AppColors.danger.opacity(0.1), Color.black.opacity(Opacity.light)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Combat Log

    var combatLogView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Детальный результат последней атаки
            if let result = lastCombatResult {
                combatResultDetailView(result)
            }

            // Журнал боя
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("📜 " + L10n.combatLogTitle.localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.muted)

                ForEach(Array(combatLog.suffix(5).enumerated()), id: \.offset) { index, entry in
                    Text("• \(entry)")
                        .font(.caption2)
                        .foregroundColor(AppColors.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(CornerRadius.md)
        }
    }

    /// Детальный вид результата атаки
    func combatResultDetailView(_ result: CombatResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Заголовок попадание/промах
            HStack {
                Text(result.isHit ? L10n.combatHitResult.localized : L10n.combatMissResult.localized)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(result.isHit ? AppColors.success : AppColors.danger)

                Spacer()

                // Общий результат
                Text(L10n.combatAttackVsDefense.localized(with: result.attackRoll.total, result.defenseValue))
                    .font(.caption)
                    .foregroundColor(AppColors.muted)
            }

            Divider()

            // Разбивка броска атаки
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(L10n.combatAttackRollTitle.localized)
                    .font(.caption)
                    .fontWeight(.semibold)

                HStack(spacing: Spacing.xxs) {
                    Text("💪 \(result.attackRoll.baseStrength)")
                        .font(.caption2)

                    Text("+")
                        .font(.caption2)
                        .foregroundColor(AppColors.muted)

                    // Кубики
                    ForEach(result.attackRoll.diceRolls.indices, id: \.self) { index in
                        diceView(result.attackRoll.diceRolls[index])
                    }

                    if result.attackRoll.bonusDamage > 0 {
                        Text("+ \(result.attackRoll.bonusDamage)")
                            .font(.caption2)
                            .foregroundColor(AppColors.power)
                    }

                    Text("= \(result.attackRoll.total)")
                        .font(.caption)
                        .fontWeight(.bold)
                }

                // Модификаторы атаки
                ForEach(result.attackRoll.modifiers.indices, id: \.self) { index in
                    let modifier = result.attackRoll.modifiers[index]
                    Text("\(modifier.icon) \(modifier.description)")
                        .font(.caption2)
                        .foregroundColor(AppColors.defense)
                }
            }

            // Расчёт урона (если попадание)
            if result.isHit, let damage = result.damageCalculation {
                Divider()

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(L10n.combatDamageCalcTitle.localized)
                        .font(.caption)
                        .fontWeight(.semibold)

                    HStack {
                        Text(L10n.combatBaseValue.localized(with: damage.base))
                            .font(.caption2)

                        ForEach(damage.modifiers.indices, id: \.self) { index in
                            let mod = damage.modifiers[index]
                            Text("\(mod.value > 0 ? "+" : "")\(mod.value)")
                                .font(.caption2)
                                .foregroundColor(mod.value > 0 ? AppColors.success : AppColors.danger)
                        }

                        Text("= \(damage.total) 💥")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.danger)
                    }

                    // Детализация модификаторов урона
                    ForEach(damage.modifiers.indices, id: \.self) { index in
                        let modifier = damage.modifiers[index]
                        HStack(spacing: Spacing.xxs) {
                            Text(modifier.icon)
                            Text(modifier.description)
                            Text("\(modifier.value > 0 ? "+" : "")\(modifier.value)")
                                .foregroundColor(modifier.value > 0 ? AppColors.success : AppColors.danger)
                        }
                        .font(.caption2)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(result.isHit ? AppColors.success.opacity(0.1) : AppColors.danger.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(result.isHit ? AppColors.success : AppColors.danger, lineWidth: 1)
                )
        )
    }

    /// Вид кубика
    func diceView(_ value: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(Color.white)
                .frame(width: Spacing.xxl, height: Spacing.xxl)
                .shadow(radius: 1)

            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(value >= 5 ? AppColors.success : value <= 2 ? AppColors.danger : .black)
        }
    }

    // MARK: - Dice Roll Overlay

    /// Prominent dice roll animation overlay
    var diceRollOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(Opacity.mediumHigh)
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                // Title
                Text(L10n.combatDiceRoll.localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Animated dice
                HStack(spacing: Spacing.lg) {
                    ForEach(animatingDiceValues.indices, id: \.self) { index in
                        animatedDiceView(value: animatingDiceValues[index], index: index)
                    }
                }
                .padding()

                // Result display (after animation completes)
                if let result = lastCombatResult, diceAnimationPhase >= 3 {
                    VStack(spacing: Spacing.md) {
                        // Attack total
                        HStack(spacing: Spacing.sm) {
                            Text("💪 \(result.attackRoll.baseStrength)")
                                .foregroundColor(.cyan)
                            Text("+")
                                .foregroundColor(.white)
                            Text("🎲 \(result.attackRoll.diceTotal)")
                                .foregroundColor(AppColors.faith)
                            if result.attackRoll.bonusDamage > 0 {
                                Text("+")
                                    .foregroundColor(.white)
                                Text("⚔️ \(result.attackRoll.bonusDamage)")
                                    .foregroundColor(AppColors.power)
                            }
                            Text("=")
                                .foregroundColor(.white)
                            Text("\(result.attackRoll.total)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .font(.headline)

                        // VS Defense
                        HStack(spacing: Spacing.sm) {
                            Text("vs")
                                .foregroundColor(AppColors.secondary)
                            Text(L10n.combatDefenseValue.localized(with: result.defenseValue))
                                .foregroundColor(AppColors.defense)
                        }
                        .font(.subheadline)

                        // Hit/Miss result
                        if result.isHit {
                            VStack(spacing: Spacing.xxs) {
                                Text(L10n.combatHitResult.localized)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.success)

                                if let damage = result.damageCalculation {
                                    Text(L10n.combatDamageValue.localized(with: damage.total))
                                        .font(.headline)
                                        .foregroundColor(AppColors.danger)
                                }
                            }
                        } else {
                            Text(L10n.combatMissResult.localized)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.danger)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .fill(Color.black.opacity(Opacity.high))
                    )
                    .transition(.scale.combined(with: .opacity))

                    // Confirmation button - applies damage and closes overlay
                    Button(action: confirmAttackResult) {
                        Text(L10n.buttonOk.localized)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: Sizes.buttonMinWidth, height: Sizes.touchTarget)
                            .background(result.isHit ? AppColors.success : AppColors.danger)
                            .cornerRadius(CornerRadius.lg)
                    }
                    .padding(.top, Spacing.lg)
                }
            }
        }
    }

    /// Confirm attack result - applies pending damage and closes overlay
    func confirmAttackResult() {
        // Apply the pending damage
        pendingDamageApplication?()
        pendingDamageApplication = nil

        // Close overlay
        withAnimation(.easeOut(duration: 0.2)) {
            showDiceRollOverlay = false
        }
    }

    /// Single animated dice
    func animatedDiceView(value: Int, index: Int) -> some View {
        ZStack {
            // Dice background
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.white)
                .frame(width: Sizes.iconRegion, height: Sizes.iconRegion)
                .shadow(color: .black.opacity(Opacity.light), radius: 4, x: 2, y: 2)

            // Dice value
            Text("\(value)")
                .font(.system(size: Sizes.iconLarge, weight: .bold, design: .rounded))
                .foregroundColor(value >= 5 ? AppColors.success : value <= 2 ? AppColors.danger : .black)
        }
        .scaleEffect(diceAnimationPhase >= 2 ? 1.0 : 1.2)
        .rotationEffect(.degrees(diceAnimationPhase >= 2 ? 0 : Double(index * 30)))
        .animation(
            .spring(response: AnimationDuration.slow, dampingFraction: 0.6),
            value: diceAnimationPhase
        )
    }

    /// Trigger dice roll animation
    func showDiceAnimation(diceRolls: [Int]) {
        // Start with random values
        animatingDiceValues = diceRolls.map { _ in Int.random(in: 1...6) }
        diceAnimationPhase = 0

        withAnimation(.easeIn(duration: 0.1)) {
            showDiceRollOverlay = true
        }

        // Animation sequence: roll several times then show final result
        let rollDuration = 0.1

        // Roll 1
        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration) {
            animatingDiceValues = diceRolls.map { _ in Int.random(in: 1...6) }
            diceAnimationPhase = 1
        }

        // Roll 2
        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration * 2) {
            animatingDiceValues = diceRolls.map { _ in Int.random(in: 1...6) }
        }

        // Roll 3
        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration * 3) {
            animatingDiceValues = diceRolls.map { _ in Int.random(in: 1...6) }
        }

        // Final result
        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration * 4) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                animatingDiceValues = diceRolls
                diceAnimationPhase = 2
            }
        }

        // Show hit/miss result and OK button
        DispatchQueue.main.asyncAfter(deadline: .now() + rollDuration * 4 + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                diceAnimationPhase = 3
            }
        }
        // No auto-dismiss - player must tap OK button to confirm and apply damage
    }

    // MARK: - Player Hand (Engine-First)

    /// Player's hand cards from engine
    private var playerHand: [Card] {
        engine.playerHand
    }

    var playerHandView: some View {
        VStack(spacing: Spacing.xxs) {
            HStack {
                Text("🃏 " + L10n.combatYourHand.localized + " (\(playerHand.count))")
                    .font(.caption)
                    .foregroundColor(AppColors.muted)

                Spacer()

                if phase == .playerTurn && actionsRemaining > 0 {
                    Text(L10n.combatTapToPlay.localized)
                        .font(.system(size: Spacing.smd))
                        .foregroundColor(AppColors.success)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(playerHand) { card in
                        CombatCardView(
                            card: card,
                            canPlay: actionsRemaining > 0 && phase == .playerTurn
                        ) {
                            playCard(card)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(height: Sizes.cardHeightMedium + Spacing.smd)
        .background(AppColors.cardBackground)
    }

    // MARK: - Combat Logic (Engine-First: uses engine.performAction())

    func startCombat() {
        // Save monster card for display after combat ends
        savedMonsterCard = engine.combatState?.enemy

        combatLog.append(L10n.combatLogBattleStartEnemy.localized(with: monster.name))
        combatLog.append(L10n.combatLogActionsInfo.localized(with: 3))

        // Engine-First: Initialize combat through engine
        // This handles: shuffle deck, draw initial hand
        engine.performAction(.combatInitialize)

        actionsRemaining = 3
        phase = .playerTurn
    }

    func performBasicAttack() {
        guard actionsRemaining > 0 else { return }

        actionsRemaining -= 1

        let monsterDef = monster.defense ?? 10
        let monsterCurrentHP = monsterHealth
        let monsterMaxHP = monster.health ?? 10

        // Engine-First: Use Engine-based calculator (no Player dependency)
        let result = CombatCalculator.calculateAttackEngineFirst(
            engine: engine,
            monsterDefense: monsterDef,
            monsterCurrentHP: monsterCurrentHP,
            monsterMaxHP: monsterMaxHP,
            bonusDice: bonusDice,
            bonusDamage: bonusDamage,
            isFirstAttack: isFirstAttackThisCombat
        )

        // Сохраняем результат для отображения
        lastCombatResult = result

        // Store damage application to be called when player confirms
        pendingDamageApplication = { [self] in
            if result.isHit, let damageCalc = result.damageCalculation {
                let damage = damageCalc.total

                // Track damage for statistics
                totalDamageDealt += damage

                // Engine-First: Apply damage through engine action
                engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: damage)))

                combatLog.append(L10n.combatLogHit.localized(with: result.attackRoll.total, monsterDef, damage, monsterHealth))

                if monsterHealth <= 0 {
                    finishCombat(victory: true)
                }
            } else {
                combatLog.append(L10n.combatLogMissed.localized(with: result.attackRoll.total, monsterDef))
            }
        }

        // Show dice roll animation (player will confirm to apply damage)
        showDiceAnimation(diceRolls: result.attackRoll.diceRolls)

        // Сбросить бонусы после атаки
        bonusDice = 0
        bonusDamage = 0
        isFirstAttackThisCombat = false
    }

    /// Take Cover / Defend action - adds shield to absorb damage
    func performDefend() {
        guard actionsRemaining > 0 else { return }

        actionsRemaining -= 1

        // Base defend gives +3 shield
        let baseShield = 3

        // Engine-First: use engine strength (no Player dependency)
        let strengthBonus = engine.playerStrength / 2  // Half strength as shield bonus

        let totalShield = baseShield + strengthBonus
        temporaryShield += totalShield

        combatLog.append(L10n.combatLogCover.localized(with: totalShield, temporaryShield))

        // Log breakdown
        if strengthBonus > 0 {
            combatLog.append(L10n.combatLogStrengthBonus.localized(with: strengthBonus))
        }
    }

    /// Play a card as a modifier (does NOT consume actions)
    /// Cards enhance the next action (attack) or add to shield (defense)
    func playCard(_ card: Card) {
        guard phase == .playerTurn else { return }

        // Проверяем стоимость веры (Engine-First: check via engine)
        // Cards cost Faith to play - this limits infinite card usage
        let faithCost = card.cost ?? 0
        if faithCost > 0 {
            guard engine.playerFaith >= faithCost else {
                combatLog.append(L10n.combatLogInsufficientFaith.localized(with: card.name, faithCost, engine.playerFaith))
                return
            }
            // Engine-First: Spend faith through engine action
            engine.performAction(.combatApplyEffect(effect: .spendFaith(amount: faithCost)))
            combatLog.append(L10n.combatLogFaithSpent.localized(with: faithCost))
        }

        // Track cards played for statistics
        cardsPlayedCount += 1

        // Engine-First: Use engine action to play card (moves from hand to discard)
        engine.performAction(.playCard(cardId: card.id, targetId: nil))

        // NEW: Cards are modifiers, not actions
        // Defense cards add to temporary shield
        // Attack cards add to bonus damage/dice
        switch card.type {
        case .defense, .armor:
            // Defense cards add to temporary shield
            let shieldValue = card.defense ?? card.power ?? 2
            temporaryShield += shieldValue
            combatLog.append(L10n.combatLogShieldCard.localized(with: card.name, shieldValue, temporaryShield))

        case .attack, .weapon:
            // Attack cards add bonus damage
            let attackBonus = card.power ?? 2
            bonusDamage += attackBonus
            combatLog.append(L10n.combatLogAttackBonus.localized(with: card.name, attackBonus))

        case .spell, .ritual:
            // Spells apply their effects
            combatLog.append(L10n.combatLogSpellCast.localized(with: card.name))
            applyCardEffects(card)

        default:
            // Other cards (items, etc.) apply their effects
            combatLog.append(L10n.combatLogCardPlayed.localized(with: card.name))
            applyCardEffects(card)
        }

        // Apply card abilities (on top of type-based effects)
        if card.type != .spell && card.type != .ritual {
            applyCardEffects(card)
        }

        // Проверяем победу (Engine-First: read from engine)
        if monsterHealth <= 0 {
            finishCombat(victory: true)
        }
    }

    func applyCardEffects(_ card: Card) {
        for ability in card.abilities {
            switch ability.effect {
            case .heal(let amount):
                // Engine-First: Heal through engine action
                engine.performAction(.combatApplyEffect(effect: .heal(amount: amount)))
                combatLog.append(L10n.combatLogHealEffect.localized(with: amount))

            case .damage(let amount, _):
                // Engine-First: Use engine's calculateDamageDealt (no Player dependency)
                let actualDamage = engine.calculateDamageDealt(amount)
                // Engine-First: Damage enemy through engine action
                engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: actualDamage)))
                // Monster health updated via engine.performAction() - no legacy sync needed
                combatLog.append(L10n.combatLogDamageEffect.localized(with: actualDamage, monsterHealth))

            case .drawCards(let count):
                // Engine-First: Draw cards through engine action (handles deck recycling)
                engine.performAction(.combatApplyEffect(effect: .drawCards(count: count)))
                combatLog.append(L10n.combatLogDrawCards.localized(with: count))

            case .gainFaith(let amount):
                // Engine-First: Gain faith through engine action
                engine.performAction(.combatApplyEffect(effect: .gainFaith(amount: amount)))
                combatLog.append(L10n.combatLogFaithGained.localized(with: amount))

            case .removeCurse(let type):
                // Engine-First: Remove curse through engine action (convert CurseType to String)
                engine.performAction(.combatApplyEffect(effect: .removeCurse(type: type?.rawValue)))
                combatLog.append(L10n.combatLogCurseRemoved.localized)

            case .addDice(let count):
                // Engine-First: Add bonus dice through engine action
                engine.performAction(.combatApplyEffect(effect: .addBonusDice(count: count)))
                bonusDice += count  // Local tracking for UI
                combatLog.append(L10n.combatLogBonusDice.localized(with: count))

            case .reroll:
                // Reroll даёт +1 кубик (выбирается лучший результат)
                engine.performAction(.combatApplyEffect(effect: .addBonusDice(count: 1)))
                bonusDice += 1
                combatLog.append(L10n.combatLogReroll.localized)

            case .shiftBalance(let towards, let amount):
                // Engine-First: Shift balance through engine action
                let directionString = towards == .light ? "light" : towards == .dark ? "dark" : "equilibrium"
                engine.performAction(.combatApplyEffect(effect: .shiftBalance(towards: directionString, amount: amount)))
                let directionText = towards == .light ? L10n.balanceLight.localized : towards == .dark ? L10n.balanceDark.localized : L10n.balanceNeutral.localized
                combatLog.append(L10n.combatLogBalanceShift.localized(with: directionText, amount))

            case .applyCurse(let curseType, let duration):
                // В бою проклятие наносит урон монстру (тёмная магия)
                let curseDamage = duration * 2
                // Engine-First: Damage enemy through engine action
                engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: curseDamage)))
                // Monster health updated via engine.performAction() - no legacy sync needed
                combatLog.append(L10n.combatLogCurseDamage.localized(with: curseType.rawValue, curseDamage))

            case .summonSpirit(let power, let realm):
                summonedSpirits.append((power: power, realm: realm))
                let realmName = realm == .yav ? L10n.realmYav.localized : realm == .nav ? L10n.realmNav.localized : L10n.realmPrav.localized
                let realmString = realm == .yav ? "yav" : realm == .nav ? "nav" : "prav"
                combatLog.append(L10n.combatLogSpiritSummoned.localized(with: realmName, power))
                // Engine-First: Spirit attacks enemy immediately through engine action
                engine.performAction(.combatApplyEffect(effect: .summonSpirit(power: power, realm: realmString)))
                // Monster health updated via engine.performAction() - no legacy sync needed
                combatLog.append(L10n.combatLogSpiritAttack.localized(with: power))

            case .sacrifice(let cost, let benefit):
                // Engine-First: Take damage through engine action
                engine.performAction(.combatApplyEffect(effect: .takeDamage(amount: cost)))
                combatLog.append("   🩸 Жертва: -\(cost) HP")
                // Парсим benefit для эффекта
                if benefit.lowercased().contains("урон") || benefit.lowercased().contains("damage") {
                    engine.performAction(.combatApplyEffect(effect: .addBonusDamage(amount: cost * 2)))
                    bonusDamage += cost * 2
                    combatLog.append("   🔥 +\(cost * 2) к урону следующей атаки")
                } else if benefit.lowercased().contains("карт") || benefit.lowercased().contains("draw") {
                    // Engine-First: Draw cards through engine action
                    engine.performAction(.combatApplyEffect(effect: .drawCards(count: cost)))
                    combatLog.append("   🃏 Взято карт: \(cost)")
                } else {
                    // Общий бонус - добавить урон
                    engine.performAction(.combatApplyEffect(effect: .addBonusDamage(amount: cost)))
                    bonusDamage += cost
                    combatLog.append("   🔥 +\(cost) к урону (\(benefit))")
                }

            case .explore:
                // Исследование не применимо в бою
                combatLog.append("   🔍 Исследование недоступно в бою")

            case .travelRealm:
                // Путешествие между мирами не применимо в бою
                combatLog.append("   🌀 Путешествие недоступно в бою")

            case .permanentStat(let stat, let amount):
                // Постоянный бонус к характеристике
                combatLog.append("   ⬆️ Постоянный бонус: +\(amount) к \(stat)")

            case .temporaryStat(let stat, let amount, let duration):
                // Временный бонус к характеристике
                if stat == "defense" {
                    temporaryShield += amount
                    combatLog.append("   🛡️ +\(amount) к защите на \(duration) ход(а)")
                } else {
                    bonusDamage += amount
                    combatLog.append("   ⬆️ +\(amount) к \(stat) на \(duration) ход(а)")
                }

            case .custom(let description):
                combatLog.append("   📜 \(description)")
            }
        }
    }

    func endPlayerTurn() {
        phase = .enemyTurn
    }

    func performEnemyAttack() {
        // Capture engine weakly to prevent retain cycles (engine is a class)
        let engineRef = engine
        let monsterName = monster.name
        let monsterPowerVal = monster.power ?? 3
        let currentShield = temporaryShield

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak engineRef] in
            guard let engine = engineRef else { return }
            guard engine.combatState?.enemyHealth ?? 0 > 0 else {
                phase = .endTurn
                return
            }

            var rawDamage = monsterPowerVal
            var shieldAbsorbed = 0
            var actualDamage = 0

            // Shield absorbs damage first
            if currentShield > 0 {
                shieldAbsorbed = min(currentShield, rawDamage)
                rawDamage -= shieldAbsorbed
                temporaryShield -= shieldAbsorbed
            }

            // Remaining damage goes to HP (Engine-First: uses takeDamageWithModifiers)
            if rawDamage > 0 {
                let healthBefore = engine.playerHealth
                // Engine handles curse modifiers and hero damage reduction
                engine.takeDamageWithModifiers(rawDamage, fromDarkSource: true)
                actualDamage = healthBefore - engine.playerHealth
            }

            // Track damage taken for statistics (only HP damage, not shield)
            totalDamageTaken += actualDamage

            // Build detailed combat log message
            var logMessage = "👹 \(monsterName) атакует! Сила: \(monsterPowerVal)"
            if shieldAbsorbed > 0 {
                logMessage += " | 🛡️ Щит поглотил: \(shieldAbsorbed)"
            }
            if actualDamage > 0 {
                logMessage += " | 💔 Урон HP: \(actualDamage)"
            } else if shieldAbsorbed == monsterPowerVal {
                logMessage += " | ✨ Полностью заблокировано!"
            }
            logMessage += " (HP: \(engine.playerHealth)/\(engine.playerMaxHealth), Щит: \(temporaryShield))"
            combatLog.append(logMessage)

            if engine.playerHealth <= 0 {
                finishCombat(victory: false)
            } else {
                phase = .endTurn
            }
        }
    }

    func performEndTurn() {
        // Capture engine weakly to prevent retain cycles
        let engineRef = engine
        let currentSpirits = summonedSpirits

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak engineRef] in
            guard let engine = engineRef else { return }

            // Духи атакуют в конце хода (если ещё живы)
            if !currentSpirits.isEmpty {
                for spirit in currentSpirits {
                    let spiritDamage = spirit.power
                    // Engine-First: Spirit damage through engine action
                    engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: spiritDamage)))
                    let realmName = spirit.realm == .yav ? "Явь" : spirit.realm == .nav ? "Навь" : "Правь"
                    combatLog.append("👻 Дух \(realmName) атакует: \(spiritDamage) урона")
                }
                // Духи исчезают после атаки
                summonedSpirits.removeAll()
            }

            // Проверяем победу после атак духов (Engine-First: read from engine)
            if engine.combatState?.enemyHealth ?? 0 <= 0 {
                finishCombat(victory: true)
                return
            }

            // Сбрасываем бонусы и щит на конец раунда
            if temporaryShield > 0 {
                combatLog.append("🛡️ Временный щит рассеялся (\(temporaryShield) → 0)")
            }
            bonusDice = 0
            bonusDamage = 0
            temporaryShield = 0  // Shield resets at end of round
            canReroll = false

            // Engine-First: End turn phase through engine action (discard, draw, faith restore)
            // This handles: discard hand, recycle deck, draw new hand, restore faith
            engine.performAction(.combatEndTurnPhase)

            // Способность Мага: +1 вера в конце хода (Медитация) - now handled by Engine
            if engine.shouldGainFaithEndOfTurn {
                combatLog.append("🔮 Медитация: +1 вера")
            }

            // Новый ход
            turnNumber += 1
            actionsRemaining = 3

            combatLog.append("━━━ Ход \(turnNumber) ━━━")

            phase = .playerTurn
        }
    }

    func finishCombat(victory: Bool) {
        phase = .combatOver

        // Save monster name BEFORE engine clears combatEnemy
        defeatedMonsterName = monster.name

        // Engine-First: Finish combat through engine action
        engine.performAction(.combatFinish(victory: victory))

        // Create combat statistics
        let stats = CombatStats(
            turnsPlayed: turnNumber,
            totalDamageDealt: totalDamageDealt,
            totalDamageTaken: totalDamageTaken,
            cardsPlayed: cardsPlayedCount
        )

        // Store stats for display in victory/defeat screen
        finalCombatStats = stats
        isVictory = victory

        if victory {
            combatLog.append("🎉 Победа! \(defeatedMonsterName) повержен!")
            combatLog.append("📊 \(stats.summary)")
        } else {
            combatLog.append("💀 Поражение...")
            combatLog.append("📊 \(stats.summary)")
        }

        // NOTE: No auto-dismiss! Player taps "Continue" button in combatOverView
        // This lets the player enjoy the victory moment and review stats
    }

    func flee() {
        // Engine-First: Flee combat through engine action
        engine.performAction(.combatFlee)

        combatLog.append("🏃 Вы сбежали из боя!")
        onCombatEnd(.fled)
    }

    // MARK: - Helpers

    var phaseText: String {
        switch phase {
        case .playerTurn: return L10n.combatPlayerTurn.localized
        case .enemyTurn: return L10n.combatEnemyTurn.localized
        case .endTurn: return L10n.combatEndTurn.localized
        case .combatOver: return L10n.combatOver.localized
        }
    }

    var phaseColor: Color {
        switch phase {
        case .playerTurn: return .green
        case .enemyTurn: return .red
        case .endTurn: return .purple
        case .combatOver: return .gray
        }
    }
}

// MARK: - Combat Card View

struct CombatCardView: View {
    let card: Card
    let canPlay: Bool
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            // Название карты
            Text(card.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Стоимость веры (если есть)
            if let cost = card.cost, cost > 0 {
                HStack(spacing: Spacing.xxxs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: Spacing.smd))
                    Text("\(cost)")
                        .font(.caption2)
                }
                .foregroundColor(AppColors.faith)
            }

            // Тип карты
            Text(cardTypeText)
                .font(.system(size: 9))
                .foregroundColor(cardTypeColor)
                .fontWeight(.medium)

            // Основной эффект
            if let ability = card.abilities.first {
                Text(abilityText(ability))
                    .font(.system(size: Spacing.smd))
                    .foregroundColor(AppColors.muted)
                    .lineLimit(2)
            }
        }
        .frame(width: Sizes.cardWidthSmall + 5, height: Sizes.cardHeightSmall + Spacing.smd)
        .padding(Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(canPlay ? cardBorder : AppColors.secondary, lineWidth: canPlay ? 2 : 1)
                )
        )
        .opacity(canPlay ? Opacity.opaque : Opacity.medium)
        .scaleEffect(canPlay ? 1.0 : 0.95)
        .onTapGesture {
            if canPlay {
                onPlay()
            }
        }
    }

    var cardTypeText: String {
        switch card.type {
        case .attack: return "⚔️ Атака"
        case .defense: return "🛡 Защита"
        case .spell: return "✨ Заклинание"
        case .resource: return "💰 Ресурс"
        default: return "📜 Карта"
        }
    }

    var cardTypeColor: Color {
        switch card.type {
        case .attack: return AppColors.danger
        case .defense: return AppColors.defense
        case .spell: return AppColors.dark
        case .resource: return AppColors.faith
        default: return AppColors.secondary
        }
    }

    var cardBackground: Color {
        switch card.type {
        case .attack: return AppColors.danger.opacity(0.15)
        case .defense: return AppColors.defense.opacity(0.15)
        case .spell: return AppColors.dark.opacity(0.15)
        case .resource: return AppColors.faith.opacity(0.15)
        default: return AppColors.secondary.opacity(0.15)
        }
    }

    var cardBorder: Color {
        switch card.type {
        case .attack: return AppColors.danger
        case .defense: return AppColors.defense
        case .spell: return AppColors.dark
        case .resource: return AppColors.faith
        default: return AppColors.secondary
        }
    }

    func abilityText(_ ability: CardAbility) -> String {
        switch ability.effect {
        case .damage(let amount, _): return "Урон: \(amount)"
        case .heal(let amount): return "Лечение: +\(amount)"
        case .drawCards(let count): return "Карты: +\(count)"
        case .gainFaith(let amount): return "Вера: +\(amount)"
        case .addDice(let count): return "+\(count) 🎲"
        case .reroll: return "Перебросок"
        case .shiftBalance(let towards, let amount):
            let dir = towards == .light ? "☀️" : towards == .dark ? "🌙" : "⚖️"
            return "\(dir) +\(amount)"
        case .applyCurse(let type, _): return "Проклятие: \(type)"
        case .removeCurse: return "Снять проклятие"
        case .summonSpirit(let power, let realm):
            let realmIcon = realm == .yav ? "🌳" : realm == .nav ? "💀" : "⭐"
            return "\(realmIcon) Дух (\(power))"
        case .sacrifice(let cost, _): return "Жертва: \(cost) HP"
        case .explore: return "Исследовать"
        case .travelRealm(let realm):
            let realmName = realm == .yav ? "Явь" : realm == .nav ? "Навь" : "Правь"
            return "→ \(realmName)"
        case .permanentStat(let stat, let amount): return "+\(amount) \(stat)"
        case .temporaryStat(let stat, let amount, let duration): return "+\(amount) \(stat) (\(duration))"
        case .custom: return ability.description
        }
    }
}
