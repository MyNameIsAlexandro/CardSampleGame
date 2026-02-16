/// Файл: Views/Combat/CombatLogOverlay.swift
/// Назначение: Оверлей боевого журнала — полупрозрачная панель с прокруткой последних событий.
/// Зона ответственности: Presentation-only — отображение лога, toggle visibility.
/// Контекст: Phase 3 Ritual Combat (R9). Epic 7 — Combat Log.

import SpriteKit

// MARK: - Log Entry Type

/// Visual style for a combat log entry.
enum CombatLogEntryType {
    case action    // player actions (select, burn, commit)
    case damage    // damage dealt or taken
    case system    // phase transitions, round changes

    var color: SKColor {
        switch self {
        case .action: return SKColor(red: 0.70, green: 0.65, blue: 0.55, alpha: 1)
        case .damage: return SKColor(red: 0.90, green: 0.45, blue: 0.35, alpha: 1)
        case .system: return SKColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1)
        }
    }
}

// MARK: - Combat Log Overlay

/// Semi-transparent scrollable combat log panel.
/// Shows last `maxEntries` events with color-coded types.
final class CombatLogOverlay: SKNode {

    // MARK: - Constants

    static let panelSize = CGSize(width: 320, height: 280)
    private let maxEntries = 20
    private let lineHeight: CGFloat = 16
    private let fontSize: CGFloat = 10

    // MARK: - Child Nodes

    private let panelBg: SKShapeNode
    private let cropNode: SKCropNode
    private let contentNode: SKNode
    private let titleLabel: SKLabelNode

    // MARK: - State

    private var entries: [(text: String, type: CombatLogEntryType)] = []
    private var entryLabels: [SKLabelNode] = []

    // MARK: - Init

    override init() {
        let size = CombatLogOverlay.panelSize
        panelBg = SKShapeNode(rectOf: size, cornerRadius: 12)
        panelBg.fillColor = SKColor(red: 0.06, green: 0.05, blue: 0.08, alpha: 0.88)
        panelBg.strokeColor = SKColor(red: 0.35, green: 0.30, blue: 0.40, alpha: 1)
        panelBg.lineWidth = 1

        cropNode = SKCropNode()
        let mask = SKShapeNode(rectOf: CGSize(width: size.width - 16, height: size.height - 40))
        mask.fillColor = .white
        cropNode.maskNode = mask
        cropNode.position = CGPoint(x: 0, y: -10)

        contentNode = SKNode()

        titleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        titleLabel.text = "Боевой журнал"
        titleLabel.fontSize = 12
        titleLabel.fontColor = SKColor(white: 0.7, alpha: 1)
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: size.height / 2 - 16)

        super.init()

        addChild(panelBg)
        cropNode.addChild(contentNode)
        addChild(cropNode)
        addChild(titleLabel)

        isHidden = true
        zPosition = 60
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public API

    /// Add a new log entry with the given type.
    func addEntry(text: String, type: CombatLogEntryType = .action) {
        entries.append((text: text, type: type))
        if entries.count > maxEntries {
            entries.removeFirst()
        }
        rebuildLabels()
    }

    /// Toggle log visibility.
    func setVisible(_ visible: Bool) {
        isHidden = !visible
    }

    /// Toggle current visibility.
    func toggle() {
        isHidden.toggle()
    }

    // MARK: - Rebuild

    private func rebuildLabels() {
        entryLabels.forEach { $0.removeFromParent() }
        entryLabels.removeAll()

        let panelH = CombatLogOverlay.panelSize.height
        let startY = panelH / 2 - 40

        for (i, entry) in entries.enumerated().reversed() {
            let label = SKLabelNode(fontNamed: "AvenirNext-Regular")
            label.text = entry.text
            label.fontSize = fontSize
            label.fontColor = entry.type.color
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top

            let lineIndex = CGFloat(entries.count - 1 - i)
            label.position = CGPoint(
                x: -CombatLogOverlay.panelSize.width / 2 + 12,
                y: startY - lineIndex * lineHeight
            )

            contentNode.addChild(label)
            entryLabels.append(label)
        }
    }
}
