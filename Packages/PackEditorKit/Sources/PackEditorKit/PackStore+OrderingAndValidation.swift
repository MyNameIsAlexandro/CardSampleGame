/// Файл: Packages/PackEditorKit/Sources/PackEditorKit/PackStore+OrderingAndValidation.swift
/// Назначение: Содержит реализацию файла PackStore+OrderingAndValidation.swift.
/// Зона ответственности: Реализует пакетный API редактора контента.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine
import PackAuthoring

extension PackStore {

    // MARK: - Entity Order

    public func orderedEntityIds(for category: ContentCategory) -> [String] {
        if let order = entityOrder[category] {
            let existingIds = Set(entityIds(for: category))
            let ordered = order.filter { existingIds.contains($0) }
            let remaining = entityIds(for: category).filter { !order.contains($0) }
            return ordered + remaining
        }
        return entityIds(for: category)
    }

    public func saveEntityOrder() throws {
        guard let url = packURL else { throw PackStoreError.noPackLoaded }
        let orderURL = url.appendingPathComponent("_editor_order.json")
        let dictionary = Dictionary(uniqueKeysWithValues: entityOrder.map { ($0.key.rawValue, $0.value) })
        let data = try JSONEncoder().encode(dictionary)
        try data.write(to: orderURL)
    }

    public func loadEntityOrder() {
        guard let url = packURL else { return }
        let orderURL = url.appendingPathComponent("_editor_order.json")
        guard let data = try? Data(contentsOf: orderURL),
              let dictionary = try? JSONDecoder().decode([String: [String]].self, from: data) else { return }
        entityOrder = Dictionary(uniqueKeysWithValues: dictionary.compactMap { key, value in
            guard let category = ContentCategory(rawValue: key) else { return nil }
            return (category, value)
        })
    }

    // MARK: - Validate

    @discardableResult
    public func validate() -> PackValidator.ValidationSummary? {
        guard let url = packURL else {
            updateValidationSummary(nil)
            return nil
        }
        let validator = PackValidator(packURL: url)
        let summary = validator.validate()
        updateValidationSummary(summary)
        return summary
    }
}
