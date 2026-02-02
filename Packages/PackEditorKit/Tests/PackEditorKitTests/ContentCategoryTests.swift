import XCTest
@testable import PackEditorKit
import TwilightEngine

final class ContentCategoryTests: XCTestCase {
    func testCharacterPackCategories() {
        let cats = ContentCategory.categories(for: .character)
        XCTAssertEqual(cats, [.heroes, .cards])
    }

    func testCampaignPackCategories() {
        let cats = ContentCategory.categories(for: .campaign)
        XCTAssertTrue(cats.contains(.enemies))
        XCTAssertTrue(cats.contains(.regions))
        XCTAssertTrue(cats.contains(.events))
        XCTAssertTrue(cats.contains(.balance))
        XCTAssertFalse(cats.contains(.heroes))
    }

    func testFullPackReturnsAll() {
        let cats = ContentCategory.categories(for: .full)
        XCTAssertEqual(Set(cats), Set(ContentCategory.allCases))
    }
}
