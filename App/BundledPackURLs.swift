/// Файл: App/BundledPackURLs.swift
/// Назначение: Содержит реализацию файла BundledPackURLs.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation

#if DEBUG
import CoreHeroesContent
import TwilightMarchesActIContent

func getBundledPackURLs() -> [URL] {
    var urls: [URL] = []
    if let heroesURL = CoreHeroesContent.packURL {
        urls.append(heroesURL)
    }
    if let storyURL = TwilightMarchesActIContent.packURL {
        urls.append(storyURL)
    }
    return urls
}
#endif
