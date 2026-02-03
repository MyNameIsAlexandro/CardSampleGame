import FirebladeECS
import CoreGraphics

public final class LabelComponent: Component {
    public var text: String
    public var fontName: String
    public var fontSize: CGFloat
    public var colorName: String
    public var verticalOffset: CGFloat
    public var horizontalOffset: CGFloat

    public init(
        text: String,
        fontName: String = "AvenirNext-Bold",
        fontSize: CGFloat = 14,
        colorName: String = "white",
        verticalOffset: CGFloat = 0,
        horizontalOffset: CGFloat = 0
    ) {
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.colorName = colorName
        self.verticalOffset = verticalOffset
        self.horizontalOffset = horizontalOffset
    }
}
