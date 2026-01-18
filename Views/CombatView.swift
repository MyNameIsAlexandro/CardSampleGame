import SwiftUI

/// Боевой экран - реализация по документации GAME_DESIGN_DOCUMENT.md
/// Цикл: PlayerTurn → EnemyTurn → EndTurn (повтор до победы/поражения)
/// Действия: 3 за ход. Играть карту = 1 действие, Атаковать = 1 действие
struct CombatView: View {
    @ObservedObject var player: Player
    @Binding var monster: Card
    let onCombatEnd: (CombatOutcome) -> Void

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
        .alert("Бой", isPresented: $showingMessage) {
            Button("OK") { }
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
                Text("Ход \(turnNumber)")
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
                    Text("Бежать")
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
                // HP монстра
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("\(monster.health ?? 0)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("HP")
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
                    Text("Атака")
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
                    Text("Защита")
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

    // MARK: - Player Stats

    var playerStats: some View {
        HStack(spacing: 24) {
            VStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(player.health)/\(player.maxHealth)")
                    .fontWeight(.bold)
                Text("HP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                Text("\(player.strength)")
                    .fontWeight(.bold)
                Text("Сила")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("\(player.faith)")
                    .fontWeight(.bold)
                Text("Вера")
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
                Text("ВАШ ХОД")
                    .font(.headline)
                    .foregroundColor(.green)

                if actionsRemaining > 0 {
                    Text("Осталось действий: \(actionsRemaining)")
                        .font(.subheadline)
                    Text("Нажмите на карту чтобы сыграть её, или атакуйте")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Действия закончились!")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    Text("Нажмите «Завершить ход»")
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
                        Text("Атака")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("(-1 действие)")
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
                        Text("Завершить")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("ход")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
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
            Text("ХОД ВРАГА")
                .font(.headline)
                .foregroundColor(.red)

            HStack {
                Image(systemName: "burst.fill")
                    .foregroundColor(.red)
                Text("\(monster.name) атакует!")
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
            Text("КОНЕЦ ХОДА")
                .font(.headline)
                .foregroundColor(.purple)

            Text("Сброс руки → Взятие 5 карт → +1 Вера")
                .font(.caption)
                .foregroundColor(.secondary)

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

    // MARK: - Combat Over View

    var combatOverView: some View {
        VStack(spacing: 12) {
            if (monster.health ?? 0) <= 0 {
                Text("🎉 ПОБЕДА!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("\(monster.name) повержен!")
                    .foregroundColor(.secondary)
            } else {
                Text("💀 ПОРАЖЕНИЕ")
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
                Text("📜 Журнал боя")
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

    // MARK: - Player Hand

    var playerHandView: some View {
        VStack(spacing: 4) {
            HStack {
                Text("🃏 Ваша рука (\(player.hand.count) карт)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if phase == .playerTurn && actionsRemaining > 0 {
                    Text("Нажмите на карту = сыграть (-1 действие)")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(player.hand) { card in
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

    // MARK: - Combat Logic

    func startCombat() {
        combatLog.append("Бой начался! Враг: \(monster.name)")
        combatLog.append("У вас 3 действия за ход")
        player.shuffleDeck()
        player.drawCards(count: player.maxHandSize)
        actionsRemaining = 3
        phase = .playerTurn
    }

    func performBasicAttack() {
        guard actionsRemaining > 0 else { return }

        actionsRemaining -= 1

        let monsterDef = monster.defense ?? 10
        let monsterCurrentHP = monster.health ?? 10
        let monsterMaxHP = monsterCurrentHP  // Начальное HP

        // Используем CombatCalculator для расчёта атаки
        let result = CombatCalculator.calculatePlayerAttack(
            player: player,
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
            let newHealth = max(0, monsterCurrentHP - damage)
            monster.health = newHealth

            combatLog.append("⚔️ ПОПАДАНИЕ! Урон: \(damage) (HP врага: \(newHealth))")

            if newHealth <= 0 {
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

        // Проверяем стоимость веры
        if let cost = card.cost, cost > 0 {
            guard player.spendFaith(cost) else {
                combatLog.append("❌ Недостаточно веры для \(card.name)")
                return
            }
            combatLog.append("💫 Потрачено \(cost) веры")
        }

        actionsRemaining -= 1
        player.playCard(card)

        combatLog.append("🃏 Сыграна: \(card.name)")

        // Применяем эффекты карты
        applyCardEffects(card)

        // Проверяем победу
        if (monster.health ?? 0) <= 0 {
            finishCombat(victory: true)
        }
    }

    func applyCardEffects(_ card: Card) {
        for ability in card.abilities {
            switch ability.effect {
            case .heal(let amount):
                player.heal(amount)
                combatLog.append("   💚 Исцеление +\(amount) HP")

            case .damage(let amount, _):
                let actualDamage = player.calculateDamageDealt(amount)
                let newHealth = max(0, (monster.health ?? 0) - actualDamage)
                monster.health = newHealth
                combatLog.append("   💥 Урон \(actualDamage) (HP врага: \(newHealth))")

            case .drawCards(let count):
                player.drawCards(count: count)
                combatLog.append("   🃏 Взято карт: \(count)")

            case .gainFaith(let amount):
                player.gainFaith(amount)
                combatLog.append("   ✨ Вера +\(amount)")

            case .removeCurse(let type):
                player.removeCurse(type: type)
                combatLog.append("   🌟 Снято проклятие")

            case .addDice(let count):
                bonusDice += count
                combatLog.append("   🎲 +\(count) кубик(ов) к следующей атаке")

            case .reroll:
                // Reroll даёт +1 кубик (выбирается лучший результат)
                bonusDice += 1
                combatLog.append("   🔄 Перебросок: +1 кубик (лучший результат)")

            case .shiftBalance(let towards, let amount):
                player.shiftBalance(towards: towards, amount: amount)
                let directionText = towards == .light ? "Свету" : towards == .dark ? "Тьме" : "Равновесию"
                combatLog.append("   ⚖️ Баланс сдвинут к \(directionText) на \(amount)")

            case .applyCurse(let curseType, let duration):
                // В бою проклятие наносит урон монстру (тёмная магия)
                let curseDamage = duration * 2
                let newHealth = max(0, (monster.health ?? 0) - curseDamage)
                monster.health = newHealth
                combatLog.append("   💀 Проклятие \(curseType): \(curseDamage) урона врагу")

            case .summonSpirit(let power, let realm):
                summonedSpirits.append((power: power, realm: realm))
                let realmName = realm == .yav ? "Явь" : realm == .nav ? "Навь" : "Правь"
                combatLog.append("   👻 Призван дух из \(realmName) (сила: \(power))")
                // Дух сразу атакует
                let spiritDamage = power
                let newHealth = max(0, (monster.health ?? 0) - spiritDamage)
                monster.health = newHealth
                combatLog.append("   👻 Дух атакует! Урон: \(spiritDamage)")

            case .sacrifice(let cost, let benefit):
                // Игрок теряет HP, получает бонус
                player.takeDamage(cost)
                combatLog.append("   🩸 Жертва: -\(cost) HP")
                // Парсим benefit для эффекта
                if benefit.lowercased().contains("урон") || benefit.lowercased().contains("damage") {
                    bonusDamage += cost * 2
                    combatLog.append("   🔥 +\(cost * 2) к урону следующей атаки")
                } else if benefit.lowercased().contains("карт") || benefit.lowercased().contains("draw") {
                    player.drawCards(count: cost)
                    combatLog.append("   🃏 Взято карт: \(cost)")
                } else {
                    // Общий бонус - добавить урон
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
            guard (monster.health ?? 0) > 0 else {
                phase = .endTurn
                return
            }

            let monsterPower = monster.power ?? 3
            let healthBefore = player.health
            player.takeDamageWithCurses(monsterPower)
            let damage = healthBefore - player.health

            combatLog.append("👹 \(monster.name) атакует! Урон: \(damage)")

            if player.health <= 0 {
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
                    let newHealth = max(0, (monster.health ?? 0) - spiritDamage)
                    monster.health = newHealth
                    let realmName = spirit.realm == .yav ? "Явь" : spirit.realm == .nav ? "Навь" : "Правь"
                    combatLog.append("👻 Дух \(realmName) атакует: \(spiritDamage) урона")
                }
                // Духи исчезают после атаки
                summonedSpirits.removeAll()
            }

            // Проверяем победу после атак духов
            if (monster.health ?? 0) <= 0 {
                finishCombat(victory: true)
                return
            }

            // Сбрасываем бонусы на конец хода
            bonusDice = 0
            bonusDamage = 0
            canReroll = false

            // Сбрасываем руку
            while !player.hand.isEmpty {
                player.playCard(player.hand[0])
            }

            // Берём новые карты
            player.drawCards(count: player.maxHandSize)

            // Восстанавливаем веру
            player.gainFaith(1)

            // Способность Мага: +1 вера в конце хода (Медитация)
            if player.shouldGainFaithEndOfTurn {
                player.gainFaith(1)
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
        combatLog.append("🏃 Вы сбежали из боя!")
        onCombatEnd(.fled)
    }

    // MARK: - Helpers

    var phaseText: String {
        switch phase {
        case .playerTurn: return "Ваш ход"
        case .enemyTurn: return "Ход врага"
        case .endTurn: return "Конец хода"
        case .combatOver: return "Бой окончен"
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
