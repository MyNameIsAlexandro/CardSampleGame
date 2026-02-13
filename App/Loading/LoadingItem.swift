/// Файл: App/Loading/LoadingItem.swift
/// Назначение: Модель строки прогресса загрузки контента.
/// Зона ответственности: Описывает элемент списка загрузки и его статус.
/// Контекст: Используется экраном загрузки и ContentLoader.

import Foundation

struct LoadingItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var count: Int?
    var status: LoadingItemStatus

    enum LoadingItemStatus {
        case pending
        case loading
        case loaded
        case failed
    }
}
