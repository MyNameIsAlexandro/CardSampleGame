# Audit Fixlist — Engine Foundation (NO-GO → GO)

**Цель:** довести текущую стадию до состояния "Stage Accepted / Source of Truth", где тесты являются судьёй, а архитектура — фундаментом DLC/паков.

**Статус:** ✅ GO (Critical issues fixed)
**Дата обновления:** 2026-01-26

---

## 0) Определение приёмки (Definition of Done)
Стадия считается принятой, если выполнены все пункты ниже и проходят gate tests:
1. ✅ Gate tests показывают **реальный статус** (не skip, не silent pass).
2. ✅ Все pack-driven сущности имеют **стабильные ID** (`String definitionId`), без fallback на UUID.
3. ✅ RNG состояние сохраняется и восстанавливается (determinism после Save/Load).
4. ✅ Нет мёртвых/неиспользуемых параметров конфигурации (`unitsPerDay`) — удалено.
5. ✅ Локализация имеет единый канон (inline LocalizedString).
6. ✅ Binary pack v2 с SHA256 checksum реализован (B2 — ЗАКРЫТО 2026-02-03).

---

# A) Блокеры архитектуры и данных

## A1) ✅ UUID + optional definitionId в runtime модели (DLC/Save incompatibility) — ИСПРАВЛЕНО
**Проблема:**
В `TwilightEngine/Core/TwilightGameEngine.swift` у `EngineRegionState` и `EngineAnchorState`:
- `id: UUID`
- `definitionId: String?` (опционально)

В `EngineSave` есть fallback вида:
- `definitionId ?? region.id.uuidString`

**Почему это катастрофа:**
Если где-то появится `definitionId == nil`, сейв "цементирует" случайный UUID как идентификатор сущности. Это ломает:
- совместимость контента,
- совместимость сейвов,
- обновления паков,
- композицию нескольких паков.

### Требования к исправлению (без костылей)
1. ✅ `definitionId` должен быть **обязательным** (`String`, non-optional) для всех pack-driven сущностей:
   - region / anchor / event / quest / card / enemy / hero
2. ✅ Полностью удалить fallback `uuidString` из сейвов и runtime.
3. ✅ Любые legacy-инициализаторы/мосты держать **только** в `Migration/`, не в core-типах.

### Acceptance / Gate tests
- ✅ `testSaveLoadUsesStableDefinitionIdsOnly()` — в сейве запрещены UUID для контента.
- ✅ `testDefinitionIdIsNonOptional()` — runtime типы имеют обязательный definitionId.
- ✅ `testNoUuidFallbackInSave()` — нет fallback на uuidString в EngineSave.

### Реализация
- `EngineRegionState.definitionId` → `String` (non-optional)
- `EngineAnchorState.definitionId` → `String` (non-optional)
- `Quest.definitionId` → `String` (non-optional)
- `RegionSaveState` — удалён fallback на uuidString

---

## A2) ✅ RNG seed/state в сейве заведён, но не используется (non-deterministic after load) — ИСПРАВЛЕНО
**Проблема:**
В `EngineSave` поле `rngSeed` существует, но в `TwilightGameEngine.createSave()` выставляется `nil`.

**Почему это опасно:**
Если после загрузки есть хотя бы один случайный выбор (event selection, fate deck, market), продолжение кампании становится нерепродуцируемым. Regression tests теряют смысл.

### Требования к исправлению
1. ✅ Сейв обязан хранить **RNG state**, а не только "seed":
   - `seed` + `position/state` генератора **или**
   - полное состояние колод/пулов (для FateDeck — must).
2. ✅ При `load(save)` движок обязан восстанавливать RNG state до продолжения игры.

### Acceptance / Gate tests
- ✅ `testSaveLoadRestoresRngState()` — одинаковый seed+state → одинаковые дальнейшие выборы.
- ✅ `testEngineSaveHasRngStateField()` — проверяет наличие rngState в EngineSave.
- ✅ `testCreateSaveSavesRngState()` — проверяет что createSave() сохраняет RNG state.

### Реализация
- `EngineSave.rngState: UInt64?` — добавлено поле для состояния генератора
- `createSave()` → `rngSeed: WorldRNG.shared.currentSeed(), rngState: WorldRNG.shared.currentState()`
- `restoreFromEngineSave()` → `WorldRNG.shared.restoreState(state)`

---

## A3) ✅ unitsPerDay в TimeBalanceConfig не используется (мёртвый элемент) — ИСПРАВЛЕНО
**Проблема:**
`TimeBalanceConfig.unitsPerDay` есть, но не используется.

### Требования (без времянок)
- ✅ Удалено поле из конфигурации и спека.

### Acceptance
- ✅ Нет мёртвых конфиг-полей в v1.0.

### Реализация
- Удалено `unitsPerDay` из `TimeBalanceConfig` в `BalanceConfiguration.swift`
- Удалена валидация `unitsPerDay` из `PackValidator.swift`
- Удалено `units_per_day` из `balance.json`
- Обновлены спецификации `SPEC_BALANCE_PACK.md` и `SPEC_BALANCE_PACK_RU.md`

---

# B) Риски платформы контента (Packs)

## B1) ✅ Локализация: закрепить один канон, запретить гибрид — ИСПРАВЛЕНО
**Проблема:**
Выбран inline `LocalizedString (ru/en)` — это нормально, но нельзя допускать появления параллельно `stringKey + string tables`.

### Требования
1. ✅ Зафиксировать канон локализации (в архитектуре и спеках).
2. ✅ Validator должен запрещать смешивание схем.
3. ✅ UI использует только единый способ получения строк.

### Acceptance / Gate tests
- ✅ `testNoMixedLocalizationSchema()` — валидатор ловит гибрид.
- ✅ `testLocalizationFallbackIsDeterministic()` — fallback детерминирован.
- ✅ `testCanonicalSchemeIsInlineOnly()` — канон = inline.

### Реализация
- `LocalizationValidator.swift` — валидатор схемы локализации
- `LocalizationValidatorTests.swift` — gate-тесты
- `ENGINE_ARCHITECTURE.md` — добавлено описание канона
- Канон: `LocalizedString { "en": "...", "ru": "..." }` (inline only)

---

## B2) ✅ Binary pack v2 с SHA256 checksum — РЕАЛИЗОВАНО (2026-02-03)
**Статус:** Полностью реализовано

**Текущее состояние:**
- Authoring format: JSON ✅
- Runtime format: Binary .pack v2 ✅
- SHA256 checksum: ✅

### Что реализовано
1. ✅ **Pack Compiler CLI** (`pack-compiler`):
   - `pack-compiler compile <dir> <file.pack>` — компиляция JSON → binary
   - `pack-compiler validate <dir>` — валидация pack directory
   - `pack-compiler decompile <file.pack> <dir>` — декомпиляция binary → JSON
   - `pack-compiler info <file.pack>` — информация о pack файле
   - `pack-compiler compile-all <dir>` — компиляция всех паков

2. ✅ **Binary .pack format v2** (42-byte header):
   - Magic bytes: "TWPK" (4 bytes)
   - Format version: 2 (2 bytes, little-endian)
   - Original size: (4 bytes, for decompression)
   - SHA256 checksum: (32 bytes, of compressed data)
   - Compressed payload: zlib

3. ✅ **Integrity verification**:
   - SHA256 checksum computed on compressed data
   - Verification at load time (throws `checksumMismatch` on corruption)
   - `getFileInfo()` for quick header inspection without full load

4. ✅ **Backward compatibility**:
   - Reader supports both v1 (10-byte header) and v2 (42-byte header)
   - Writer always produces v2 format

### Acceptance / Gate tests
- ✅ `testV2WriteProducesValidHeader()` — 42-byte header, version=2
- ✅ `testV2ChecksumVerification()` — SHA256 validation passes
- ✅ `testV2DetectsCorruptedData()` — throws `checksumMismatch` on corruption
- ✅ `testDecompileRoundTrip()` — decompile → recompile → identical content
- ✅ `testDecompileCreatesCorrectDirectoryStructure()` — proper folder layout

### Файлы
- `BinaryPack.swift` — v2 format reader/writer with SHA256
- `PackDecompiler.swift` — pack → JSON extraction
- `main.swift` — CLI with decompile command
- `BinaryPackV2Tests.swift` — 10 tests
- `PackDecompilerTests.swift` — 12 tests

---

# C) Блокеры тестовой модели (“судья” не должен скипаться)

## C1) ✅ Gate tests скипаются из-за неверных путей (false green) — ИСПРАВЛЕНО
**Проблема:**
После выноса Engine в Swift Package, gate-тесты ищут исходники по старым путям (например `Engine/Core/...`), не находят и делают `XCTSkip`, после чего CI зелёный.

Это **катастрофа**: gate test не имеет права skip'аться.

### Требования к исправлению (немедленно)
1. ✅ Все gate-тесты, читающие исходники, обновить под реальные пути Swift Package:
   - `Packages/TwilightEngine/Sources/TwilightEngine/...`
2. ✅ Запретить `XCTSkip` в gate-тестах:
   - если файл не найден → `XCTFail` (stop-the-line).
3. ✅ Ввести общий helper `SourcePathResolver` (в тестах), чтобы пути не дублировались.

### Acceptance
- ✅ Ни один gate-test не содержит `XCTSkip`.
- ✅ Gate suite падает при невозможности проверки.

### Реализация
- `AuditGateTests.swift` - обновлены пути, XCTSkip → XCTFail
- `CodeHygieneTests.swift` - XCTSkip → XCTFail
- `DesignSystemComplianceTests.swift` - XCTSkip → XCTFail
- `SourcePathResolver.swift` - централизованный helper для путей

---

## C2) ✅ Gate не ловит "optional definitionId + uuidString fallback" — ИСПРАВЛЕНО
**Проблема:**
Существующие проверки ловят Set'ы id у событий и т.п., но не ловят:
- `definitionId` optional
- fallback на uuidString
- генерацию новых UUID при восстановлении

### Требования
1. ✅ Запретить optional definitionId в runtime types (см. A1).
2. ✅ Запретить uuidString fallback в save (см. A1).
3. ✅ Добавить отдельный gate:
   - "в production runtime сущность без definitionId = fatal error до старта".

### Acceptance / Gate tests
- ✅ `testDefinitionIdIsNonOptional()` — сканирует исходники на String? definitionId
- ✅ `testNoUuidFallbackInSave()` — проверяет отсутствие fallback в EngineSave

### Реализация
- Gate-тесты сканируют исходный код на наличие `String?` для definitionId
- При обнаружении optional — тест падает с XCTFail

---

# D) Резюме: причины NO-GO → ✅ ИСПРАВЛЕНО
- ✅ Gate-тесты не скипаются → тесты судья.
- ✅ definitionId non-optional, uuid fallback удалён → DLC/сейвы устойчивы.
- ✅ RNG state сохраняется и восстанавливается → regression достоверен.

---

# E) Минимальный набор задач для немедленного выполнения (Stop-the-line) → ✅ ВЫПОЛНЕНО
1. ✅ Убрать `XCTSkip` из gate tests и исправить пути под Swift Package.
2. ✅ Сделать `definitionId` non-optional в runtime types и удалить uuid fallback.
3. ✅ Сохранить и восстановить RNG/FateDeck state через EngineSave.
4. ✅ Удалить `unitsPerDay` (удалено из конфига и спеков).

---

# F) Technical Debt — ✅ ЗАКРЫТО (2026-02-03)

> Все пункты технического долга закрыты. Gate-тесты проходят.

## F1) ✅ Legacy Adapters / Legacy Initialization в WorldMapView — ИСПРАВЛЕНО
**Статус:** Закрыто. WorldMapView использует чистую Engine-First архитектуру.

### Что сделано
- WorldMapView содержит только Engine-First инициализацию
- Нет legacy init/ветки/комментарии
- Все View → Intent → ViewModel → Engine → State

### Acceptance / Gate tests
- ✅ `testNoLegacyInitializationInViews()` — проходит
- ✅ `testNoLegacyInitializationCommentsInWorldMapView()` — проходит

---

## F2) ✅ AssetRegistry safety (защита от отсутствующих картинок) — ИСПРАВЛЕНО
**Статус:** Закрыто. AssetRegistry возвращает SF Symbol fallback для отсутствующих ассетов.

### Что сделано
- AssetRegistry реализует 3-уровневый fallback chain:
  1. Основной ассет (e.g., `region_forest`)
  2. Fallback ассет (e.g., `unknown_region`)
  3. SF Symbol (e.g., `mappin.circle`)
- SafeImage и AssetValidator обеспечивают дополнительную защиту
- Прямые `UIImage(named:)` запрещены в Views и ViewModels

### Acceptance / Gate tests
- ✅ `testMissingAssetHandling_returnsPlaceholder()` — проходит
- ✅ `testAssetRegistry_returnsFallbackForMissingAssets()` — проходит
- ✅ `testNoDirectUIImageNamedInViewsAndViewModels()` — проходит

---

# G) Expression Conditions — Critical Missing Validation (Stop-the-Line)

## G1) ✅ Опечатки в condition (например WorldResonanse) не должны проходить — ИСПРАВЛЕНО
**Проблема:** сейчас тесты доверяют синтаксису JSON, но не всегда проверяют **логическую валидность выражений**.
Пример: `"condition": "WorldResonanse < -50"` (опечатка) → условие никогда не сработает, баг будет "тихий".

### Архитектурное решение
Движок использует **типизированные enums** для всех conditions, а не строковые выражения. Это обеспечивает:
- Защиту на уровне компиляции (неизвестное значение = ошибка парсинга JSON)
- Невозможность опечаток типа "WorldResonanse" (просто не скомпилируется/не распарсится)
- Whitelist условий определён в `AbilityConditionType`, `AbilityTrigger`, `HeroAbilityEffectType`

### Требования (без костылей)
1. ✅ В движке существует **строгий валидатор** для условий — `ConditionValidator`.
2. ✅ Все condition types определены как **typed enums с CaseIterable**.
3. ✅ Неизвестное значение приводит к `DecodingError` (hard fail).
4. ✅ Whitelist определён в enum'ах: `AbilityConditionType`, `AbilityTrigger`, `HeroAbilityEffectType`.

### Acceptance / Tests
- ✅ `ConditionValidatorTests.swift`:
  - `testValidAbilityConditionTypesExist()` — whitelist не пустой
  - `testRejectsUnknownConditionType()` — `"WorldResonanse"` → rejected
  - `testRejectsUnknownTrigger()` — `"onDamageRecieved"` → rejected (typo)
  - `testConditionsUseTypedEnumsNotStrings()` — JSON с неизвестным enum = DecodingError
- ✅ `testAllPackConditionsAreValid()` — интеграционный тест всех паков

### Реализация
- `ConditionValidator.swift` — валидатор с whitelist
- `ConditionValidatorTests.swift` — gate-тесты
- `AbilityConditionType: CaseIterable` — whitelist condition types
- `AbilityTrigger: CaseIterable` — whitelist triggers
- `RegionState: CaseIterable` — whitelist region states

---

# H) Обновление приёмки (Definition of Done) → ✅ ВЫПОЛНЕНО
Приёмка стадии как "Source of Truth":
- ✅ Gate tests не могут skip'аться (XCTSkip → XCTFail)
- ✅ Все conditions в pack'ах валидируются ConditionValidator'ом (typed enums)
- ✅ Ошибки в переменных/функциях ловятся на этапе парсинга JSON (DecodingError)

---

# I) Оставшиеся задачи (Non-Blocking)

## Warnings (не блокируют приёмку)
- Нет открытых warnings

## Tech Debt
- ✅ ~~**F1)** Legacy Adapters / Legacy Initialization в WorldMapView~~ — ЗАКРЫТО
- ✅ ~~**F2)** AssetRegistry safety (placeholder для отсутствующих ассетов)~~ — ЗАКРЫТО
- ✅ ~~**B2)** Binary pack v2 с SHA256 checksum~~ — ЗАКРЫТО (2026-02-03)

**Весь технический долг закрыт. Все warnings разрешены.**
