# CardSampleGame / ECHO: Legends of the Veil — Engineering Contract (v4.1, 2026-02-12)

**Тип проекта:** Narrative Co-op Deckbuilder RPG (iOS)  
**Ядро:** Engine-First + Deterministic Runtime + Data-Driven Content  
**Цель:** зафиксировать обязательные инженерные правила, чтобы развитие продукта не требовало повторного архитектурного рефакторинга.

---

## 0) Иерархия правил

При конфликте применяются правила в этом порядке:

1. **Gate-тесты и CI-контракты** (`CardSampleGameTests/GateTests`, `Packages/TwilightEngine/Tests`).
2. **Этот документ** (`CLAUDE.md`).
3. Остальная документация (`Docs/**`).

Изменение инварианта считается завершённым только при обновлении **кода + тестов + документации** в одном change set.

---

## 1) Архитектурные инварианты (не обсуждаются)

### 1.1 Engine-First и action pipeline
- Единственный источник истины — runtime-state в `TwilightGameEngine`.
- Любая мутация состояния — только через канонический action/facade-путь.
- App/UI/Bridge не мутируют engine state напрямую.

### 1.2 Границы слоёв
- `Packages/TwilightEngine` — pure logic, без UI-фреймворков (`SwiftUI`, `UIKit`, `AppKit`, `SpriteKit`, `SceneKit`).
- App/Views — presentation + intent dispatch.
- Bridge — адаптер данных, не место для доменной логики ядра.

### 1.3 Determinism-first
- Системный RNG запрещён в gameplay-потоке.
- Seed внешнего боя рождается внутри engine action-пути (`.startCombat`), не в App.
- Save/load/resume обязаны быть воспроизводимыми для одного pack set и одинакового входного состояния.

### 1.4 External combat как транзакция
- Старт боя: engine отдаёт snapshot/seed/context.
- Завершение боя: engine принимает единый commit через канонический API (`commitExternalCombat` / action).
- Любые `pending*` поля изменяются только ядром.

### 1.5 Arena/Quick Battle изоляция
- Arena — sandbox-режим.
- Arena не потребляет RNG мирового движка.
- Arena не коммитит результат в main world-engine state (если это не отдельный явно поддержанный режим с собственным контрактом и тестами).

---

## 2) Контракты по модулям

### 2.1 `Packages/TwilightEngine`
- Только типизированные причины invalid action:
  - `ActionError.invalidAction(reason: InvalidActionReason)` — да
  - `ActionError.invalidAction(reason: String)` — нет
- `pendingEncounterState` и аналогичные поля — `public private(set)`.
- Публичные обходные API для RNG/seed (`nextSeed(...)`) запрещены.
- `TwilightGameEngine` обязан делегировать домены в sub-managers/facades, а не концентрировать всю логику в одном месте.

### 2.2 Bridge/App слой
- Bridge не расширяет engine доменной логикой.
- App не пишет напрямую в engine внутренние поля (`pendingEncounterState`, `pendingExternalCombatSeed`, `currentEventId` и т.д.).
- Любой state change из UI должен иметь явный intent/action в engine-контракте.

### 2.3 DevTools изоляция
- `TwilightEngineDevTools` не участвует в production graph.
- Legacy pipeline (`EventPipeline`, `MiniGameDispatcher`) допускается только в devtools/тестовом контуре и не может быть неявно активирован в runtime.

---

## 3) Контент и паки

### 3.1 IDs и целостность
- Все content IDs — стабильные `String`.
- UUID/random IDs для контента запрещены.
- Отсутствие обязательного `definitionId` — fail-fast, без silent auto-repair.

### 3.2 Runtime vs Authoring
- Runtime читает только бинарные `.pack` (`BinaryPackReader`, `ContentRegistry.loadPacks`).
- `PackLoader`/`PackCompiler`/`PackValidator` — authoring toolchain, не production runtime.

### 3.3 Совместимость локализованных карт
- При authoring decode порядок:
  1) `PackCardDefinition` (legacy `name_ru` / `description_ru`)
  2) `StandardCardDefinition`
- Это обязательный backward compatibility слой для исторического контента.

### 3.4 После изменений контент-пайплайна
- Пересобрать и перевалидировать `.pack` ресурсы.
- Обязательный прогон `BundledPacksValidationTests`.
- При изменении формата сейва/контента — добавить миграционный тест и документировать версию.

---

## 4) Локализация (hard contract)

### 4.1 Engine и системные сообщения
- В engine нельзя закреплять RU/EN текст как «истину».
- User-facing системные сообщения — через key-based слой (`L10n` / `LocalizationManager`).

### 4.2 Runtime резолв и resume-path
- Локализация резолвится через централизованный resolver, а не через произвольный `Locale.current`.
- В resume/external-combat bridge данные должны пере-локализовываться по текущему registry/locale перед показом пользователю.

### 4.3 UI токены и утечки ключей
- SF Symbols рендерятся только как `Image(systemName:)`.
- Отображение `Text("cross.fill")`, `Text("icon.*")` и любых raw service keys запрещено.
- Появление raw ключей/токенов в UI считается дефектом блокирующего уровня и закрывается регрессионным тестом.

---

## 5) Стандарты кода и декомпозиции

### 5.1 Жёсткие лимиты first-party кода
- Swift-файл: максимум **600 строк**.
- Файл engine: максимум **5 top-level типов**.
- Принцип: `1 file = 1 main type`, расширения — `Type+Feature.swift`.
- Legacy whitelist для first-party кода не допускается.
- Исключения только для внешнего кода: `/.build/`, `/Packages/ThirdParty/`, `/.codex_home/`.

### 5.2 Обязательный заголовок файла
Для production/test Swift-файлов:

```swift
/// Файл: ...
/// Назначение: ...
/// Зона ответственности: ...
/// Контекст: ...
```

### 5.3 Запрет на техдолг в runtime
- `TODO`/`FIXME` в production-коде запрещены.
- Временное решение допустимо только как краткоживущий migration seam с тестом, issue-ссылкой и явным планом удаления.
- Мёртвый код, неиспользуемые классы и legacy-костыли удаляются, а не прячутся за флагами без плана вывода.

---

## 6) Тестовая модель и Quality Gates

### 6.1 Минимальный набор перед интеграцией
- `AuditArchitectureBoundaryGateTests`
- `AuditGateTests`
- `CodeHygieneTests`
- `LocalizationCompletenessTests`
- `LocalizationValidatorTests`
- `BundledPacksValidationTests`
- Плюс релевантные тесты изменённого модуля.

### 6.2 Контроль инвариантов
- Каждому архитектурному дефекту соответствует отдельный регрессионный тест (или gate), который падает до фикса и проходит после.
- Для save/load/resume и RNG обязательны детерминизм-проверки (snapshot/replay/property-style при необходимости).

### 6.3 Release проверки
- Hard-contract проверка:
  - `bash .github/ci/run_release_check.sh TestResults/QualityDashboard CardSampleGame`
  - Требует clean tree (`--require-clean-tree`).
- Snapshot-проверка текущего рабочего среза:
  - `bash .github/ci/run_release_check_snapshot.sh TestResults/QualityDashboard CardSampleGame`

### 6.4 Синхронизация документации
- При изменении gate-контрактов обязательно обновить:
  - `Docs/QA/QUALITY_CONTROL_MODEL.md`
  - `Docs/QA/TESTING_GUIDE.md`
  - `TestResults/QualityDashboard/gate_inventory.json`

---

## 7) Структура проекта и Xcode

- Группы в Xcode должны отражать файловую структуру на диске.
- Новые файлы добавляются в правильные модульные зоны (`App`, `Views`, `ViewModels`, `Packages/*`), без «свалок» в root.
- Любая крупная декомпозиция сопровождается переносом файлов и обновлением project structure gate.
- Документация и контракты для модулей обновляются одновременно с переносом.

---

## 8) Definition of Done для фичи/рефакторинга

1. Зафиксирован инвариант, который не должен ломаться.
2. Изменения внесены только в разрешённых слоях.
3. Добавлен/обновлён регрессионный тест под конкретный риск.
4. Прогнаны релевантные gate-тесты и модульные тесты.
5. Обновлены `CLAUDE.md`/`Docs/**` при изменении контракта.
6. Нет новых нарушений hygiene, localization, determinism.

---

## 9) Запрещённые паттерны (быстрый список)

- Прямые присваивания engine-критичных полей из App/Views.
- Доступ из App/Views к `engine.services.rng` / `WorldRNG.shared`.
- Любой системный RNG в gameplay (`Int.random`, `UInt64.random`, `UUID()` как источник случайности).
- `.invalidAction(reason: "raw string")` в engine.
- Импорт `TwilightEngineDevTools` в production.
- `Text(...icon token...)` вместо `Image(systemName:)`.
- Коммит arena-результата в main world-engine.
- Оставление мёртвого кода и временных костылей без плана удаления.

---

## 10) Полезные команды

- TwilightEngine tests:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --package-path Packages/TwilightEngine`
- Targeted app architecture gate:
  - `bash .github/ci/run_xcodebuild.sh test -scheme CardSampleGame -destination "$(bash .github/ci/select_ios_destination.sh --scheme CardSampleGame)" -only-testing:CardSampleGameTests/AuditArchitectureBoundaryGateTests`
- Snapshot release check:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash .github/ci/run_release_check_snapshot.sh TestResults/QualityDashboard CardSampleGame`
