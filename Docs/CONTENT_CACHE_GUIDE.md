# Система кеширования контента

## Обзор

Система кеширования контента — это универсальный механизм движка для персистентного хранения загруженного контента. Она позволяет:

- Ускорить повторные запуски приложения
- Уменьшить время загрузки за счёт пропуска парсинга JSON
- Автоматически инвалидировать кеш при изменении контента

## Архитектура

```
┌─────────────────────────────────────────────────────────────────┐
│                         CardGameApp                             │
│                              │                                  │
│                              ▼                                  │
│                       ContentLoader                             │
│                              │                                  │
│              ┌───────────────┼───────────────┐                 │
│              ▼               ▼               ▼                 │
│       CacheValidator   FileSystemCache  PackLoader             │
│       (SHA256 хеш)     (JSON хранилище)  (парсинг JSON)       │
│                              │                                  │
│                              ▼                                  │
│                       ContentRegistry                           │
│                       (mergedContent)                           │
└─────────────────────────────────────────────────────────────────┘
```

## Компоненты

### CacheValidator

Отвечает за:
- Вычисление SHA256 хеша всех JSON файлов пака
- Проверку валидности кеша по хешу и версии движка

```swift
// Вычисление хеша контента
let hash = try CacheValidator.computeContentHash(for: packURL)

// Проверка валидности
let isValid = CacheValidator.isCacheValid(
    metadata: cachedMetadata,
    currentHash: hash
)
```

### FileSystemCache

Реализация кеша на основе файловой системы:
- Хранит данные в `~/Library/Application Support/CardSampleGame/ContentCache/`
- Использует JSON для сериализации
- Поддерживает операции CRUD для кешированных паков

```swift
let cache = FileSystemCache.shared

// Проверка наличия валидного кеша
if cache.hasValidCache(for: packId, contentHash: hash) {
    // Загрузка из кеша
    let cached = try cache.loadCachedPack(packId: packId)
} else {
    // Загрузка из JSON и сохранение в кеш
    let pack = try PackLoader.load(manifest: manifest, from: url)
    try cache.savePack(pack, contentHash: hash)
}
```

### CacheMetadata

Метаданные кеша для быстрой проверки валидности:

```swift
struct CacheMetadata: Codable {
    let packId: String           // ID пака
    let version: SemanticVersion // Версия пака
    let contentHash: String      // SHA256 хеш контента
    let cachedAt: Date           // Время создания кеша
    let engineVersion: String    // Версия движка
}
```

### CachedPackData

Полные данные пака для сериализации:

```swift
struct CachedPackData: Codable {
    let metadata: CacheMetadata
    let manifest: PackManifest
    let regions: [String: RegionDefinition]
    let events: [String: EventDefinition]
    let quests: [String: QuestDefinition]
    let anchors: [String: AnchorDefinition]
    let heroes: [String: StandardHeroDefinition]
    let cards: [String: StandardCardDefinition]
    let enemies: [String: EnemyDefinition]
    let balanceConfig: BalanceConfiguration?
}
```

## Алгоритм инвалидации

Кеш считается **невалидным** если:

1. **Хеш контента изменился** — любое изменение в JSON файлах пака
2. **Major или Minor версия движка изменилась** — для обеспечения совместимости
3. **Файл кеша отсутствует или повреждён**

```
Запуск приложения
       │
       ▼
┌──────────────────────┐
│ Вычислить хеш JSON   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐     Нет     ┌─────────────────┐
│ Кеш существует и     │────────────▶│ Загрузить из    │
│ хеш совпадает?       │             │ JSON            │
└──────────┬───────────┘             └────────┬────────┘
           │ Да                               │
           ▼                                  │
┌──────────────────────┐                     │
│ Загрузить из кеша    │                     │
│ (быстрый путь)       │                     ▼
└──────────────────────┘             ┌─────────────────┐
                                     │ Сохранить в кеш │
                                     └─────────────────┘
```

## Структура файлов кеша

```
~/Library/Application Support/CardSampleGame/ContentCache/
├── twilight-marches-act1/
│   ├── metadata.json      # CacheMetadata (для быстрой проверки)
│   └── content.json       # CachedPackData (полный контент)
└── another-pack-id/
    ├── metadata.json
    └── content.json
```

## Использование в ContentLoader

```swift
private func loadContentPacks() async {
    // 1. Найти пак
    guard let packURL = await findPackURL() else { return }

    // 2. Вычислить хеш контента
    let contentHash = try? CacheValidator.computeContentHash(for: packURL)
    let manifest = try? PackManifest.load(from: packURL)

    // 3. Проверить кеш
    if let hash = contentHash,
       let m = manifest,
       cache.hasValidCache(for: m.packId, contentHash: hash) {
        // Быстрый путь: загрузка из кеша (~50ms)
        let cached = try cache.loadCachedPack(packId: m.packId)
        ContentRegistry.shared.loadPackFromCache(cached)
    } else {
        // Медленный путь: загрузка из JSON (~500ms)
        let pack = try ContentRegistry.shared.loadPack(from: packURL)
        if let hash = contentHash {
            try cache.savePack(pack, contentHash: hash)
        }
    }
}
```

## API для разработчиков

### ContentCache Protocol

```swift
protocol ContentCache {
    /// Проверить наличие валидного кеша
    func hasValidCache(for packId: String, contentHash: String) -> Bool

    /// Загрузить закешированный пак
    func loadCachedPack(packId: String) throws -> CachedPackData?

    /// Сохранить пак в кеш
    func savePack(_ pack: LoadedPack, contentHash: String) throws

    /// Инвалидировать кеш для пака
    func invalidateCache(for packId: String)

    /// Очистить весь кеш
    func clearAllCache()

    /// Получить метаданные без загрузки контента
    func getCacheMetadata(for packId: String) -> CacheMetadata?
}
```

### ContentRegistry Extension

```swift
extension ContentRegistry {
    /// Загрузить пак из кешированных данных
    func loadPackFromCache(_ cached: CachedPackData) -> LoadedPack
}
```

## Тестирование

### Unit тесты

```swift
// Тест консистентности хеша
func testContentHashIsConsistent() {
    let hash1 = try CacheValidator.computeContentHash(for: packURL)
    let hash2 = try CacheValidator.computeContentHash(for: packURL)
    XCTAssertEqual(hash1, hash2)
}

// Тест валидности кеша
func testCacheValidityWithMatchingHash() {
    let metadata = CacheMetadata(...)
    XCTAssertTrue(CacheValidator.isCacheValid(
        metadata: metadata,
        currentHash: "same-hash"
    ))
}

// Тест сохранения/загрузки
func testSaveAndLoadPackRoundtrip() {
    try cache.savePack(pack, contentHash: hash)
    let loaded = try cache.loadCachedPack(packId: pack.manifest.packId)
    XCTAssertEqual(loaded?.regions.count, pack.regions.count)
}
```

### Ручное тестирование

1. Удалить кеш:
   ```bash
   rm -rf ~/Library/Application\ Support/CardSampleGame/ContentCache/
   ```

2. Запустить приложение — должен загрузить из JSON и создать кеш

3. Перезапустить — должен загрузить из кеша (быстрее)

4. Изменить любой JSON в ContentPacks — должен перезагрузить из JSON

## Расширяемость

Система спроектирована универсально:

1. **Протокол ContentCache** позволяет реализовать другие бэкенды (CoreData, SQLite, iCloud)

2. **CachedPackData** содержит все типы контента и расширяем

3. **CacheValidator** независим от способа хранения

4. **Версионирование движка** гарантирует совместимость при обновлениях

## Ограничения

- Кеш хранится локально на устройстве
- При первом запуске всегда загружается из JSON
- Большие паки могут требовать значительного места на диске

## Файлы

| Файл | Описание |
|------|----------|
| `Engine/ContentPacks/Cache/CacheValidator.swift` | Валидация и хеширование |
| `Engine/ContentPacks/Cache/FileSystemCache.swift` | Реализация кеша |
| `Engine/ContentPacks/PackTypes.swift` | Структуры CacheMetadata, CachedPackData |
| `App/CardGameApp.swift` | Интеграция в ContentLoader |
