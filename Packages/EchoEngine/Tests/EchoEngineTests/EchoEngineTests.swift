import Testing
@testable import EchoEngine

@Suite("EchoEngine Smoke Tests")
struct EchoEngineTests {
    @Test("Package compiles and version is set")
    func testVersion() {
        #expect(EchoEngine.version == "0.1.0")
    }
}
