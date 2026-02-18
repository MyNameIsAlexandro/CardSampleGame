# Disposition Combat System — Design Document (v2.1)

> **Статус:** DRAFT v2.5 — v2.4 + auditor response matrix, готов к финальному review
> **Дата:** 2026-02-18
> **Контекст:** Полная переработка боевой системы Ritual Combat → Disposition Combat

---

## 1. North Star

### 1.1 Core Intent

Бой — это контекстная задача, не оптимизационная формула.

Игрок не ищет "лучшую карту" и не запоминает "правильную последовательность". Каждое взаимодействие — решение под давлением: ограниченная рука, незнакомый враг, меняющийся контекст. Победа — это момент, когда игрок нашёл выход из сложной ситуации, а не когда он применил выученную стратегию.

### 1.2 Признаки успеха дизайна

- Игрок обсуждает **"как он выиграл"**, а не "какая карта сильнее"
- В двух боях с одним врагом решения различаются
- Стиль героя (Навь/Правь/Явь) меняет **смысл** победы, а не только числа
- Проигрыш ощущается как "я мог иначе", а не "мне не повезло"
- Игроки делятся историями, а не гайдами

### 1.3 Context > Calculation

Игрок **не должен иметь полной информации**:
- Враг телеграфирует намерения, но не раскрывает точные числа
- Fate deck добавляет непредсказуемость к каждому действию
- Resonance меняет правила между encounter'ами

Решение должно ощущаться как **осознанный риск**, а не как математический расчёт.

### 1.4 Player-Facing vs Engine-Internal

Система содержит 10+ взаимодействующих механик, но **игрок не должен их считать**. Чёткое разделение: что видит игрок, а что скрыто в engine.

#### Игрок видит (3 решения + 2 подсказки)

| Элемент | Что показывает UI | Как игрок это воспринимает |
|---------|-------------------|--------------------------|
| **Drag zones** | 3 зоны с подсветкой | "Куда тащить карту?" — основное решение |
| **Enemy telegraph** | Иконка + режим (аура) | "Что он сделает?" — контекст решения |
| **Fate keyword** | Название + краткий эффект | "Мне повезло / не повезло" — сюрприз |
| **Disposition bar** | Градиент с позицией | "Я ближе к победе или проигрышу?" |
| **Energy counter** | Число | "Сколько карт ещё могу сыграть?" |

#### Игрок чувствует, но не считает

| Механика | Как проявляется в UI | Игрок думает |
|----------|---------------------|-------------|
| Momentum | Число рядом с streak растёт, аура усиливается | "Мои удары всё сильнее" |
| Switch penalty | Итоговый урон падает при переключении | "Переключился — стало слабее" |
| Resonance | Цветовая палитра сцены + подсказка при drag | "В этой локации бить больнее" |
| Vulnerabilities | Итоговый урон выше/ниже обычного + иконка | "Этот враг уязвим к дипломатии тут" |
| Affinity | Стартовая позиция на disposition bar | "Он враждебен с порога" |

#### Engine-internal (скрыто от игрока)

| Механика | Почему скрыта |
|----------|--------------|
| Формула effective_power | Игрок видит результат, не формулу |
| Threat bonus | Проявляется как повышенный урон — причину не нужно знать |
| Enemy deck weights | Игрок видит telegraph, не вероятности |
| Fate base modifier (-1…+1) | Поглощён keyword-эффектом |
| Sacrifice enemy buff | Враг "выглядит злее" — анимация, не число |

**Принцип:** UI показывает **результат и подсказку к решению**, а не формулу. Игрок принимает решение по ощущениям и контексту, не по расчёту.

---

## 2. Player Experience Goals

### 2.1 Что должен чувствовать игрок

| Момент | Ощущение |
|--------|----------|
| Начало боя | "Так, что у меня в руке и кто передо мной?" — оценка ситуации |
| Первый ход | "Попробую так..." — гипотеза |
| Враг отвечает | "Ого, он защитился / ударил в ответ" — враг живой |
| Середина боя | "Мне сменить стратегию или дожать?" — дилемма |
| Sacrifice | "Я жертвую сильную карту ради шанса..." — риск |
| Победа | "Я нашёл выход!" — гордость |
| Поражение | "Надо было иначе..." — не обида, а понимание |

### 2.2 Чего НЕ должен чувствовать

- "Опять этот бой, тот же порядок карт" — скука
- "Эта карта всегда лучше" — доминантная стратегия
- "Нет смысла пробовать дипломатию" — мёртвая ветка
- "Sacrifice на первом ходу — обязательно" — принудительный ритуал

---

## 3. Core Loop — Disposition Track

### 3.1 Шкала

```
-100 ←————————— 0 ——————————→ +100
 УНИЧТОЖЕН     НЕЙТРАЛЕН      ПОДЧИНЁН
```

Каждый край — победа, но **с разной ценой и разными последствиями**.

### 3.2 Цена за край

| Край | Последствие | Награда | Долгосрочный эффект |
|------|------------|---------|-------------------|
| **-100 (уничтожен)** | Враг покидает мир навсегда | Loot, ресурсы | Resonance сдвигается к тьме; фракция врага враждебнее |
| **+100 (подчинён)** | Враг остаётся в мире | Информация, союзник, торговля | Resonance сдвигается к свету; но подчинение не забывается |

- **Уничтожение** проще тактически, но закрывает будущие возможности
- **Подчинение** сложнее, но открывает нарратив
- Способ подчинения (дружба / обман / запугивание) влияет на качество связи — обманутый враг может предать позже

### 3.3 Поражение (HP = 0) — Failure with Meaning

Поражение — не просто "game over, попробуй снова". Провал меняет мир:

- **Изменение позиции**: герой отброшен, теряет территорию или ресурсы
- **Новые последствия**: враг усиливается, призывает подкрепление, занимает локацию
- **Сдвиг resonance**: провал в бою с нечистью усиливает тьму
- **Нарративная развилка**: поражение открывает альтернативный путь ("ты пленён" / "тебя спасли")

Игрок не ищет "безопасный путь" — потому что безопасного пути нет.

### 3.4 Стартовая Disposition — Affinity Matrix

Стартовое значение = `affinityMatrix[heroWorld][enemyType] + situationModifier`

| Враг \ Герой | Навь | Явь | Правь |
|-------------|------|-----|-------|
| Нечисть     | +30  |  0  | -40   |
| Человек     | -10  | +20 | +10   |
| Дух Прави   | -40  | -10 | +30   |
| Зверь       | +10  | +10 |   0   |

- Матрица хранится в content pack (data-driven, не в engine коде)
- `situationModifier`: предыдущие взаимодействия, мировые флаги, квестовый контекст
- Для героя Нави нечисть начинает почти дружелюбной — убивать "своих" стоит дороже морально (resonance shift)
- Для героя Прави та же нечисть враждебна с порога — дипломатия требует больше усилий

---

## 4. Card Play — 3 режима через drag

### 4.1 Структура карты

```swift
Card {
    id: String
    name: String
    type: CardType
    description: String
    strikePower: Int      // урон к disposition (→ -100)
    influencePower: Int   // влияние к disposition (→ +100)
    cost: Int             // стоимость в энергии
}
```

Герой определяется колодой, не числовыми статами. Воин — колода с высоким strikePower. Дипломат — с высоким influencePower. Но **каждая карта** может быть сыграна любым способом.

### 4.2 Режимы розыгрыша

| Действие | Жест | Эффект | Карта после |
|----------|------|--------|-------------|
| **Strike** | Drag → на врага | disposition -= effective_power | Discard |
| **Influence** | Drag → на алтарь | disposition += effective_power | Discard |
| **Sacrifice** | Drag → на костёр | см. раздел 6 | Exhaust (навсегда) |

- Розыгрыш мгновенный: drag → drop → эффект → анимация
- Пока есть энергия — можно продолжать
- End Turn когда готов

### 4.3 Энергия

- Начало хода: N энергии (определяется колодой/прогрессией)
- Каждая карта стоит `cost` энергии
- Ход заканчивается: End Turn или энергия = 0

---

## 5. Context Systems

### 5.1 Momentum — инерция стратегии

#### State (детерминистичный, сохраняется в snapshot)

```
streakType: ActionType?     // .strike | .influence | nil
streakCount: Int            // подряд одного типа
lastActionType: ActionType? // для threat bonus
```

#### Формула

```
streak_bonus    = max(0, streakCount - 1)
threat_bonus    = 2 if (lastAction == .strike AND current == .influence) else 0
switch_penalty  = max(0, streakCount - 2) if (switching AND streakCount >= 3) else 0

surged_base     = fate.keyword == .surge ? (base_power * 3 / 2) : base_power
fate_modifier   = fateCard.baseModifier + fateCard.keyword.contextEffect(disposition)
raw_power       = surged_base + streak_bonus + threat_bonus - switch_penalty + fate_modifier
effective_power = min(raw_power, 25)   // hard cap: ни одно действие не сдвигает шкалу больше чем на 25
```

#### Почему это работает

Momentum создаёт **дилемму продолжения**: каждый ход одного типа сильнее предыдущего, но делает переключение дороже. Игрок постоянно решает: "дожать или сменить подход?"

### 5.2 Resonance — контекст меняет правила

Resonance — не декоративный фон. Это **модификатор правил**, зависящий от локации и мирового состояния.

| Зона Resonance | Strike | Influence | Sacrifice |
|---------------|--------|-----------|-----------|
| **Навь** (тьма) | +2 бонус, но враг получает +1 ATK | -1 штраф | На 1 энергию дешевле |
| **Правь** (свет) | Backlash: герой теряет 1 HP за Strike | +2 бонус | Рискован: может exhaust 2 карты |
| **Явь** (баланс) | Нейтрально | Нейтрально | Нейтрально |

Это значит:
- В тёмной локации бить выгоднее, но враг бьёт больнее — **агрессия рискованна**
- В светлой локации Strike наказывает героя — **дипломатия оправдана**
- Resonance сдвигается по ходу игры, меняя тактику между encounter'ами
- Одна и та же колода требует разных решений в разных локациях

### 5.3 Fate Deck — ключевые слова, не числа

После Strike/Influence тянется карта судьбы **внутри engine action** (engine-owned RNG). Детерминистична при одном seed.

#### Fate Keywords

Каждая Fate-карта несёт **keyword** + базовый modifier (-1…+1). Keyword определяет контекстный эффект:

| Keyword | Базовый эффект | При disposition < -30 | При disposition > +30 |
|---------|---------------|----------------------|----------------------|
| **Surge** | +50% к base_power (округление вниз) | То же (+50% base_power) | То же (+50% base_power) |
| **Shadow** | -1 к текущему действию | switch_penalty += 2 (тьма сковывает) | Враг теряет Defend на следующий ход |
| **Ward** | 0 | Backlash от Resonance отменяется | Backlash от Resonance отменяется |
| **Focus** | +1 к текущему действию | Ignore enemy Defend | Ignore enemy Provoke |
| **Echo** | 0 | Повтор предыдущего действия бесплатно (0 energy). **Не срабатывает сразу после Sacrifice** | Повтор предыдущего действия бесплатно (0 energy). **Не срабатывает сразу после Sacrifice** |

#### Fate Deck Composition (MVP)

```
Surge  x4
Shadow x3
Ward   x3
Focus  x3
Echo   x2
```

15 карт, перемешивание при старте боя через engine RNG. Когда колода пуста — reshuffle.

#### Почему это работает

- **Числовой modifier мал** (-1…+1) — Fate не перекрывает решения игрока
- **Surge ограничен base_power** — не умножает bonus'ы, чтобы не создавать swingy последние ходы. При base=3: surged=4 (управляемо), а не base+streak x2 (неконтролируемо)
- **Echo блокируется после Sacrifice** — нельзя получить "sacrifice → influence → echo → influence" combo. Жертва "загрязняет" эхо
- **Keywords создают уникальные моменты**: Echo позволяет сыграть бесплатный дубль, Focus пробивает защиту, Ward спасает от backlash
- **Disposition-зависимость**: одна и та же карта работает по-разному в начале и конце боя
- **Непредсказуемость, но не рандом**: игрок знает состав колоды и может считать, что осталось
- **Hard cap = 25**: ни одно действие не может сдвинуть disposition больше чем на четверть шкалы, независимо от комбинации модификаторов

#### Echo — самый опасный keyword (safety note)

Echo копирует предыдущее действие бесплатно. Это создаёт наибольший мета-потенциал:
- Echo после сильного Strike/Influence удваивает эффект хода
- Echo НЕ тянет новую Fate-карту (повтор = тот же fate_modifier)
- Echo НЕ сбрасывает streak (повтор = streak продолжается)

**Ограничения (уже в дизайне):**
- Echo не срабатывает после Sacrifice
- Всего 2 Echo в deck из 15 (13%)
- Hard cap 25 ограничивает даже удвоенные ходы

**Мониторинг при балансе:** если в stress-тестах Echo-ходы составляют >30% от disposition shift — уменьшить до 1 Echo в deck

---

## 6. Resource Tension — Sacrifice

### 6.1 Проблема

Если Sacrifice = просто "+1 энергия", он станет обязательным оптимальным действием или полностью бесполезным. Sacrifice должен быть **решением под давлением**.

### 6.2 Механика

| Параметр | Значение |
|----------|---------|
| Эффект | +1 энергия |
| Стоимость | Карта уходит из боя **навсегда** (exhaust) |
| Ограничение | **1 sacrifice за ход** |
| Побочный эффект | Враг получает +1 к следующему действию (жертва показывает отчаяние) |
| Resonance эффект | Sacrifice в Нави — дешевле (тьма питается жертвой). В Прави — рискован (может exhaust ещё 1 случайную карту) |

### 6.3 Почему это работает

- **Ограничение 1/ход** — нельзя спамить
- **Усиление врага** — жертва имеет тактическую цену, а не только ресурсную
- **Потеря карты навсегда** — уменьшает опции в долгосрочной перспективе
- **Контекст resonance** — в одной локации sacrifice выгоден, в другой опасен

Sacrifice — это "я в отчаянии и готов заплатить", а не "оптимальный первый ход".

---

## 7. Enemy as Dynamic System

### 7.1 Враг — не мешок HP

Враг — это **задача с адаптацией**. Он играет картами из своей мини-колоды (3-6 action cards, определяются content pack). У каждого врага есть **уязвимости и резистенции**, создающие системную асимметрию.

### 7.2 Системная асимметрия (Anti-Meta)

Каждый тип врага реагирует на действия игрока **по-разному**, и эта реакция **зависит от Resonance зоны**.

#### Базовые уязвимости (без resonance)

| Враг | Strike | Influence | Sacrifice |
|------|--------|-----------|-----------|
| **Бандит** | Нейтрально | Слабость: -2 к resist | Провоцирует: +2 ATK |
| **Дух** | Резист: -3 к урону | Нейтрально | Слабость: дух ослабевает |
| **Зверь** | Слабость: +2 бонус | Резист: -3 к influence | Нейтрально |
| **Торговец** | Провоцирует: вызывает стражу | Слабость: -2 к resist | Нейтрально |
| **Нежить** | Нейтрально | Резист: не чувствует эмоций | Слабость: жертва разрушает |

#### Resonance модифицирует уязвимости

| Враг | В Нави | В Яви | В Прави |
|------|--------|-------|---------|
| **Дух** | Sacrifice слабость **активна** (тьма ослабляет духов) | Sacrifice нейтрально | Sacrifice слабость → **резист** (свет защищает духов) |
| **Зверь** | Strike слабость **отключена** (звери в тьме осторожны) | Strike слабость **активна** | Strike слабость **усилена** (+3 вместо +2) |
| **Нежить** | Sacrifice слабость **усилена** | Нейтрально | Influence резист **отключён** (свет пробуждает эмоции) |
| **Бандит** | Influence слабость **отключена** (в тьме не торгуются) | Influence слабость **активна** | Influence слабость **усилена** |
| **Торговец** | Strike провокация **отключена** (нет стражи в тьме) | Strike провокация **активна** | Strike провокация **усилена** (двойная стража) |

**Это означает:** "дух слаб к sacrifice" — правда только в Нави. В Прави тот же дух **резистентен** к sacrifice. Нельзя запомнить одну таблицу — контекст локации меняет оптимальную стратегию.

Уязвимости хранятся в content pack как `EnemyVulnerabilityDefinition` с полем `resonanceOverrides`.

### 7.3 Enemy Modes — поведение меняется, не только числа

Disposition — не линейная шкала. При критических пороговых значениях враг **переключает режим**.

#### Динамические пороги (anti-meta)

Пороги **не фиксированы** — определяются seed при старте боя:

```
survivalThreshold  = -(65 + seed_hash % 11)    // от -65 до -75
desperationThreshold = 65 + seed_hash % 11       // от +65 до +75
```

Игрок знает, что режим переключится "где-то около ±70", но не знает точно где. Это исключает мету "держи на 64".

#### Hysteresis — режим держится

Когда режим активируется, он **держится минимум 1 ход** после выхода за порог. Враг не "мерцает" между режимами — он переходит и задерживается.

#### Режимы

| Условие | Режим | Что меняется |
|---------|-------|-------------|
| disposition ≤ survivalThreshold | **Survival** | Враг в ярости: все действия = Attack/Rage. Наносит двойной урон, но каждый Strike игрока получает +3 бонус (враг раскрывается) |
| disposition ≥ desperationThreshold | **Desperation** | Враг паникует: ATK x2, но Defend отключается. Provoke усиливается — отчаянно сопротивляется подчинению |
| disposition качается ±30 за ход | **Weakened** | Враг дезориентирован: выбирает **слабейшее** действие из своей колоды. Telegraph показывает "?" — намерение скрыто. Игрок награждён за тактическую гибкость |
| остальное | **Normal** | Стандартное поведение по deck weights |

**Почему это работает**:
- При приближении к победе бой **усложняется, а не упрощается**. Последние ~30 пунктов — самые опасные
- Динамические пороги исключают "оптимальное расстояние" — нельзя точно рассчитать безопасную зону
- Hysteresis делает переход драматичным: враг переключился — он в этом режиме минимум на ход
- Weakened — награда, не хаос: игрок видит "?" (интрига), но знает, что враг ослаблен

### 7.4 Типы вражеских действий

| Действие | Эффект | Когда используется |
|----------|--------|-------------------|
| **Attack** | Урон по HP героя | По умолчанию |
| **Defend** | Снижает следующий Strike игрока | При disposition < -50 |
| **Provoke** | Штраф к Influence в этом ходу | При disposition > +30 |
| **Adapt** | Блокирует тип действия с наибольшим streak | При streak >= 3 |
| **Rage** | ATK x2, но disposition сдвигается на +5 (ошибка врага) | Только в Survival mode |
| **Plea** | Disposition +10 (враг молит), но если игрок продолжает Strike — backlash -5 HP | Только в Desperation mode |

### 7.5 Enemy "читает" momentum

Ключевая механика: **враг наказывает повторение**.

- streak >= 3 Strike → враг переходит в Defend + Adapt
- streak >= 3 Influence → враг Provoke — штрафует дипломатию
- Частый Sacrifice → враг усиливает Attack — наказывает за потерю руки

Это делает бой **задачей на чтение врага**, а не перетягиванием шкалы.

### 7.6 AI (MVP — rule-based с modes)

```
# Thresholds (computed once at combat start from seed)
survivalThreshold  = -(65 + seed_hash % 11)
desperationThreshold = 65 + seed_hash % 11

# Mode selection (with hysteresis: mode holds 1 turn after leaving threshold)
if disposition <= survivalThreshold OR (prev_mode == SURVIVAL AND hysteresis_turns > 0):
    mode = SURVIVAL
elif disposition >= desperationThreshold OR (prev_mode == DESPERATION AND hysteresis_turns > 0):
    mode = DESPERATION
elif abs(disposition_delta_this_turn) > 30:
    mode = WEAKENED
else:
    mode = NORMAL

# Action selection per mode
SURVIVAL:    Attack(60%) | Rage(30%) | Attack(10%)
DESPERATION: Provoke(40%) | Plea(30%) | Attack(30%)
WEAKENED:    select action with lowest weight from deck  // reward, not chaos
NORMAL:
  if player_streak >= 3: Adapt(50%) | counter_action(50%)
  elif disposition < -50: Defend(60%) | Attack(40%)
  elif disposition > +30: Provoke(50%) | Attack(50%)
  else: Attack(80%) | random(20%)
```

Weights определяются в `EnemyActionDefinition`. Resolve через engine RNG (детерминистично).

### 7.7 Телеграфирование

Враг **показывает следующее действие** перед ходом игрока (как в Slay the Spire):
- Иконка + число над врагом: "ATK 5" или "DEF" или "!"
- **Mode** визуально заметен: Survival = красная аура, Desperation = синяя дрожь, Weakened = мерцание + "?" вместо intent
- Игрок видит намерение и режим, но не знает точное значение
- Создаёт осознанный выбор: "он в Survival, значит будет бить сильнее — готов ли я?"

### 7.8 Visual Communication Contract

Враг имеет 6+ нелинейных переключателей. Игрок не видит формулы, но **чувствует** переходы. Если переход не коммуницирован визуально — он воспринимается как хаос.

**Обязательные требования к переходам режимов:**

| Переход | Визуал | Длительность | Звук |
|---------|--------|-------------|------|
| Normal → Survival | Красная вспышка + аура пульсирует | 0.5s transition | Рычание / удар |
| Normal → Desperation | Синяя дрожь + враг отшатывается | 0.5s transition | Крик / стон |
| Any → Weakened | Мерцание + "?" над головой | 0.3s transition | Звон / дезориентация |
| Mode → Normal | Аура гаснет плавно | 0.8s fade | Тишина |

**Принципы:**
- Переход **всегда** имеет анимацию — нет мгновенных скачков
- Текущий режим виден постоянно (аура/эффект), не только в момент перехода
- Hysteresis визуально подтверждён: аура мигает перед окончанием, давая игроку 1 ход подготовки
- При первом появлении режима в сессии — короткая tooltip-подсказка ("Враг в ярости — его атаки удвоены, но он раскрыт")

---

## 8. Anti-Meta Design Principles

### 8.1 Как система наказывает повторение одной стратегии?

| Механизм | Как он ломает единую стратегию |
|----------|-------------------------------|
| **Enemy adaptation** | Враг "читает" streak и контрит повторяющийся подход |
| **Momentum switch penalty** | Переиспользование одного подхода делает переключение дорогим |
| **Sacrifice side effect** | Усиливает врага — нельзя бездумно конвертировать карты |
| **Resonance zones** | Меняет эффективность действий между локациями — одна тактика не работает везде |
| **Limited hand** | Ограниченность руки исключает универсальное комбо |
| **Affinity matrix** | Разные герои в разных стартовых позициях — нет "лучшего героя для всех" |
| **Fate deck** | Непредсказуемый модификатор не позволяет точно рассчитать исход |

### 8.2 Proof of Variety

Для одного и того же encounter'а (враг: бандит, disposition 0) три героя имеют разный опыт:

**Герой Нави** (нечисть: +30, человек: -10):
- Бандит-человек начинает на -10. Убить проще, чем убедить.
- Но в локации Нави Strike даёт backlash. Дилемма.

**Герой Яви** (человек: +20):
- Бандит начинает на +20. Дипломатия близка.
- Но бандит Provoke-heavy — будет мешать переговорам.

**Герой Прави** (человек: +10):
- Бандит нейтрален. Обе стратегии жизнеспособны.
- Но в локации Прави Strike стоит HP. Агрессия дорогая.

---

## 9. UI Layout (390x700 SpriteKit)

```
+-----------------------------+
|       Enemy Idol(s)         |  <- Drop zone: Strike
|  [-100 ######...... +100]   |  <- Disposition bar
|     [intent: ATK 5]         |  <- Enemy telegraph
|                             |
|       Altar of Word          |  <- Drop zone: Influence
|                             |
|         Bonfire              |  <- Drop zone: Sacrifice
|                             |
|   [C1] [C2] [C3] [C4] [C5] |  <- Hand (fan)
|  E:3/5  Streak:x2  [End]   |  <- Energy + Momentum + End Turn
+-----------------------------+
```

### 9.1 Visual Feedback

- Drag к врагу: красная подсветка, trail огня
- Drag к алтарю: синяя/золотая подсветка, trail света
- Drag к костру: оранжевая подсветка, trail пепла
- Disposition bar: градиент красный (-100) → серый (0) → синий (+100)
- Momentum: аура вокруг руки нарастает с streak
- Enemy telegraph: иконка над врагом показывает следующее действие

### 9.2 Зоны drag-drop

- **Enemy zone** (верхняя треть): drop = Strike
- **Altar zone** (центр): drop = Influence
- **Bonfire zone** (у центра): drop = Sacrifice
- **Hand zone** (нижняя четверть): возврат карты

### 9.3 Живое поле

- Фон сцены отражает локацию encounter'а
- Resonance zone влияет на цветовую палитру и частицы
- Навь: тёмные тона, фиолетовый туман. Правь: золотое свечение. Явь: нейтральные тона.

---

## 10. Testing Philosophy

### 10.1 Что тестируем

Не "работает ли механика", а **"порождает ли система разнообразие"**:

- Детерминизм: один seed → идентичный результат (воспроизводимость)
- Антимета: при одних и тех же картах разный контекст (resonance, affinity) → разные оптимальные решения
- Провал со смыслом: поражение меняет state, а не просто перезапускает encounter
- Enemy adaptation: враг контрит streak >= 3

### 10.2 Gate-тесты

| Тест | Инвариант |
|------|-----------|
| `testDispositionDeterminism` | 100 боёв с одним seed → идентичный результат |
| `testMomentumStreak_resetsOnSwitch` | streak обнуляется при смене типа |
| `testMomentumStreak_preservedAcrossTurns` | streak живёт между ходами |
| `testThreatBonus_afterStrike` | +2 к Influence после Strike |
| `testSwitchPenalty_longStreak` | штраф при streak >= 3 |
| `testAffinityMatrix_startDisposition` | стартовая disposition верна по матрице |
| `testResonanceZone_modifiesEffectiveness` | Навь/Правь/Явь дают разные модификаторы |
| `testSacrifice_limitOnePerTurn` | нельзя sacrifice дважды за ход |
| `testSacrifice_strengthensEnemy` | враг получает +1 после sacrifice |
| `testEnemyAdapt_countersStreak` | враг меняет стратегию при streak >= 3 |
| `testDispositionTransaction_engineOwns` | App/Views не мутируют disposition |
| `testFateDraw_insideEngineAction` | fate draw через engine RNG |
| `testSaveRestore_dispositionState` | save/load сохраняет disposition + streak |
| `testArena_doesNotCommitDisposition` | arena не коммитит в world state |
| `testDefeatChangesWorldState` | поражение меняет resonance / enemy state |
| `testEnemyMode_survivalAtDynamicThreshold` | disposition ≤ survivalThreshold → SURVIVAL; порог в диапазоне -65…-75 |
| `testEnemyMode_desperationAtDynamicThreshold` | disposition ≥ desperationThreshold → DESPERATION; порог в диапазоне +65…+75 |
| `testEnemyMode_thresholdDeterministic` | один seed → идентичные пороги survivalThreshold и desperationThreshold |
| `testEnemyMode_hysteresis` | после выхода за порог режим держится минимум 1 ход |
| `testEnemyMode_weakenedOnSwing` | ±30 за ход → WEAKENED, враг выбирает слабейшее действие |
| `testEnemyMode_weakenedNotRandom` | WEAKENED → действие с наименьшим weight, не uniform random |
| `testSystemicAsymmetry_vulnerabilities` | каждый тип врага имеет уязвимость хотя бы к одному типу действия |
| `testSystemicAsymmetry_resistances` | каждый тип врага имеет резистенцию хотя бы к одному типу действия |
| `testSystemicAsymmetry_resonanceChangesVulnerability` | одна и та же уязвимость отличается в Nav/Yav/Prav |
| `testSystemicAsymmetry_noAbsoluteVulnerability` | ни один враг не уязвим к одному типу во всех трёх resonance зонах одинаково |
| `testSurge_onlyAffectsBasePower` | Surge: base_power × 1.5 (только base, не умножает streak/threat). См. §5.1 формулу |
| `testFateKeyword_echoFreeCopy` | Echo → повтор предыдущего действия с 0 energy cost |
| `testFateKeyword_focusIgnoresDefend` | Focus при disposition < -30 → ignore enemy Defend |
| `testFateKeyword_wardCancelsBacklash` | Ward → отменяет resonance backlash |
| `testFateKeyword_shadowIncreasePenalty` | Shadow при disposition < -30 → switch_penalty += 2 |
| `testFateDeck_reshuffleWhenEmpty` | пустая fate deck → reshuffle, бой продолжается |
| `testFateDeck_deterministicShuffle` | один seed → идентичный порядок fate cards |
| `testEnemyRage_doubleATKplusDispositionShift` | Rage: ATK x2, disposition += 5 |
| `testEnemyPlea_dispositionPlusBacklash` | Plea: disposition +10, Strike после Plea → -5 HP герою |
| `testEffectivePower_hardCap25` | effective_power никогда не превышает 25 при любой комбинации модификаторов |
| `testSurge_onlyAffectsBasePower` | Surge: base_power * 1.5, streak/threat/switch bonus'ы не затронуты |
| `testEcho_blockedAfterSacrifice` | Echo не срабатывает, если предыдущее действие = Sacrifice |
| `testEcho_worksAfterStrikeOrInfluence` | Echo срабатывает нормально после Strike или Influence |
| `testEcho_noNewFateDraw` | Echo не тянет новую Fate-карту, повторяет предыдущий fate_modifier |
| `testEcho_continuesStreak` | Echo продолжает streak, не сбрасывает |

### 10.3 Stress-тесты (exploit-сценарии)

Каждый сценарий проверяет конкретную цепочку, которая может стать exploit'ом:

| Сценарий | Цепочка | Что проверяем |
|----------|---------|--------------|
| **Sacrifice cycle** | sacrifice → strike → enemy rage → strike +3 → weaken trigger | Disposition не уходит за cap; weaken не даёт бесконечный loop |
| **Echo snowball** | strike x3 (streak=3) → echo → surge | effective_power каждого хода ≤ 25; суммарный shift за ход ≤ 40 |
| **Threshold dancing** | держать disposition на 64–66, не триггеря mode | Dynamic threshold (65-75) делает это ненадёжным; тест подтверждает вариацию |
| **Influence lock** | influence x5 → enemy провоцирует → sacrifice → influence | Sacrifice + Provoke достаточно наказывают; disposition не растёт линейно |
| **All-sacrifice opener** | sacrifice t1 → sacrifice t2 → sacrifice t3 | Лимит 1/ход соблюдён; враг накопил +3 к действиям; рука уменьшена на 3 |

### 10.4 Simulation Requirements (перед балансом)

"Proof of Variety" в секции 8.2 — декларативный. Реальное разнообразие нужно **симулировать**.

#### Что симулировать

| Параметр | Метрика | Acceptance criteria |
|----------|---------|-------------------|
| **Win path distribution** | % побед через -100 vs +100 | Ни один путь не >70% для любого героя×врага×resonance |
| **Average combat length** | Ходы до завершения | 5–15 ходов (слишком быстро = нет решений, слишком долго = скука) |
| **Action type distribution** | % Strike / Influence / Sacrifice | Sacrifice <20% от всех действий; Strike и Influence в пределах 30–60% каждый |
| **Echo impact** | % disposition shift от Echo-ходов | <30% от общего shift (если больше — Echo доминирует) |
| **Mode trigger frequency** | Как часто враг входит в Survival/Desperation/Weakened | Survival/Desperation: 40–70% боёв; Weakened: 10–30% боёв |
| **Variety across seeds** | Разница в исходах для 100 seeds | Стандартное отклонение combat length > 2 хода |

#### Как симулировать

1. **Random agent**: случайные действия (baseline — если random побеждает >60%, система не требует навыка)
2. **Greedy strike agent**: всегда strike (проверяет: работает ли anti-strike мета)
3. **Greedy influence agent**: всегда influence (проверяет: работает ли anti-influence мета)
4. **Adaptive agent**: strike пока streak<3, затем influence (проверяет: наказывает ли система переключение)
5. **Sacrifice-heavy agent**: sacrifice каждый ход, затем strike (проверяет: exploit-потенциал sacrifice)

Симуляция запускается на 1000 боёв для каждого agent × enemy type × resonance zone × hero world. Результаты сохраняются в `TestResults/CombatSimulation/`.

---

## 11. Technical Specification

### 11.1 Engine Action Enum

```swift
case combatPlayCardAsStrike(cardId: String, targetId: String)
case combatPlayCardAsInfluence(cardId: String)
case combatPlayCardAsSacrifice(cardId: String)
case combatEndTurn
```

Все мутации — только через actions. Fate draw внутри action (engine-owned RNG).

### 11.2 DispositionCombatSimulation

- `disposition: Int` (-100…+100)
- `streakType: ActionType?`, `streakCount: Int`, `lastActionType: ActionType?`
- `sacrificeUsedThisTurn: Bool`
- `enemyActionDeck: [EnemyActionDefinition]`
- `resonanceZone: ResonanceZone`
- `enemyMode: EnemyMode` (computed from disposition thresholds)
- `fateDeck: [FateCardDefinition]`, `lastFateKeyword: FateKeyword?`
- `enemyVulnerabilities: EnemyVulnerabilityDefinition`
- Methods: `playCardAsStrike(cardId:targetId:)`, `playCardAsInfluence(cardId:)`, `playCardAsSacrifice(cardId:)`, `resolveEnemyTurn()`, `endPlayerTurn()`, `drawFate() -> FateCardDefinition`
- Max 600 строк; калькулятор в `DispositionCombatCalculator`

### 11.3 CombatSnapshot — расширение

```swift
let disposition: Int
let streakType: String?
let streakCount: Int
let lastActionType: String?
let sacrificeUsedThisTurn: Bool
let enemyActionDeckState: [EnemyActionState]
let enemyMode: String              // "normal", "survival", "desperation", "weakened"
let enemyModeHysteresisRemaining: Int  // turns left before mode can change (0 = can change)
let survivalThreshold: Int         // seed-based, -65…-75
let desperationThreshold: Int      // seed-based, +65…+75
let fateDeckState: [FateCardState] // remaining fate cards (order preserved for determinism)
let lastFateKeyword: String?       // keyword from last fate draw
let resonanceZone: String
```

### 11.4 Content Pack — расширение

#### AffinityMatrix

```swift
struct AffinityMatrixDefinition: Codable {
    let id: String
    let entries: [AffinityEntry]
}
struct AffinityEntry: Codable {
    let heroWorld: String    // "nav", "yav", "prav"
    let enemyType: String
    let baseDisposition: Int
}
```

#### EnemyActionDeck

```swift
struct EnemyActionDefinition: Codable {
    let id: String
    let type: String            // "attack", "defend", "provoke", "adapt", "rage", "plea"
    let value: Int
    let weight: Int             // AI selection weight
    let dispositionThreshold: Int?
    let streakThreshold: Int?   // trigger: play only if player streak >= N
    let modeRestriction: String? // nil = any mode, "survival", "desperation", "weakened"
}
```

#### FateCard

```swift
struct FateCardDefinition: Codable {
    let id: String
    let keyword: String       // "surge", "shadow", "ward", "focus", "echo"
    let baseModifier: Int     // -1, 0, +1
}
```

#### EnemyVulnerability

```swift
struct EnemyVulnerabilityDefinition: Codable {
    let enemyType: String
    let strikeModifier: Int       // +2 = vulnerable, -3 = resistant, 0 = neutral
    let influenceModifier: Int
    let sacrificeEffect: String   // "neutral", "provoke", "weaken"
    let sacrificeValue: Int       // +2 ATK for provoke, -1 DEF for weaken
    let resonanceOverrides: [ResonanceVulnerabilityOverride]?
}
struct ResonanceVulnerabilityOverride: Codable {
    let zone: String              // "nav", "yav", "prav"
    let strikeModifier: Int?      // nil = use base
    let influenceModifier: Int?
    let sacrificeEffect: String?
    let sacrificeValue: Int?
}
```

#### Card model — backward compatibility

```swift
let strikePower: Int?       // nil → fallback to card.power ?? 1
let influencePower: Int?    // nil → fallback to card.power ?? 1
```

#### ResonanceZoneModifiers

```swift
struct ResonanceZoneModifiers: Codable {
    let zone: String                // "nav", "yav", "prav"
    let strikeBonus: Int            // +/- to strike
    let strikeBacklash: Int         // HP cost to hero per strike
    let influenceBonus: Int         // +/- to influence
    let sacrificeEnergyCostMod: Int // -1 = cheaper, +1 = extra exhaust risk
    let enemyAttackBonus: Int       // enemy ATK modifier
}
```

### 11.5 Arena x Disposition

- Arena может использовать Disposition Combat
- Arena результат НЕ коммитится в world-engine state
- Arena использует собственный RNG seed
- Gate-тест на изоляцию обязателен

### 11.6 Migration (по фазам)

| Шаг | Фаза | Что делаем |
|-----|-------|-----------|
| 1 | contract | Action enum + формулы + CLAUDE.md обновление |
| 2 | tests | Gate-тесты для всех инвариантов из раздела 10.2 |
| 3 | code | `DispositionCombatSimulation`, `DispositionCombatCalculator`, snapshot |
| 4 | code | `RitualCombatScene` адаптация (layout, drag-drop, visual feedback) |
| 5 | content | AffinityMatrix + EnemyActionDeck + ResonanceZoneModifiers |
| 6 | tests | Интеграционные тесты, удаление старых Ritual Combat тестов |
| 7 | validation | `run_release_check_snapshot.sh`, полный прогон gates |

---

## 12. Auditor Response Matrix

Документ прошёл 5 раундов аудита. Ниже — mapping повторяющихся замечаний к механизмам, которые их закрывают.

### 12.1 "Система слишком сложна" (поднималось 3 раза)

**Ответ:** сложность в engine, не в голове игрока.

| Слой | Тип | Где закрыт |
|------|-----|-----------|
| Disposition | Player-facing | Секция 1.4 — disposition bar всегда виден |
| Momentum | Felt, not calculated | Секция 1.4 — аура + число streak, не формула |
| Threat bonus | Engine-internal | Секция 1.4 — поглощён итоговым числом |
| Switch penalty | Felt | Секция 1.4 — "стало слабее при переключении" |
| Fate keyword | Player-facing | Секция 5.3 — название + краткий эффект |
| Fate base modifier | Engine-internal | Секция 1.4 — поглощён keyword-эффектом |
| Resonance | Felt | Секция 1.4 — цветовая палитра + подсказка |
| Vulnerabilities | Felt | Секция 1.4 — "этот враг уязвим тут" |
| Enemy mode | Player-facing | Секция 7.8 — visual communication contract |
| Adaptation | Engine-internal | Секция 1.4 — враг "контрит", игрок видит telegraph |
| Sacrifice buff | Engine-internal | Секция 1.4 — "враг злее" через анимацию |
| Affinity | Felt | Секция 1.4 — стартовая позиция на bar |

**Частота наложений:** контролируется симуляцией (секция 10.4). Не правилами.

### 12.2 "X может стать метой" (поднималось 5 раз)

| Что | Почему не мета | Где закрыт |
|-----|---------------|-----------|
| Sacrifice spam | 1/ход + усиление врага + exhaust навсегда | Секция 6.2 |
| Echo snowball | 2/15 (13%) + не после Sacrifice + hard cap 25 | Секция 5.3 |
| Surge swingy | +50% base only, не bonus'ы + hard cap 25 | Секция 5.1, 5.3 |
| Weakened exploit | Требует swing ±30 (не воспроизводимо) + враг всё равно действует | Секция 7.3, 10.3 |
| Nav dark rush | Data-driven resonance modifiers — поворот ручки, не редизайн | Секция 5.2, 11.4 |
| Threshold dancing | Dynamic thresholds (65–75 per seed) + hysteresis | Секция 7.3 |
| Matchup table | Vulnerabilities × Resonance = 3D lookup, слишком сложно для запоминания | Секция 7.2 |
| Fate deck building | Fate deck общий и фиксированный — игрок не выбирает карты | Секция 5.3 |

### 12.3 Граница дизайна vs баланса

Дизайн-документ фиксирует **механики и контракты**. Следующие вопросы решаются **симуляцией**, а не правилами:

- Конкретные числа (strikeBonus: +2 или +1)
- Частота наложения модификаторов
- Доминирование конкретного героя/врага/resonance
- Оптимальная длина боя

Все числовые параметры — data-driven (content pack). Изменение баланса не требует изменения кода или дизайна.

### 12.4 Готовность к реализации

| Критерий | Статус |
|----------|--------|
| Core loop определён | Disposition Track + 3 drag modes |
| Формулы детерминистичны | effective_power с hard cap 25 |
| Anti-meta доказан | 8 механизмов в секции 8.1 + stress-tests |
| Engine-first соблюдён | Actions в секции 11.1, snapshot в 11.3 |
| Content data-driven | 5 content pack типов в секции 11.4 |
| Gate-тесты определены | 35 тестов в секции 10.2 |
| Stress-тесты определены | 5 exploit-сценариев в секции 10.3 |
| Simulation plan готов | 5 agent-типов, 6 метрик в секции 10.4 |
| Visual contract | Переходы, анимации, tooltips в секции 7.8 |

---

## 13. Backlog (за пределами MVP)

### P1 — Следующий цикл
- [ ] **Adaptive Enemy AI**: глубокая адаптация, memory между encounter'ами
- [ ] **Combo-эффекты**: синергия карт при последовательном розыгрыше
- [ ] **Множественные враги**: 2-3 врага с независимыми disposition tracks
- [ ] **Прокачка героя**: progression system, улучшение колоды

### P2 — Будущее
- [ ] **Уникальные способности карт**: special effects помимо strike/influence
- [ ] **Environmental modifiers**: уникальные правила для конкретных локаций
- [ ] **Faction reputation**: глобальная reputation, влияющая на affinity
- [ ] **Multiplayer encounters**: кооперативные encounter'ы
- [ ] **Card crafting**: создание/модификация карт
- [ ] **Influence subtypes**: угроза, обман, убеждение — разные подтипы с уникальными последствиями
- [ ] **Enemy memory**: враг помнит предыдущие encounter'ы с этим героем
