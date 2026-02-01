import SwiftUI
import TwilightEngine

/// Structured editor for CardAbility.effect (AbilityEffect enum).
struct AbilityEffectEditor: View {
    @Binding var effect: AbilityEffect

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Effect Type", selection: effectTypeBinding) {
                ForEach(EffectType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            switch effect {
            case .damage(let amount, let type):
                damageEditor(amount: amount, type: type)
            case .heal(let amount):
                intEditor(label: "Amount", value: amount) { effect = .heal(amount: $0) }
            case .drawCards(let count):
                intEditor(label: "Count", value: count) { effect = .drawCards(count: $0) }
            case .addDice(let count):
                intEditor(label: "Count", value: count) { effect = .addDice(count: $0) }
            case .gainFaith(let amount):
                intEditor(label: "Amount", value: amount) { effect = .gainFaith(amount: $0) }
            case .applyCurse(let type, let duration):
                curseEditor(type: type, duration: duration)
            case .removeCurse(let type):
                removeCurseEditor(type: type)
            case .summonSpirit(let power, let realm):
                spiritEditor(power: power, realm: realm)
            case .shiftBalance(let towards, let amount):
                balanceEditor(towards: towards, amount: amount)
            case .travelRealm(let to):
                realmPicker(realm: to)
            case .permanentStat(let stat, let amount):
                statEditor(stat: stat, amount: amount) { s, a in effect = .permanentStat(stat: s, amount: a) }
            case .temporaryStat(let stat, let amount, let duration):
                tempStatEditor(stat: stat, amount: amount, duration: duration)
            case .sacrifice(let cost, let benefit):
                sacrificeEditor(cost: cost, benefit: benefit)
            case .custom(let text):
                customEditor(text: text)
            case .reroll, .explore:
                EmptyView()
            }
        }
    }

    // MARK: - Sub-editors

    @ViewBuilder
    private func damageEditor(amount: Int, type: DamageType) -> some View {
        HStack {
            Text("Amount")
                .font(.caption)
            TextField("Amount", value: Binding(
                get: { amount },
                set: { effect = .damage(amount: $0, type: type) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
        }
        Picker("Damage Type", selection: Binding(
            get: { type },
            set: { effect = .damage(amount: amount, type: $0) }
        )) {
            ForEach(DamageType.allCases, id: \.self) { dt in
                Text(dt.rawValue).tag(dt)
            }
        }
    }

    @ViewBuilder
    private func intEditor(label: String, value: Int, onChange: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(label)
                .font(.caption)
            TextField(label, value: Binding(
                get: { value },
                set: { onChange($0) }
            ), format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 60)
        }
    }

    @ViewBuilder
    private func curseEditor(type: CurseType, duration: Int) -> some View {
        Picker("Curse", selection: Binding(
            get: { type.rawValue },
            set: { if let ct = CurseType(rawValue: $0) { effect = .applyCurse(type: ct, duration: duration) } }
        )) {
            ForEach(Self.curseTypes, id: \.self) { Text($0).tag($0) }
        }
        intEditor(label: "Duration", value: duration) { effect = .applyCurse(type: type, duration: $0) }
    }

    @ViewBuilder
    private func removeCurseEditor(type: CurseType?) -> some View {
        Picker("Curse", selection: Binding(
            get: { type?.rawValue ?? "" },
            set: { effect = .removeCurse(type: $0.isEmpty ? nil : CurseType(rawValue: $0)) }
        )) {
            Text("Any").tag("")
            ForEach(Self.curseTypes, id: \.self) { Text($0).tag($0) }
        }
    }

    @ViewBuilder
    private func spiritEditor(power: Int, realm: Realm) -> some View {
        intEditor(label: "Power", value: power) { effect = .summonSpirit(power: $0, realm: realm) }
        Picker("Realm", selection: Binding(
            get: { realm },
            set: { effect = .summonSpirit(power: power, realm: $0) }
        )) {
            ForEach(Realm.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
    }

    @ViewBuilder
    private func balanceEditor(towards: CardBalance, amount: Int) -> some View {
        Picker("Towards", selection: Binding(
            get: { towards },
            set: { effect = .shiftBalance(towards: $0, amount: amount) }
        )) {
            ForEach(CardBalance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        intEditor(label: "Amount", value: amount) { effect = .shiftBalance(towards: towards, amount: $0) }
    }

    @ViewBuilder
    private func realmPicker(realm: Realm) -> some View {
        Picker("Realm", selection: Binding(
            get: { realm },
            set: { effect = .travelRealm(to: $0) }
        )) {
            ForEach(Realm.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
    }

    @ViewBuilder
    private func statEditor(stat: String, amount: Int, onChange: @escaping (String, Int) -> Void) -> some View {
        HStack {
            Text("Stat")
                .font(.caption)
            TextField("Stat", text: Binding(
                get: { stat },
                set: { onChange($0, amount) }
            ))
            .textFieldStyle(.roundedBorder)
        }
        intEditor(label: "Amount", value: amount) { onChange(stat, $0) }
    }

    @ViewBuilder
    private func tempStatEditor(stat: String, amount: Int, duration: Int) -> some View {
        statEditor(stat: stat, amount: amount) { s, a in effect = .temporaryStat(stat: s, amount: a, duration: duration) }
        intEditor(label: "Duration", value: duration) { effect = .temporaryStat(stat: stat, amount: amount, duration: $0) }
    }

    @ViewBuilder
    private func sacrificeEditor(cost: Int, benefit: String) -> some View {
        intEditor(label: "Cost", value: cost) { effect = .sacrifice(cost: $0, benefit: benefit) }
        HStack {
            Text("Benefit")
                .font(.caption)
            TextField("Benefit", text: Binding(
                get: { benefit },
                set: { effect = .sacrifice(cost: cost, benefit: $0) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func customEditor(text: String) -> some View {
        TextField("Custom Effect", text: Binding(
            get: { text },
            set: { effect = .custom($0) }
        ))
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Effect type mapping

    private enum EffectType: String, CaseIterable {
        case damage, heal, drawCards, addDice, reroll, explore, custom
        case applyCurse, removeCurse, summonSpirit, shiftBalance
        case travelRealm, gainFaith, sacrifice, permanentStat, temporaryStat
    }

    private var effectTypeBinding: Binding<EffectType> {
        Binding(
            get: {
                switch effect {
                case .damage: return .damage
                case .heal: return .heal
                case .drawCards: return .drawCards
                case .addDice: return .addDice
                case .reroll: return .reroll
                case .explore: return .explore
                case .custom: return .custom
                case .applyCurse: return .applyCurse
                case .removeCurse: return .removeCurse
                case .summonSpirit: return .summonSpirit
                case .shiftBalance: return .shiftBalance
                case .travelRealm: return .travelRealm
                case .gainFaith: return .gainFaith
                case .sacrifice: return .sacrifice
                case .permanentStat: return .permanentStat
                case .temporaryStat: return .temporaryStat
                }
            },
            set: { newType in
                switch newType {
                case .damage: effect = .damage(amount: 1, type: .physical)
                case .heal: effect = .heal(amount: 1)
                case .drawCards: effect = .drawCards(count: 1)
                case .addDice: effect = .addDice(count: 1)
                case .reroll: effect = .reroll
                case .explore: effect = .explore
                case .custom: effect = .custom("")
                case .applyCurse: effect = .applyCurse(type: .weakness, duration: 1)
                case .removeCurse: effect = .removeCurse(type: nil)
                case .summonSpirit: effect = .summonSpirit(power: 1, realm: .yav)
                case .shiftBalance: effect = .shiftBalance(towards: .light, amount: 1)
                case .travelRealm: effect = .travelRealm(to: .yav)
                case .gainFaith: effect = .gainFaith(amount: 1)
                case .sacrifice: effect = .sacrifice(cost: 1, benefit: "")
                case .permanentStat: effect = .permanentStat(stat: "power", amount: 1)
                case .temporaryStat: effect = .temporaryStat(stat: "power", amount: 1, duration: 1)
                }
            }
        )
    }

    private static let curseTypes = [
        "weakness", "fear", "exhaustion", "greed", "shadowOfNav", "bloodCurse", "sealOfNav"
    ]
}
