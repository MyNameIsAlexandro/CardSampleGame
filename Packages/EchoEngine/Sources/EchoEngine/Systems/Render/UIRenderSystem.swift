import SpriteKit
import FirebladeECS

public final class UIRenderSystem: EchoSystem {
    public let registry: NodeRegistry

    private static let hpBarName = "echo_hp_bar"
    private static let hpBarBgName = "echo_hp_bar_bg"
    private static let willBarName = "echo_will_bar"
    private static let willBarBgName = "echo_will_bar_bg"
    private static let labelName = "echo_label"

    public init(registry: NodeRegistry) {
        self.registry = registry
    }

    public func update(nexus: Nexus) {
        updateHealthBars(nexus: nexus)
        updateLabels(nexus: nexus)
    }

    // MARK: - Health Bars

    private func updateHealthBars(nexus: Nexus) {
        let family = nexus.family(requiresAll: HealthBarComponent.self, HealthComponent.self)
        for entity in family.entities {
            guard let parent = registry.node(for: entity.identifier) else { continue }
            let bar: HealthBarComponent = nexus.get(unsafe: entity.identifier)
            let health: HealthComponent = nexus.get(unsafe: entity.identifier)

            if bar.showHP {
                let fraction = health.max > 0 ? CGFloat(health.current) / CGFloat(health.max) : 0
                syncBar(
                    parent: parent,
                    bgName: Self.hpBarBgName,
                    fillName: Self.hpBarName,
                    fraction: fraction,
                    barWidth: bar.barWidth,
                    yOffset: bar.verticalOffset,
                    color: hpColor(fraction: fraction)
                )
            }

            if bar.showWill && health.maxWill > 0 {
                let fraction = CGFloat(health.will) / CGFloat(health.maxWill)
                syncBar(
                    parent: parent,
                    bgName: Self.willBarBgName,
                    fillName: Self.willBarName,
                    fraction: fraction,
                    barWidth: bar.barWidth,
                    yOffset: bar.verticalOffset - 8,
                    color: .cyan
                )
            }
        }
    }

    private func syncBar(
        parent: SKNode,
        bgName: String,
        fillName: String,
        fraction: CGFloat,
        barWidth: CGFloat,
        yOffset: CGFloat,
        color: SKColor
    ) {
        let barHeight: CGFloat = 6
        let clampedFraction = max(0, min(1, fraction))

        // Background
        let bg: SKShapeNode
        if let existing = parent.childNode(withName: bgName) as? SKShapeNode {
            bg = existing
        } else {
            bg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 3)
            bg.name = bgName
            bg.fillColor = SKColor(white: 0.2, alpha: 0.8)
            bg.strokeColor = .clear
            bg.zPosition = 10
            parent.addChild(bg)
        }
        bg.position = CGPoint(x: 0, y: yOffset)

        // Fill
        let fillWidth = barWidth * clampedFraction
        let fill: SKShapeNode
        if let existing = parent.childNode(withName: fillName) as? SKShapeNode {
            fill = existing
            fill.path = CGPath(
                roundedRect: CGRect(x: -barWidth / 2, y: -barHeight / 2, width: fillWidth, height: barHeight),
                cornerWidth: 3, cornerHeight: 3, transform: nil
            )
        } else {
            fill = SKShapeNode(
                rect: CGRect(x: -barWidth / 2, y: -barHeight / 2, width: fillWidth, height: barHeight),
                cornerRadius: 3
            )
            fill.name = fillName
            fill.strokeColor = .clear
            fill.zPosition = 11
            parent.addChild(fill)
        }
        fill.fillColor = color
        fill.position = CGPoint(x: 0, y: yOffset)
    }

    private func hpColor(fraction: CGFloat) -> SKColor {
        if fraction > 0.5 { return .green }
        if fraction > 0.25 { return .orange }
        return .red
    }

    // MARK: - Labels

    private func updateLabels(nexus: Nexus) {
        let family = nexus.family(requiresAll: LabelComponent.self, SpriteComponent.self)
        for entity in family.entities {
            guard let parent = registry.node(for: entity.identifier) else { continue }
            let label: LabelComponent = nexus.get(unsafe: entity.identifier)

            let labelNode: SKLabelNode
            if let existing = parent.childNode(withName: Self.labelName) as? SKLabelNode {
                labelNode = existing
            } else {
                labelNode = SKLabelNode()
                labelNode.name = Self.labelName
                labelNode.verticalAlignmentMode = .center
                labelNode.horizontalAlignmentMode = .center
                labelNode.zPosition = 10
                parent.addChild(labelNode)
            }
            labelNode.text = label.text
            labelNode.fontName = label.fontName
            labelNode.fontSize = label.fontSize
            labelNode.fontColor = colorFromName(label.colorName)
            labelNode.position = CGPoint(x: 0, y: label.verticalOffset)
        }
    }

    private func colorFromName(_ name: String) -> SKColor {
        switch name {
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "cyan": return .cyan
        default: return .white
        }
    }
}
