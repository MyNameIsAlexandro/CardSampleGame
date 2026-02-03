import FirebladeECS
import CoreGraphics

public final class HealthBarComponent: Component {
    public var showHP: Bool
    public var showWill: Bool
    public var barWidth: CGFloat
    public var verticalOffset: CGFloat
    public var horizontalOffset: CGFloat

    public init(
        showHP: Bool = true,
        showWill: Bool = false,
        barWidth: CGFloat = 60,
        verticalOffset: CGFloat = -40,
        horizontalOffset: CGFloat = 0
    ) {
        self.showHP = showHP
        self.showWill = showWill
        self.barWidth = barWidth
        self.verticalOffset = verticalOffset
        self.horizontalOffset = horizontalOffset
    }
}
