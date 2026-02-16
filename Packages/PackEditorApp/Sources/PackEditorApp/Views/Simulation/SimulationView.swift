/// Файл: Packages/PackEditorApp/Sources/PackEditorApp/Views/Simulation/SimulationView.swift
/// Назначение: Содержит реализацию файла SimulationView.swift.
/// Зона ответственности: Изолирован своей предметной ответственностью в рамках модуля.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import SwiftUI
import Charts
import TwilightEngine
import PackEditorKit

struct SimulationView: View {
    @EnvironmentObject var tab: EditorTab

    @State private var selectedHeroId: String?
    @State private var selectedEnemyIds: Set<String> = []
    @State private var simulationCount: Int = 100
    @State private var startingResonance: Float = 0
    @State private var isRunning = false
    @State private var progress: Int = 0
    @State private var result: SimulationResult?

    private var heroOptions: [(id: String, label: String)] {
        tab.heroes.values
            .sorted { $0.id < $1.id }
            .map { (id: $0.id, label: $0.name.resolved(for: "en")) }
    }

    private var enemyOptions: [(id: String, label: String)] {
        tab.enemies.values
            .sorted { $0.id < $1.id }
            .map { (id: $0.id, label: $0.name.resolved(for: "en")) }
    }

    var body: some View {
        Form {
            configSection
            if isRunning { progressSection }
            if let result { resultsSection(result) }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Configuration

    @ViewBuilder
    private var configSection: some View {
        Section("Configuration") {
            Picker("Hero", selection: $selectedHeroId) {
                Text("Select a hero...").tag(String?.none)
                ForEach(heroOptions, id: \.id) { option in
                    Text(option.label).tag(String?.some(option.id))
                }
            }

            VStack(alignment: .leading) {
                Text("Enemies")
                    .font(.headline)
                ForEach(enemyOptions, id: \.id) { option in
                    Toggle(option.label, isOn: Binding(
                        get: { selectedEnemyIds.contains(option.id) },
                        set: { isOn in
                            if isOn { selectedEnemyIds.insert(option.id) }
                            else { selectedEnemyIds.remove(option.id) }
                        }
                    ))
                }
            }

            Picker("Simulations", selection: $simulationCount) {
                Text("100").tag(100)
                Text("500").tag(500)
                Text("1000").tag(1000)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading) {
                Text("Starting Resonance: \(Int(startingResonance))")
                Slider(value: $startingResonance, in: -100...100, step: 1)
            }

            Button(action: runSimulation) {
                Label("Run Simulation", systemImage: "play.fill")
            }
            .disabled(!canRun)
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
        Section {
            ProgressView(value: Double(progress), total: Double(simulationCount))
            Text("\(progress) / \(simulationCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsSection(_ result: SimulationResult) -> some View {
        Section("Results") {
            LabeledContent("Win Rate") {
                Text(String(format: "%.1f%%", result.winRate * 100))
                    .foregroundStyle(balanceColor(for: result.winRate))
                    .fontWeight(.bold)
            }
            LabeledContent("Wins / Losses") {
                Text("\(result.wins) / \(result.losses)")
            }
            LabeledContent("Avg Rounds") {
                Text(String(format: "%.1f", result.avgRounds))
            }
            LabeledContent("Avg HP Remaining (wins)") {
                Text(String(format: "%.1f", result.avgHPRemaining))
            }
            LabeledContent("Avg Resonance Delta") {
                Text(String(format: "%+.2f", result.avgResonanceDelta))
            }
            LabeledContent("Longest Fight") {
                Text("\(result.longestFight) rounds")
            }

            balanceIndicator(result.winRate)
        }

        Section("Round Distribution") {
            Chart {
                ForEach(Array(result.roundDistribution.keys.sorted()), id: \.self) { round in
                    BarMark(
                        x: .value("Round", round),
                        y: .value("Count", result.roundDistribution[round] ?? 0)
                    )
                    .foregroundStyle(.blue.gradient)
                }
            }
            .chartXAxisLabel("Round")
            .chartYAxisLabel("Fights Ended")
            .frame(height: 200)
        }
    }

    // MARK: - Balance Indicator

    private func balanceIndicator(_ winRate: Double) -> some View {
        let (label, color) = balanceAssessment(winRate)
        return HStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(color)
                .font(.caption)
            Text("Balance: \(label)")
                .font(.callout)
        }
    }

    private func balanceColor(for winRate: Double) -> Color {
        balanceAssessment(winRate).color
    }

    private func balanceAssessment(_ winRate: Double) -> (label: String, color: Color) {
        if winRate < 0.3 {
            return ("Too Hard", .red)
        } else if winRate < 0.5 {
            return ("Slightly Hard", .yellow)
        } else if winRate <= 0.8 {
            return ("Balanced", .green)
        } else {
            return ("Too Easy", .yellow)
        }
    }

    // MARK: - Actions

    private var canRun: Bool {
        !isRunning && selectedHeroId != nil && !selectedEnemyIds.isEmpty
    }

    private func runSimulation() {
        guard let heroId = selectedHeroId,
              let heroDef = tab.heroes[heroId] else { return }

        let enemyDefs = selectedEnemyIds.compactMap { tab.enemies[$0] }
        guard !enemyDefs.isEmpty else { return }

        let config = SimulationConfig(
            heroDefinition: heroDef,
            enemyDefinitions: enemyDefs,
            simulationCount: simulationCount,
            startingResonance: startingResonance
        )

        isRunning = true
        progress = 0
        result = nil

        Task { @MainActor in
            let simResult = await CombatSimulator.run(config: config) { @MainActor done in
                progress = done
            }
            isRunning = false
            result = simResult
        }
    }
}
