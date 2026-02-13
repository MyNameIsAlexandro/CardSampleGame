/// Файл: Packages/EchoEngine/Tests/EchoEngineTests/EchoEngineTests.swift
/// Назначение: Содержит реализацию файла EchoEngineTests.swift.
/// Зона ответственности: Проверяет контракт пакетного модуля и сценарии регрессий.
/// Контекст: Используется в автоматических тестах и quality gate-проверках.

import Testing
@testable import EchoEngine

@Suite("EchoEngine Smoke Tests")
struct EchoEngineTests {
    @Test("Package compiles and version is set")
    func testVersion() {
        #expect(EchoEngine.version == "0.1.0")
    }
}
