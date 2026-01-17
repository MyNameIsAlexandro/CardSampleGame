import SwiftUI

/// Боевой экран - чистая реализация по документации
/// Цикл: PlayerTurn → EnemyTurn → EndTurn (повтор до победы/поражения)
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
    @State private var selectedCard: Card?
    @State private var combatLog: [String] = []
    @State private var showingAttackResult = false
    @State private var lastAttackResult: AttackResult?
    @State private var isAnimating = false

    struct AttackResult {
        let diceRoll: Int
        let playerPower: Int
        let total: Int
        let monsterDefense: Int
        let success: Bool
        let damage: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель с информацией о ходе
            combatHeader

            // Основная область боя
            ScrollView {
                VStack(spacing: 16) {
                    // Монстр
                    monsterCard

                    // Разделитель с VS
                    HStack {
                        Rectangle().fill(Color.red.opacity(0.5)).frame(height: 2)
                        Text("VS")
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                        Rectangle().fill(Color.red.opacity(0.5)).frame(height: 2)
                    }
                    .padding(.horizontal)

                    // Игрок
                    playerStats

                    // Кнопки действий
                    if phase == .playerTurn {
                        actionButtons
                    } else if phase == .enemyTurn {
                        enemyTurnView
                    } else if phase == .endTurn {
                        endTurnView
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
        .alert("Результат атаки", isPresented: $showingAttackResult) {
            Button("OK") {
                checkCombatEnd()
            }
        } message: {
            if let result = lastAttackResult {
                Text(attackResultMessage(result))
            }
        }
        .onAppear {
            startCombat()
        }
    }

    // MARK: - Header

    var combatHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Ход \(turnNumber)")
                    .font(.headline)
                Text(phaseText)
                    .font(.subheadline)
                    .foregroundColor(phaseColor)
            }

            Spacer()

            // Действия
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < actionsRemaining ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
                Text("Действия")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Кнопка побега
            Button(action: flee) {
                Image(systemName: "figure.run")
                    .foregroundColor(.gray)
            }
            .disabled(phase != .playerTurn)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Monster Card

    var monsterCard: some View {
        VStack(spacing: 8) {
            // Имя монстра
            Text(monster.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)

            // Статы монстра
            HStack(spacing: 24) {
                // Здоровье
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("\(monster.health ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("HP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Сила атаки
                VStack {
                    Image(systemName: "burst.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("\(monster.power ?? 3)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Атака")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Защита
                VStack {
                    Image(systemName: "shield.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    Text("\(monster.defense ?? 10)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Защита")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Описание
            if !monster.description.isEmpty {
                Text(monster.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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

    // MARK: - Player Stats

    var playerStats: some View {
        HStack(spacing: 24) {
            // Здоровье
            VStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(player.health)/\(player.maxHealth)")
                    .fontWeight(.bold)
                Text("HP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Сила
            VStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                Text("\(player.strength)")
                    .fontWeight(.bold)
                Text("Сила")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Вера
            VStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("\(player.faith)")
                    .fontWeight(.bold)
                Text("Вера")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Выносливость (защита)
            VStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.blue)
                Text("\(player.constitution)")
                    .fontWeight(.bold)
                Text("Защита")
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

    // MARK: - Action Buttons

    var actionButtons: some View {
        VStack(spacing: 12) {
            // Атака
            Button(action: performAttack) {
                HStack {
                    Image(systemName: "dice.fill")
                    Text("Атаковать")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(actionsRemaining > 0 ? Color.orange : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(actionsRemaining <= 0 || isAnimating)
            .accessibilityIdentifier(AccessibilityIdentifiers.Combat.attackButton)

            // Завершить ход
            Button(action: endPlayerTurn) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Завершить ход")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isAnimating)
            .accessibilityIdentifier(AccessibilityIdentifiers.Combat.endTurnButton)
        }
        .padding(.horizontal)
        .accessibilityIdentifier(AccessibilityIdentifiers.Combat.actionBar)
    }

    // MARK: - Enemy Turn View

    var enemyTurnView: some View {
        VStack(spacing: 12) {
            Text("Ход врага...")
                .font(.headline)
                .foregroundColor(.red)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .red))
        }
        .padding()
        .onAppear {
            performEnemyAttack()
        }
    }

    // MARK: - End Turn View

    var endTurnView: some View {
        VStack(spacing: 12) {
            Text("Конец хода")
                .font(.headline)
                .foregroundColor(.purple)

            Text("Сброс руки, взятие 5 карт, +1 вера")
                .font(.caption)
                .foregroundColor(.secondary)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
        }
        .padding()
        .onAppear {
            performEndTurn()
        }
    }

    // MARK: - Combat Log

    var combatLogView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Журнал боя")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)

            ForEach(combatLog.suffix(5), id: \.self) { entry in
                Text(entry)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - Player Hand

    var playerHandView: some View {
        VStack(spacing: 4) {
            Text("Рука (\(player.hand.count))")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(player.hand) { card in
                        CombatCardView(
                            card: card,
                            isSelected: selectedCard?.id == card.id,
                            canPlay: actionsRemaining > 0 && phase == .playerTurn
                        ) {
                            playCard(card)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(height: 140)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Combat Logic

    func startCombat() {
        combatLog.append("Бой начался! Враг: \(monster.name)")
        player.shuffleDeck()
        player.drawCards(count: player.maxHandSize)
        actionsRemaining = 3
        phase = .playerTurn
    }

    func performAttack() {
        guard actionsRemaining > 0 else { return }

        actionsRemaining -= 1
        isAnimating = true

        // Бросок кубика
        let diceRoll = Int.random(in: 1...6)
        let playerPower = player.strength
        let total = diceRoll + playerPower
        let monsterDefense = monster.defense ?? 10

        let success = total >= monsterDefense
        var damage = 0

        if success {
            damage = max(1, total - monsterDefense + 3)
            // Применяем модификаторы проклятий
            damage = player.calculateDamageDealt(damage)

            let newHealth = max(0, (monster.health ?? 0) - damage)
            monster.health = newHealth

            combatLog.append("Атака! Кубик: \(diceRoll) + Сила: \(playerPower) = \(total) vs \(monsterDefense). Урон: \(damage)")
        } else {
            combatLog.append("Атака! Кубик: \(diceRoll) + Сила: \(playerPower) = \(total) vs \(monsterDefense). Промах!")
        }

        lastAttackResult = AttackResult(
            diceRoll: diceRoll,
            playerPower: playerPower,
            total: total,
            monsterDefense: monsterDefense,
            success: success,
            damage: damage
        )

        isAnimating = false
        showingAttackResult = true
    }

    func playCard(_ card: Card) {
        guard actionsRemaining > 0, phase == .playerTurn else { return }

        // Проверяем стоимость веры
        if let cost = card.cost, cost > 0 {
            guard player.spendFaith(cost) else {
                combatLog.append("Недостаточно веры для \(card.name)")
                return
            }
        }

        actionsRemaining -= 1
        player.playCard(card)

        // Применяем эффекты карты
        applyCardEffects(card)

        combatLog.append("Сыграна карта: \(card.name)")
        checkCombatEnd()
    }

    func applyCardEffects(_ card: Card) {
        for ability in card.abilities {
            switch ability.effect {
            case .heal(let amount):
                player.heal(amount)
                combatLog.append("  → Исцеление: +\(amount) HP")

            case .damage(let amount, _):
                let actualDamage = player.calculateDamageDealt(amount)
                let newHealth = max(0, (monster.health ?? 0) - actualDamage)
                monster.health = newHealth
                combatLog.append("  → Урон: \(actualDamage)")

            case .drawCards(let count):
                player.drawCards(count: count)
                combatLog.append("  → Взято карт: \(count)")

            case .gainFaith(let amount):
                player.gainFaith(amount)
                combatLog.append("  → Вера: +\(amount)")

            case .removeCurse(let type):
                player.removeCurse(type: type)
                combatLog.append("  → Снято проклятие")

            default:
                break
            }
        }
    }

    func endPlayerTurn() {
        phase = .enemyTurn
    }

    func performEnemyAttack() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard (monster.health ?? 0) > 0 else {
                // Монстр мёртв, пропускаем атаку
                phase = .endTurn
                return
            }

            let monsterPower = monster.power ?? 3
            let healthBefore = player.health
            player.takeDamageWithCurses(monsterPower)
            let damage = healthBefore - player.health

            combatLog.append("Враг атакует! Урон: \(damage). Ваше HP: \(player.health)")

            if player.health <= 0 {
                phase = .combatOver
                onCombatEnd(.defeat)
            } else {
                phase = .endTurn
            }
        }
    }

    func performEndTurn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Сбрасываем руку
            while !player.hand.isEmpty {
                player.playCard(player.hand[0])
            }

            // Берём новые карты
            player.drawCards(count: player.maxHandSize)

            // Восстанавливаем веру
            player.gainFaith(1)

            // Новый ход
            turnNumber += 1
            actionsRemaining = 3

            combatLog.append("--- Ход \(turnNumber) ---")

            phase = .playerTurn
        }
    }

    func checkCombatEnd() {
        if (monster.health ?? 0) <= 0 {
            combatLog.append("Победа! \(monster.name) побеждён!")
            phase = .combatOver

            // Небольшая задержка перед закрытием
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onCombatEnd(.victory)
            }
        } else if player.health <= 0 {
            combatLog.append("Поражение...")
            phase = .combatOver
            onCombatEnd(.defeat)
        }
    }

    func flee() {
        combatLog.append("Вы сбежали из боя!")
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

    func attackResultMessage(_ result: AttackResult) -> String {
        if result.success {
            return """
            Бросок: \(result.diceRoll)
            + Сила: \(result.playerPower)
            = \(result.total)

            Защита врага: \(result.monsterDefense)

            Успех! Урон: \(result.damage)
            Осталось HP: \(monster.health ?? 0)
            """
        } else {
            return """
            Бросок: \(result.diceRoll)
            + Сила: \(result.playerPower)
            = \(result.total)

            Защита врага: \(result.monsterDefense)

            Промах!
            """
        }
    }
}

// MARK: - Combat Card View

struct CombatCardView: View {
    let card: Card
    let isSelected: Bool
    let canPlay: Bool
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(card.name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let cost = card.cost, cost > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("\(cost)")
                        .font(.caption2)
                }
                .foregroundColor(.yellow)
            }

            // Показываем основной эффект
            if let ability = card.abilities.first {
                Text(abilityText(ability))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(width: 80, height: 100)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : cardBorder, lineWidth: isSelected ? 3 : 1)
                )
        )
        .opacity(canPlay ? 1.0 : 0.6)
        .onTapGesture {
            if canPlay {
                onPlay()
            }
        }
    }

    var cardBackground: Color {
        switch card.type {
        case .attack: return Color.red.opacity(0.1)
        case .defense: return Color.blue.opacity(0.1)
        case .spell: return Color.purple.opacity(0.1)
        case .resource: return Color.yellow.opacity(0.1)
        default: return Color.gray.opacity(0.1)
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
        case .heal(let amount): return "Лечение: \(amount)"
        case .drawCards(let count): return "Карты: +\(count)"
        case .gainFaith(let amount): return "Вера: +\(amount)"
        default: return ability.description
        }
    }
}
