import SwiftUI

/// Боевой экран - реализация по документации GAME_DESIGN_DOCUMENT.md
/// Цикл: PlayerTurn → EnemyTurn → EndTurn (повтор до победы/поражения)
/// Действия: 3 за ход. Играть карту = 1 действие, Атаковать = 1 действие
///
/// Engine-First Architecture (Gate 1 Compliant):
/// - All player mutations go through engine.performAction()
/// - UI reads state from engine properties
struct CombatView: View {
    // MARK: - Engine-First Architecture
    @ObservedObject var engine: TwilightGameEngine
    let onCombatEnd: (CombatOutcome) -> Void

    // MARK: - Legacy Support (for backwards compatibility during migration)
    // Will be removed after full migration
    private var legacyPlayer: Player?
    private var legacyMonster: Binding<Card>?

    enum CombatOutcome {
        case victory
        case defeat
        case fled
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

    // Боевые бонусы (сбрасываются в конце хода)
    @State private var bonusDice: Int = 0          // Дополнительные кубики от карт
    @State private var bonusDamage: Int = 0        // Бонусный урон
    @State private var canReroll: Bool = false     // Возможность перебросить кубик
    @State private var summonedSpirits: [(power: Int, realm: Realm)] = []  // Призванные духи
    @State private var isFirstAttackThisCombat: Bool = true  // Для способности Следопыта
    @State private var lastCombatResult: CombatResult? = nil  // Последний результат атаки

    // MARK: - Computed Properties (Engine-First)

    /// Player from engine or legacy
    private var player: Player? {
        // In Engine-First mode, we use engine's player adapter
        // For now, use legacy player if available
        legacyPlayer
    }

    /// Monster from engine combat state or legacy binding
    private var monster: Card {
        get {
            engine.combatState?.enemy ?? legacyMonster?.wrappedValue ?? Card(
                name: "Unknown",
                type: .monster,
                description: "Unknown enemy"
            )
        }
    }

    /// Monster health from engine
    private var monsterHealth: Int {
        engine.combatState?.enemyHealth ?? monster.health ?? 10
    }

    // MARK: - Initialization (Engine-First)

    init(engine: TwilightGameEngine, onCombatEnd: @escaping (CombatOutcome) -> Void) {
        self.engine = engine
        self.onCombatEnd = onCombatEnd
        self.legacyPlayer = nil
        self.legacyMonster = nil
    }

    // MARK: - Legacy Initialization (for backwards compatibility)

    init(player: Player, monster: Binding<Card>, onCombatEnd: @escaping (CombatOutcome) -> Void) {
        // Create engine connected to legacy player
        let newEngine = TwilightGameEngine()
        // Setup combat enemy in engine
        newEngine.setupCombatEnemy(monster.wrappedValue)
        self.engine = newEngine
        self.onCombatEnd = onCombatEnd
        self.legacyPlayer = player
        self.legacyMonster = monster
    }

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель
            combatHeader

            // Основная область боя
            ScrollView {
                VStack(spacing: 16) {
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
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.combatTurnNumber.localized(with: turnNumber))
                    .font(.headline)
                Text(phaseText)
                    .font(.subheadline)
                    .foregroundColor(phaseColor)
            }

            Spacer()

            // Действия (показываем только в ход игрока)
            if phase == .playerTurn {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < actionsRemaining ? Color.orange : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }

                Text("\(actionsRemaining)/3")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding(.leading, 4)
            }

            Spacer()

            // Кнопка побега
            Button(action: flee) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.run")
                    Text(L10n.combatFleeButton.localized)
                        .font(.caption)
                }
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .disabled(phase != .playerTurn)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Monster Card

    var monsterCard: some View {
        VStack(spacing: 8) {
            Text(monster.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)

            HStack(spacing: 32) {
                // HP монстра (Engine-First: read from engine.combatState)
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("\(monsterHealth)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(L10n.combatHP.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Атака монстра
                VStack {
                    Image(systemName: "burst.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("\(monster.power ?? 3)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(L10n.combatAttack.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Защита монстра
                VStack {
                    Image(systemName: "shield.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("\(monster.defense ?? 10)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(L10n.combatDefense.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 2)
                )
        )
    }

    var vsIndicator: some View {
        HStack {
            Rectangle().fill(Color.red.opacity(0.5)).frame(height: 2)
            Text("⚔️ VS ⚔️")
                .font(.headline)
                .padding(.horizontal, 8)
            Rectangle().fill(Color.red.opacity(0.5)).frame(height: 2)
        }
    }

    // MARK: - Player Stats (Engine-First: reads from engine.player*)

    var playerStats: some View {
        HStack(spacing: 24) {
            VStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(engine.playerHealth)/\(engine.playerMaxHealth)")
                    .fontWeight(.bold)
                Text(L10n.combatHP.localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                Text("\(player?.strength ?? 1)")
                    .fontWeight(.bold)
                Text(L10n.combatStrength.localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("\(engine.playerFaith)")
                    .fontWeight(.bold)
                Text(L10n.tmResourceFaith.localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }

    // MARK: - Player Turn Controls

    var playerTurnControls: some View {
        VStack(spacing: 16) {
            // Инструкция
            VStack(spacing: 4) {
                Text(L10n.combatPlayerTurn.localized)
                    .font(.headline)
                    .foregroundColor(.green)

                if actionsRemaining > 0 {
                    Text(L10n.combatActionsRemaining.localized(with: actionsRemaining))
                        .font(.subheadline)
                    Text(L10n.combatTapToPlay.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(L10n.combatActionsRemaining.localized(with: 0))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    Text(L10n.combatEndTurnButton.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            // Кнопки действий
            HStack(spacing: 12) {
                // Базовая атака
                Button(action: performBasicAttack) {
                    VStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                        Text(L10n.combatAttackButton.localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("(-1)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(actionsRemaining > 0 ? Color.orange : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(actionsRemaining <= 0)
                .accessibilityIdentifier(AccessibilityIdentifiers.Combat.attackButton)

                // Завершить ход
                Button(action: endPlayerTurn) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text(L10n.combatEndTurnButton.localized)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.Combat.endTurnButton)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.Combat.actionBar)
        }
    }

    // MARK: - Enemy Turn View

    var enemyTurnView: some View {
        VStack(spacing: 12) {
            Text(L10n.combatEnemyTurn.localized)
                .font(.headline)
                .foregroundColor(.red)

            HStack {
                Image(systemName: "burst.fill")
                    .foregroundColor(.red)
                Text(L10n.combatLogEnemyAttacks.localized(with: monster.name))
            }

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .red))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            performEnemyAttack()
        }
    }

    // MARK: - End Turn View

    var endTurnView: some View {
        VStack(spacing: 12) {
            Text(L10n.combatEndTurn.localized)
                .font(.headline)
                .foregroundColor(.purple)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            performEndTurn()
        }
    }

    // MARK: - Combat Over View (Engine-First: reads from engine.combatState)

    var combatOverView: some View {
        VStack(spacing: 12) {
            if monsterHealth <= 0 {
                Text("🎉 " + L10n.combatVictory.localized)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            } else {
                Text("💀 " + L10n.combatDefeat.localized)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Combat Log

    var combatLogView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Детальный результат последней атаки
            if let result = lastCombatResult {
                combatResultDetailView(result)
            }

            // Журнал боя
            VStack(alignment: .leading, spacing: 4) {
                Text("📜 " + L10n.combatLogTitle.localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                ForEach(combatLog.suffix(5), id: \.self) { entry in
                    Text("• \(entry)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }

    /// Детальный вид результата атаки
    func combatResultDetailView(_ result: CombatResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Заголовок попадание/промах
            HStack {
                Text(result.isHit ? "✅ ПОПАДАНИЕ!" : "❌ ПРОМАХ!")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(result.isHit ? .green : .red)

                Spacer()

                // Общий результат
                Text("Атака \(result.attackRoll.total) vs Защита \(result.defenseValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Разбивка броска атаки
            VStack(alignment: .leading, spacing: 2) {
                Text("Бросок атаки:")
                    .font(.caption)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Text("💪 \(result.attackRoll.baseStrength)")
                        .font(.caption2)

                    Text("+")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Кубики
                    ForEach(result.attackRoll.diceRolls.indices, id: \.self) { index in
                        diceView(result.attackRoll.diceRolls[index])
                    }

                    if result.attackRoll.bonusDamage > 0 {
                        Text("+ \(result.attackRoll.bonusDamage)")
                            .font(.caption2)
                            .foregroundColor(.orange)
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
                        .foregroundColor(.blue)
                }
            }

            // Расчёт урона (если попадание)
            if result.isHit, let damage = result.damageCalculation {
                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Расчёт урона:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    HStack {
                        Text("Базовый: \(damage.base)")
                            .font(.caption2)

                        ForEach(damage.modifiers.indices, id: \.self) { index in
                            let mod = damage.modifiers[index]
                            Text("\(mod.value > 0 ? "+" : "")\(mod.value)")
                                .font(.caption2)
                                .foregroundColor(mod.value > 0 ? .green : .red)
                        }

                        Text("= \(damage.total) 💥")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }

                    // Детализация модификаторов урона
                    ForEach(damage.modifiers.indices, id: \.self) { index in
                        let modifier = damage.modifiers[index]
                        HStack(spacing: 4) {
                            Text(modifier.icon)
                            Text(modifier.description)
                            Text("\(modifier.value > 0 ? "+" : "")\(modifier.value)")
                                .foregroundColor(modifier.value > 0 ? .green : .red)
                        }
                        .font(.caption2)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(result.isHit ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(result.isHit ? Color.green : Color.red, lineWidth: 1)
                )
        )
    }

    /// Вид кубика
    func diceView(_ value: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .shadow(radius: 1)

            Text("\(value)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(value >= 5 ? .green : value <= 2 ? .red : .black)
        }
    }

    // MARK: - Player Hand (Engine-First with legacy fallback)

    /// Player's hand cards
    private var playerHand: [Card] {
        player?.hand ?? []
    }

    var playerHandView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("🃏 " + L10n.combatYourHand.localized + " (\(playerHand.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if phase == .playerTurn && actionsRemaining > 0 {
                    Text(L10n.combatTapToPlay.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
        .frame(height: 150)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Combat Logic (Engine-First: uses engine.performAction())

    func startCombat() {
        combatLog.append("Бой начался! Враг: \(monster.name)")
        combatLog.append("У вас 3 действия за ход")

        // Engine-First: Initialize combat through engine
        engine.performAction(.combatInitialize)

        // Legacy fallback for deck operations
        if let p = player {
            p.shuffleDeck()
            p.drawCards(count: p.maxHandSize)
        }

        actionsRemaining = 3
        phase = .playerTurn
    }

    func performBasicAttack() {
        guard actionsRemaining > 0 else { return }

        actionsRemaining -= 1

        let monsterDef = monster.defense ?? 10
        let monsterCurrentHP = monsterHealth
        let monsterMaxHP = monster.health ?? 10

        // Используем CombatCalculator для расчёта атаки
        guard let p = player else { return }
        let result = CombatCalculator.calculatePlayerAttack(
            player: p,
            monsterDefense: monsterDef,
            monsterCurrentHP: monsterCurrentHP,
            monsterMaxHP: monsterMaxHP,
            bonusDice: bonusDice,
            bonusDamage: bonusDamage,
            isFirstAttack: isFirstAttackThisCombat
        )

        // Сохраняем результат для отображения
        lastCombatResult = result

        if result.isHit, let damageCalc = result.damageCalculation {
            let damage = damageCalc.total

            // Engine-First: Apply damage through engine action
            engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: damage)))

            // Update legacy monster binding if available
            legacyMonster?.wrappedValue.health = monsterHealth

            combatLog.append("⚔️ ПОПАДАНИЕ! Урон: \(damage) (HP врага: \(monsterHealth))")

            if monsterHealth <= 0 {
                finishCombat(victory: true)
            }
        } else {
            combatLog.append("⚔️ ПРОМАХ! (\(result.attackRoll.total) vs \(monsterDef))")
        }

        // Сбросить бонусы после атаки
        bonusDice = 0
        bonusDamage = 0
        isFirstAttackThisCombat = false
    }

    func playCard(_ card: Card) {
        guard actionsRemaining > 0, phase == .playerTurn else { return }

        // Проверяем стоимость веры (Engine-First: check via engine)
        if let cost = card.cost, cost > 0 {
            guard engine.playerFaith >= cost else {
                combatLog.append("❌ Недостаточно веры для \(card.name)")
                return
            }
            // Engine-First: Spend faith through engine action
            engine.performAction(.combatApplyEffect(effect: .spendFaith(amount: cost)))
            combatLog.append("💫 Потрачено \(cost) веры")
        }

        actionsRemaining -= 1

        // Legacy: play card from hand
        player?.playCard(card)

        combatLog.append("🃏 Сыграна: \(card.name)")

        // Применяем эффекты карты (Engine-First)
        applyCardEffects(card)

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
                combatLog.append("   💚 Исцеление +\(amount) HP")

            case .damage(let amount, _):
                let actualDamage = player?.calculateDamageDealt(amount) ?? amount
                // Engine-First: Damage enemy through engine action
                engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: actualDamage)))
                legacyMonster?.wrappedValue.health = monsterHealth
                combatLog.append("   💥 Урон \(actualDamage) (HP врага: \(monsterHealth))")

            case .drawCards(let count):
                // Engine-First: Draw cards through engine action
                engine.performAction(.combatApplyEffect(effect: .drawCards(count: count)))
                player?.drawCards(count: count)  // Legacy sync
                combatLog.append("   🃏 Взято карт: \(count)")

            case .gainFaith(let amount):
                // Engine-First: Gain faith through engine action
                engine.performAction(.combatApplyEffect(effect: .gainFaith(amount: amount)))
                combatLog.append("   ✨ Вера +\(amount)")

            case .removeCurse(let type):
                // Engine-First: Remove curse through engine action (convert CurseType to String)
                engine.performAction(.combatApplyEffect(effect: .removeCurse(type: type?.rawValue)))
                combatLog.append("   🌟 Снято проклятие")

            case .addDice(let count):
                // Engine-First: Add bonus dice through engine action
                engine.performAction(.combatApplyEffect(effect: .addBonusDice(count: count)))
                bonusDice += count  // Local tracking for UI
                combatLog.append("   🎲 +\(count) кубик(ов) к следующей атаке")

            case .reroll:
                // Reroll даёт +1 кубик (выбирается лучший результат)
                engine.performAction(.combatApplyEffect(effect: .addBonusDice(count: 1)))
                bonusDice += 1
                combatLog.append("   🔄 Перебросок: +1 кубик (лучший результат)")

            case .shiftBalance(let towards, let amount):
                // Engine-First: Shift balance through engine action
                let directionString = towards == .light ? "light" : towards == .dark ? "dark" : "equilibrium"
                engine.performAction(.combatApplyEffect(effect: .shiftBalance(towards: directionString, amount: amount)))
                let directionText = towards == .light ? "Свету" : towards == .dark ? "Тьме" : "Равновесию"
                combatLog.append("   ⚖️ Баланс сдвинут к \(directionText) на \(amount)")

            case .applyCurse(let curseType, let duration):
                // В бою проклятие наносит урон монстру (тёмная магия)
                let curseDamage = duration * 2
                // Engine-First: Damage enemy through engine action
                engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: curseDamage)))
                legacyMonster?.wrappedValue.health = monsterHealth
                combatLog.append("   💀 Проклятие \(curseType): \(curseDamage) урона врагу")

            case .summonSpirit(let power, let realm):
                summonedSpirits.append((power: power, realm: realm))
                let realmName = realm == .yav ? "Явь" : realm == .nav ? "Навь" : "Правь"
                let realmString = realm == .yav ? "yav" : realm == .nav ? "nav" : "prav"
                combatLog.append("   👻 Призван дух из \(realmName) (сила: \(power))")
                // Engine-First: Spirit attacks enemy immediately through engine action
                engine.performAction(.combatApplyEffect(effect: .summonSpirit(power: power, realm: realmString)))
                legacyMonster?.wrappedValue.health = monsterHealth
                combatLog.append("   👻 Дух атакует! Урон: \(power)")

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
                    engine.performAction(.combatApplyEffect(effect: .drawCards(count: cost)))
                    player?.drawCards(count: cost)  // Legacy sync
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

            case .custom(let description):
                combatLog.append("   📜 \(description)")
            }
        }
    }

    func endPlayerTurn() {
        phase = .enemyTurn
    }

    func performEnemyAttack() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard monsterHealth > 0 else {
                phase = .endTurn
                return
            }

            let monsterPower = monster.power ?? 3
            let healthBefore = engine.playerHealth

            // Engine-First: Enemy attack through engine action
            engine.performAction(.combatEnemyAttack(damage: monsterPower))

            let damage = healthBefore - engine.playerHealth

            combatLog.append("👹 \(monster.name) атакует! Урон: \(damage)")

            if engine.playerHealth <= 0 {
                finishCombat(victory: false)
            } else {
                phase = .endTurn
            }
        }
    }

    func performEndTurn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Духи атакуют в конце хода (если ещё живы)
            if !summonedSpirits.isEmpty {
                for spirit in summonedSpirits {
                    let spiritDamage = spirit.power
                    // Engine-First: Spirit damage through engine action
                    engine.performAction(.combatApplyEffect(effect: .damageEnemy(amount: spiritDamage)))
                    legacyMonster?.wrappedValue.health = monsterHealth
                    let realmName = spirit.realm == .yav ? "Явь" : spirit.realm == .nav ? "Навь" : "Правь"
                    combatLog.append("👻 Дух \(realmName) атакует: \(spiritDamage) урона")
                }
                // Духи исчезают после атаки
                summonedSpirits.removeAll()
            }

            // Проверяем победу после атак духов (Engine-First: read from engine)
            if monsterHealth <= 0 {
                finishCombat(victory: true)
                return
            }

            // Сбрасываем бонусы на конец хода
            bonusDice = 0
            bonusDamage = 0
            canReroll = false

            // Engine-First: End turn phase through engine action (discard, draw, faith restore)
            engine.performAction(.combatEndTurnPhase)

            // Legacy sync: discard and draw
            if let p = player {
                while !p.hand.isEmpty {
                    p.playCard(p.hand[0])
                }
                p.drawCards(count: p.maxHandSize)
            }

            // Способность Мага: +1 вера в конце хода (Медитация)
            if player?.shouldGainFaithEndOfTurn == true {
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

        // Engine-First: Finish combat through engine action
        engine.performAction(.combatFinish(victory: victory))

        if victory {
            combatLog.append("🎉 Победа! \(monster.name) повержен!")
        } else {
            combatLog.append("💀 Поражение...")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onCombatEnd(victory ? .victory : .defeat)
        }
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
        VStack(spacing: 4) {
            // Название карты
            Text(card.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Стоимость веры (если есть)
            if let cost = card.cost, cost > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("\(cost)")
                        .font(.caption2)
                }
                .foregroundColor(.yellow)
            }

            // Тип карты
            Text(cardTypeText)
                .font(.system(size: 9))
                .foregroundColor(cardTypeColor)
                .fontWeight(.medium)

            // Основной эффект
            if let ability = card.abilities.first {
                Text(abilityText(ability))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 85, height: 110)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(canPlay ? cardBorder : Color.gray, lineWidth: canPlay ? 2 : 1)
                )
        )
        .opacity(canPlay ? 1.0 : 0.5)
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
        case .attack: return .red
        case .defense: return .blue
        case .spell: return .purple
        case .resource: return .yellow
        default: return .gray
        }
    }

    var cardBackground: Color {
        switch card.type {
        case .attack: return Color.red.opacity(0.15)
        case .defense: return Color.blue.opacity(0.15)
        case .spell: return Color.purple.opacity(0.15)
        case .resource: return Color.yellow.opacity(0.15)
        default: return Color.gray.opacity(0.15)
        }
    }

    var cardBorder: Color {
        switch card.type {
        case .attack: return .red
        case .defense: return .blue
        case .spell: return .purple
        case .resource: return .yellow
        default: return .gray
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
        case .custom: return ability.description
        }
    }
}
