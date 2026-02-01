# ECHO: ECS + SpriteKit + Metal Migration Design

## Overview

Full architectural migration from SwiftUI + Engine-First to ECS + SpriteKit + Metal + GameplayKit.

**Stack:**
- FirebladeECS (Nexus-based ECS)
- SpriteKit (2D rendering, scenes)
- Metal (custom shaders for card effects, fog, auras)
- GameplayKit (AI state machines, strategist)
- SwiftUI (navigation shell, settings, static screens only)

---

## 1. Architecture

```
JSON Content Packs (unchanged)
       |
ContentRegistry (loading, validation)
       |
   Nexus (ECS world)
       |
  Systems: Logic → Render
       |
  SKScene → SpriteView → SwiftUI shell
```

Engine-First replaced by ECS. All game state lives in components on entities inside a single Nexus. Systems process components each frame. No direct state mutation outside systems.

---

## 2. Entities

| Entity | Description |
|--------|-------------|
| PlayerEntity | Health, faith, balance, deck, hero, curses |
| EnemyEntity | HP, Will, intents, behavior, abilities, AI |
| CardEntity | Card in hand/deck/discard: type, cost, effects |
| FateCardEntity | Fate card: modifier, resonance effect |
| RegionEntity | World map region: anchor, events, neighbors |
| WorldEntity | Global state: day, tension, resonance |

---

## 3. Components

```swift
struct HealthComponent: Component { var current: Int; var max: Int }
struct FaithComponent: Component { var current: Int; var max: Int }
struct BalanceComponent: Component { var value: Int } // 0...100
struct DeckComponent: Component { var deck: [CardRef]; var hand: [CardRef]; var discard: [CardRef] }
struct HeroComponent: Component { var heroId: String; var stats: HeroStats }
struct CurseComponent: Component { var activeCurses: [ActiveCurse] }
struct CombatStateComponent: Component { var phase: CombatPhase; var round: Int }
struct SpriteComponent: Component { var nodeName: String; var textureName: String }
struct PositionComponent: Component { var x: Float; var y: Float }
struct IntentComponent: Component { var action: EnemyAction; var value: Int }
struct AIComponent: Component { var stateMachine: GKStateMachine }
```

---

## 4. Systems

### Logic Systems (no UI)

| System | Reads | Writes |
|--------|-------|--------|
| CombatSystem | CombatState, Health, Intent, Curse | Health, CombatState |
| FateDeckSystem | FateDeck, Resonance | FateDeck, CombatState |
| DeckSystem | Deck | Deck |
| CurseSystem | Curse, Health | Curse, Health |
| AISystem | AI, Health, CombatState | Intent |
| TimeSystem | World | World |
| EventSystem | World, Region, Balance | World, Balance |
| SaveSystem | All | -- |

### Render Systems (SpriteKit)

| System | Purpose |
|--------|---------|
| SpriteRenderSystem | Sync SpriteComponent to SKSpriteNode |
| AnimationSystem | Attack, damage, heal animations |
| ParticleSystem | SKEmitterNode for magic/effects |
| ShaderSystem | Apply Metal shaders (glow, auras) |
| UIRenderSystem | HUD: health, faith, balance, combat log |

### Execution Order

```
AISystem -> CombatSystem -> FateDeckSystem -> DeckSystem -> CurseSystem
-> TimeSystem -> EventSystem
-> SpriteRenderSystem -> AnimationSystem -> ParticleSystem -> ShaderSystem -> UIRenderSystem
```

---

## 5. SpriteKit Scenes

| Scene | Content |
|-------|---------|
| CombatScene | Arena: enemy top, cards bottom, Fate deck side, HUD, particles |
| WorldMapScene | Region nodes, paths, fog of war, atmospheric particles |
| EventScene | Visual novel: background, character, text, choices |
| MainMenuScene | Animated background, hero selection |

Scenes contain no logic -- only rendering. Touch input produces commands into ECS.

```swift
class CombatScene: SKScene {
    let nexus: Nexus
    let renderSystems: [RenderSystem]

    override func update(_ currentTime: TimeInterval) {
        renderSystems.forEach { $0.update(nexus: nexus, dt: deltaTime) }
    }
}
```

---

## 6. Metal Shaders

| Shader | Effect |
|--------|--------|
| card_glow.metal | Card outline glow (color by type: attack/defense/spell) |
| card_holographic.metal | Holographic shimmer on tilt (rare cards) |
| resonance_aura.metal | Resonance aura: Nav = dark purple, Prav = gold |
| damage_dissolve.metal | Enemy death dissolve (pixel scatter) |
| fog_of_war.metal | Procedural noise fog on world map |
| energy_flow.metal | Energy streams between cards and player on cast |

## 7. Particle Systems

| Emitter | Usage |
|---------|-------|
| magic_cast.sks | Spell cast |
| sword_slash.sks | Melee attack |
| heal_sparkle.sks | Healing |
| curse_smoke.sks | Curse applied |
| fate_reveal.sks | Fate card reveal flash |

---

## 8. GameplayKit AI

Enemy AI via GKStateMachine:

```
IdleState       -- waiting for turn
AggressiveState -- HP > 50%: attacks
DefensiveState  -- HP < 30%: defend/heal
EnragedState    -- HP < 15%: empowered attacks
FleeState       -- Will = 0: flee/surrender
```

Transitions driven by HealthComponent and CombatStateComponent. AISystem calls `stateMachine.update(deltaTime:)`, writes result to IntentComponent.

Boss enemies use `GKMinmaxStrategist` for 2-3 turn lookahead.

---

## 9. Migration from Current Architecture

### Preserved as-is
- JSON content packs (same definitionId format)
- ContentRegistry (JSON loading)
- FateDeckManager / WorldRNG (become systems)
- BalanceConfiguration data

### Rewritten
- TwilightGameEngine + 3 managers -> Nexus + Systems
- EngineSave -> component serialization from Nexus
- 31 SwiftUI Views -> 4 SpriteKit scenes + SwiftUI shell
- EncounterViewModel -> CombatSystem + AISystem

### Deleted
- All SwiftUI game views (CombatView, WorldMapView, EventView, etc.)
- EncounterBridge, CombatSubviews
- Current design system (AppColors/Spacing/AppFonts) -> SpriteKit equivalent

---

## 10. Migration Order (Incremental)

Each step produces a working game. Old SwiftUI screens live alongside new SpriteKit scenes.

1. **New package `EchoEngine`** -- ECS core + logic systems (no UI), headless tests
2. **Combat pilot** -- CombatSystem + CombatScene + shaders + particles
3. **World Map** -- WorldMapScene + EventSystem + fog shader
4. **Events** -- EventScene
5. **Menus** -- MainMenuScene
6. **Cleanup** -- remove TwilightEngine, old Views, old tests

---

## 11. Project Structure

```
Packages/
  EchoEngine/
    Sources/EchoEngine/
      Core/           -- Nexus setup, World bootstrap
      Components/     -- all components
      Systems/
        Logic/        -- CombatSystem, DeckSystem, AISystem...
        Render/       -- SpriteRenderSystem, AnimationSystem...
      Content/        -- ContentRegistry, JSON loading
      RNG/            -- FateDeckManager, WorldRNG
      Save/           -- SaveSystem, component serialization
    Tests/EchoEngineTests/
      Systems/        -- isolated system tests
      Integration/    -- full combat/event scenarios

  TwilightEngine/     -- lives in parallel until full migration

GameScenes/
  CombatScene.swift
  WorldMapScene.swift
  EventScene.swift
  MainMenuScene.swift

Shaders/
  card_glow.metal
  card_holographic.metal
  resonance_aura.metal
  damage_dissolve.metal
  fog_of_war.metal
  energy_flow.metal

Particles/
  magic_cast.sks
  sword_slash.sks
  heal_sparkle.sks
  curse_smoke.sks
  fate_reveal.sks
```

---

## 12. Testing Strategy

Logic systems tested headless (no SpriteKit):

```swift
@Test("CombatSystem resolves attack damage")
func testAttackDamage() {
    let nexus = Nexus()
    let player = nexus.createEntity()
    player.assign(HealthComponent(current: 10, max: 10))

    let enemy = nexus.createEntity()
    enemy.assign(HealthComponent(current: 8, max: 8))
    enemy.assign(IntentComponent(action: .attack, value: 3))

    CombatSystem.resolve(nexus: nexus)

    let playerHP = player.get(component: HealthComponent.self)
    #expect(playerHP?.current == 7)
}
```

- RNG: seeded WorldRNG, deterministic
- Render systems: manual testing + snapshot tests
- AI: unit tests for state transitions

---

## 13. Hard Rules (Updated)

- No System RNG: WorldRNG / FateDeckManager only
- No UI in EchoEngine package (SpriteKit/SwiftUI forbidden)
- Components are pure data, no logic
- Systems are stateless functions operating on components
- Scene touch input -> commands, never direct state mutation
- definitionId (String), no UUID for content
- Saves serialize all components from Nexus, fail-fast on missing data
