# MIGRATION_PLAN.md — Engine v1.0 Release Gates (No Temporary Fixes)

Версия: 1.0
Статус: Active
Цель: привести проект к состоянию Engine-first / Pack-driven / Deterministic / Release-safe без костылей и временных решений.

Принципы выполнения

1. Нет временных решений. Если компонент нарушает архитектуру — он удаляется или переписывается до соответствия.
2. Один источник истины. Контент берётся только из Pack’ов; runtime меняется только через Engine.
3. Детерминизм обязателен. Любая случайность в Engine/Core запрещена, кроме DevTools/Tests.
4. Тесты = судья. Любая критическая гарантия должна быть закреплена автоматическими тестами (gate tests).
5. Релиз запрещён, пока все задачи ниже не закрыты.

---

## Epic 0 — Release Safety & Build Hygiene (Critical)

### 0.1 Asset Catalog Safety (Fallback icons)

**Задачи**
* Добавить placeholder ассет `unknown_region` в `Assets.xcassets`.
* Создать `AssetRegistry` (единственная точка получения изображений).
* Реализовать fallback: если `UIImage(named: iconName) == nil`, возвращать `unknown_region`.
* Запретить прямые вызовы `UIImage(named:)` в View/ViewModel — только через `AssetRegistry`.

**Acceptance**
* UI никогда не показывает пустую иконку из-за отсутствующего ассета.
* Тест: `testMissingAssetHandling_returnsPlaceholder()`.

### 0.2 Release Configuration (No debug prints)

**Задачи**
* Удалить все `print(...)` из production-кода (Engine/Runtime/PackLoader/UI).
* Ввести `Logger` с уровнями и отключением в Release.
* Проверить схему Release: отсутствие debug output.

**Acceptance**
* `xcodebuild -configuration Release` не содержит debug-print логики.
* (Gate) Тест-скан: `testNoPrintsInProductionSources()`.

### 0.3 Version Lock (Hash lock for v1.0 content)

**Задачи**
* Добавить механизм хэширования контента (sha256) для всех pack-файлов авторинга и/или compiled pack.
* Сохранять fingerprint в manifest и/или ContentFingerprint.
* При загрузке: сверка fingerprint → при несовпадении `ContentError.hashMismatch` (graceful error, без crash).

**Acceptance**
* Тест: `testContentHashMismatchThrowsError()`.

---

## Epic 1 — One Truth Runtime (Critical)

### 1.1 Удалить legacy runtime модели из production flow

**Задачи**
* Найти и удалить из runtime пути любые legacy Models/WorldState, GameState, старые registries и любые прямые мутации state из UI.

**Acceptance**
* `Views/` не импортируют и не используют legacy модели.
* Gate скан: `testNoLegacyWorldStateUsageInViews()`.

### 1.2 “Один движок = одна истина”

**Задачи**
* Production runtime engine должен быть единственным исполняемым движком в проекте.
* Удалить `CoreGameEngine.swift` (или любой альтернативный runtime engine), если он не соответствует контрактам и/или содержит системный RNG.
* Контрактные тесты должны выполняться на production engine.

**Acceptance**
* Тест: `testContractsAgainstProductionEngine()`.

---

## Epic 2 — Single Source of Content (Packs only) (Critical)

### 2.1 Удалить кодовые реестры контента из runtime

**Задачи**
* Удалить `TwilightMarchesCards.swift` из runtime пути. Допускается только в `DevTools/` как источник для компилятора паков.
* Удалить `CardRegistry.registerBuiltInCards()` и любые аналоги.
* Вся загрузка карт/героев/квестов/ивентов осуществляется через `ContentRegistry` (pack-driven).

**Acceptance**
* Gate скан: `testRuntimeDoesNotAccessCodeRegistries()`.
* Новый герой/карта добавляется изменением pack-файла без изменения кода.

---

## Epic 3 — Stable IDs Everywhere (Critical)

### 3.1 Запрет UUID для контентных сущностей

**Задачи**
* Во всём runtime state и save: использовать строковые definition IDs (`String`), а не `UUID`.
* Instance IDs допустимы только как отдельное поле и никогда не используются как ссылка на definition.
* `EngineSave` хранит только:
    * `regionDefinitionId`, `anchorDefinitionId`, `eventDefinitionId`, `cardDefinitionId`, `enemyDefinitionId`, `heroDefinitionId`
    * и т.п.

**Acceptance**
* Тест: `testSaveLoadUsesStableDefinitionIdsOnly()`.

---

## Epic 4 — Determinism & Forbidden APIs (Critical)

### 4.1 Запрет системного RNG в Engine/Core и Pack loader

**Задачи**
* Удалить использование:
    * `randomElement()`, `.shuffled()`, `Double.random`, `Int.random`
    * из Engine/Core, PackLoader, EventPipeline, DegradationRules, Market generation и любых core-paths.
* Вся случайность проходит через deterministic RNG (seeded).

**Acceptance**
* Gate скан: `testNoSystemRandomInEngineCore()`.
* Regression harness не флакает.

---

## Epic 5 — Pack Localization Canon (Critical)

### 5.1 Канон строк: stringKey + string tables

**Задачи**
* В pack’ах и спеках запрещены raw strings в полях, которые должны быть локализуемыми.
* Все сущности используют `stringKey`.
* Pack содержит string tables per locale.
* Missing key: fallback на Core strings + warning.

**Acceptance**
* Validator падает при raw strings в обязательных полях.
* Тесты:
    * `testPackLocalizationOverridesCore()`
    * `testMissingLocalizationKeyFallsBackToCore()`.

---

## Epic 6 — Pack Composition (Arkham-like) (Critical)

### 6.1 Campaign + Investigator packs совместимы

**Задачи**
* Реализовать композицию packset:
    * campaign pack + heroes pack из разных паков должны загружаться одновременно.
* Гарантировать отсутствие коллизий ID (namespaced ids или packId-prefix enforced validator).

**Acceptance**
* Тест: `testCampaignPackPlusInvestigatorPackComposition()`.

---

## Epic 7 — Save Compatibility (PackSet-aware) (High)

### 7.1 Сейв хранит packset и версии

**Задачи**
* Save обязан хранить:
    * `coreVersion`, `formatVersion`
    * `activePackSet: { packId: version }`
    * `primaryCampaignPackId`
* Load обязан:
    * проверять packset и совместимость
    * выдавать понятную ошибку, без crash.

**Acceptance**
* Тест: `testSaveStoresPackSetAndRefusesIncompatibleLoad()`.

---

## Epic 8 — Physical Modularization (High)

### 8.1 Вынести Engine в локальный Swift Package

**Задачи**
* Перенести `Engine/` и runtime models в локальный Swift Package.
* Минимизировать public API.
* UI не может обращаться к internal деталям Engine.

**Acceptance**
* Project builds; UI не компилируется при попытке доступа к internal Engine.

---

## Epic 9 — Design System for UI (Medium)

### 9.1 Удалить “магические числа” и хардкод цветов в UI

**Задачи**
* Добавить `DesignSystem.swift` / `AppTheme.swift`.
* Перевести:
    * padding/frames/colors на константы DesignSystem.

**Acceptance**
* `WorldMapView` не содержит числовых magic constants (кроме редких случаев в layout primitives).
* Theme можно поменять централизованно.

---

## Epic 10 — Documentation & Code Hygiene (Medium)

### 10.1 Swift Doc Comments на public API Engine

**Задачи**
* Все public методы Engine/ContentLoader/ContentRegistry имеют `///` doc comments.

**Acceptance**
* Quick Help показывает корректные описания.

### 10.2 “1 файл = 1 основной тип”

**Задачи**
* Разнести файлы, где смешаны типы, энумы и большие extension блоки.
* Extension оформлять через `MARK` либо отдельными файлами.

---

## Epic 11 — QA/Test Model Corrections (Critical)

### 11.1 Удалить неактуальные тесты legacy state

**Задачи**
* Удалить тесты, которые проверяют поведение внутри `WorldState`, если он DTO/struct и не содержит логики.
* Удалить тесты на конкретные имена (“Деревня”) — имена теперь контентные.

### 11.2 Усилить негативные сценарии загрузчика контента

**Задачи**
* Добавить тесты:
    * `testBrokenJsonThrowsContentError()`
    * `testMissingRequiredFieldsThrowsContentError()`
    * `testContentIntegrity()` (neighbors/event refs exist)

### 11.3 Persistence round-trip

**Задачи**
* Добавить:
    * `testStateRoundTripSerialization()` (encode/decode сохраняет эквивалентное состояние)

---

## Documentation Cleanup Directive (после закрытия Critical)

**Задачи**
* Создать `Docs/Archive/`.
* Переместить устаревшие MIGRATION/AUDIT/старые отчёты в архив.
* В корне Docs оставить только “конституцию”:
    * `ENGINE_ARCHITECTURE.md`
    * `EVENT_MODULE_ARCHITECTURE.md`
    * `SPEC_*` packs
    * `QA_ACT_I_CHECKLIST.md`
    * `INDEX.md`
    * `CHANGELOG.md`

---

**Release Gates (Stop-the-line)**
Релиз запрещён, пока не выполнены все условия аудита.
