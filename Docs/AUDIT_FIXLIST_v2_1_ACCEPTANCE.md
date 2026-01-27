# AUDIT_FIXLIST_v2_1_ACCEPTANCE.md
## Stop-the-line задачи для принятия стадии (Stage Acceptance)

**Цель:** принять текущую стадию как фундамент (Engine-first + packs + deterministic + tests-as-judge).
**Правило:** никаких временных решений. Если компонент нарушает архитектуру — его **удаляем** или **переписываем** до соответствия.

---

# 0) Итог комиссии
Текущая стадия **не может быть принята**, пока не закрыты блокеры ниже.
Причина: часть “gate tests” может давать ложнозелёный результат (skip/не те пути), а в Engine остаются признаки “двойной истины”.

---

# 1) BLOCKERS (Critical, Stop-the-line)

## 1.1 Gate tests НЕ имеют права skip’аться
**Проблема:** в `CardSampleGameTests/Engine/*` встречается `XCTSkip(...)`.
**Почему критично:** тесты должны быть судьёй; skip = ложнозелёный прогон.

### Требования
- Удалить `XCTSkip` из gate/contract тестов полностью.
- Любая невозможность проверить условие = `XCTFail` (и падение CI).
- Обновить все “file path” проверки на реальные пути (Swift Package / текущая структура проекта).
- Ввести один `SourcePathResolver` (helper) для путей в тестах, чтобы не дублировать строки.

### Acceptance
- Поиск по тестам: **0** вхождений `XCTSkip`.
- Gate suite падает, если файл не найден или проверка невозможна.

---

## 1.2 Engine не должен содержать game-specific IDs/словари конкретной игры
**Проблема:** в Engine встречаются `"village"`, `"forest"`, `"swamp"`, и пр.
**Почему критично:** ломает DLC/паковую модель и делает движок не переиспользуемым.

### Требования
- Удалить любые упоминания конкретных ID/типов из `Engine/` и `Packages/TwilightEngine/...`.
- Entry point (startRegionId и т.п.) должен приходить **только** из manifest.
- Любая логика отображения (иконка/цвет/тема) должна приходить из definitions (pack), не из switch/case по id.

### Acceptance
- Static scan test: `testEngineContainsNoGameSpecificIds()` (скан `Engine/` на запрещённые строки).
- Добавление нового региона “ice_cave” возможно без изменения Engine кода.

---

## 1.3 Запрет системного RNG в Engine core/runtime path
**Проблема:** `randomElement()`, `.shuffled()`, `Double.random`, `Int.random` в Engine путях.
**Почему критично:** ломает детерминизм, regression, CI.

### Требования
- Полный запрет системного RNG в Engine/Core, PackLoader, EventPipeline, Market generation.
- Вся случайность только через deterministic RNG (seeded).
- Любой “альтернативный движок” с системным RNG (например `CoreGameEngine.swift`) — **удалить**.

### Acceptance
- Static scan test: `testNoSystemRandomInEngineCore()` падает при наличии запрещённых вызовов.
- Regression tests стабильно проходят без флака.

---

## 1.4 Stable IDs: запрещены UUID и fallback на uuidString для контента
**Проблема:** `definitionId` опционален + fallback `uuidString` в save.
**Почему критично:** сейвы и DLC несовместимы.

### Требования
- `definitionId` обязателен (non-optional) для всех pack-driven сущностей: region/anchor/event/quest/card/enemy/hero.
- Удалить любые fallback на `uuidString` в EngineSave.
- InstanceId допускается только отдельно и никогда не используется как ссылка на definition.

### Acceptance
- Тест: `testSaveLoadUsesStableDefinitionIdsOnly()` (сейв не содержит uuidString и UUID для definitions).
- Gate: `testDefinitionIdNeverNilForPackEntities()`.

---

## 1.5 RNG state должен сохраняться и восстанавливаться через Save/Load
**Проблема:** в save есть rngSeed/state, но он не выставляется/не используется.
**Почему критично:** игра не репродуцируема после загрузки.

### Требования
- Save хранит RNG state (seed + позиция/состояние генератора) **или** (для FateDeck) полное состояние draw/discard/sticky.
- Load восстанавливает RNG/FateDeck state до продолжения игры.

### Acceptance
- Тест: `testSaveLoadRestoresRngState()` и/или `testFateDeckRoundTrip()`.

---

# 2) UI / Presentation Safety (High)

## 2.1 Legacy Comments / закомментированный старый код в WorldMapView — удалить
**Проблема:** в `WorldMapView.swift` остаются закомментированные куски “Legacy initialization”.
**Почему важно:** засоряет код и провоцирует возвращение legacy путей.

### Требования
- Полностью удалить legacy-комментарии и закомментированный код.
- Оставить только актуальный Engine-first flow.

### Acceptance
- Gate scan: `testNoLegacyInitializationCommentsInWorldMapView()`.

---

## 2.2 Asset Fallback: SafeImage должен использоваться везде
**Проблема:** есть `SafeImage.swift`, но местами (например previews) встречается `Image("name")`.
**Почему важно:** отсутствие ассета в паке → пустота/розовый квадрат.

### Требования
- Запрет прямого `Image("...")` для pack-driven ассетов в Views/ViewModels.
- Использовать `SafeImage`/`AssetRegistry` везде, включая previews.
- Placeholder ассет `unknown_region` обязателен.

### Acceptance
- Тест: `testMissingAssetHandling_returnsPlaceholder()`.
- Gate scan: `testNoDirectImageNamedInViews()`.

---

# 3) Content Validation (High)

## 3.1 Expression conditions: валидировать не только JSON синтаксис, но и логику условий
**Проблема:** опечатка `"WorldResonanse < -50"` может пройти в JSON и условие никогда не сработает.
**Почему важно:** тихий дефект контента, не ловится до игроков.

### Требования
- В движке должен быть строгий `ExpressionParser` (whitelist переменных/функций).
- ContentValidator обязан парсить все `condition` во всех загруженных pack’ах.
- Любая неизвестная переменная/функция → `ContentError.invalidExpression` (hard fail).

### Acceptance
- `ExpressionParserTests.swift`:
  - `testRejectsUnknownVariables()` (WorldResonanse)
  - `testRejectsUnknownFunctions()`
  - `testRejectsInvalidSyntax()`
- Интеграционный тест: `testAllPackConditionsAreValid()`.

---

# 4) Pack System Clarity (High)

## 4.1 Локализация: закрепить один канон и запретить гибрид
**Требование**
- Выбран один подход к локализации (например inline LocalizedString ru/en).
- Validator запрещает смешивание схем (stringKey vs raw strings vs tables).

**Acceptance**
- `testNoMixedLocalizationSchema()`.

---

## 4.2 Binary pack (Phase N) — фиксируем как обязательное требование
**Требование**
- Пока runtime работает на JSON — честно фиксируем это как текущую фазу.
- Реализовать CLI pack compiler (`packc/json2pack`) и перевести runtime на `.pack` как обязательный этап.

**Acceptance**
- `testPackCompilerRoundTrip()` (когда pack compiler появится).

---

# 5) Code hygiene (Medium)

## 5.1 Swift Doc Comments для public API Engine
**Требование**
- Все public методы Engine и ContentLoader/ContentRegistry документированы (///).

## 5.2 SwiftLint
**Требование**
- Добавить `.swiftlint.yml` с запретом `force_cast`, `force_try`, лимиты на complexity/length.

---

# 6) Definition of Done (Stage Acceptance)
Стадия принята, если:
- Все пункты раздела **1) BLOCKERS** закрыты и подтверждены тестами.
- UI не содержит legacy закомментированного кода.
- SafeImage используется во всех местах.
- ExpressionParser валидирует conditions во всех pack’ах.
- Gate tests не skip’аются и реально падают при нарушениях.
