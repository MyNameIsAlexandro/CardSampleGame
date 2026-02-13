/// Файл: App/CardGameApp.swift
/// Назначение: Содержит реализацию файла CardGameApp.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI

@main
struct CardGameApp: App {
    @StateObject private var contentLoader = ContentLoader()

    var body: some Scene {
        WindowGroup {
            if contentLoader.isLoaded, let services = contentLoader.services {
                ContentView(services: services)
            } else {
                LoadingView(loader: contentLoader)
            }
        }
    }
}
