# GAME DESIGN DOCUMENT — MICRO WORLD: LIVING

## 1. Pitch

You are a fresh F-rank adventurer of the Cartographers' Guild, posted to **Havenbrook**, a
shrine-village on a small living world floating in a hollow sky. Walk anywhere: the planet is a
continuous sphere of radius 250 m, and gravity pulls toward its centre. Climb the guild ladder
F→E→D, cull monsters in the meadow, delve into the **Barrow of the Bone Warden**, and uncover why
the world's shrines are pulsing.

Tone: warm low-poly fantasy, chunky readable silhouettes, tablet-first controls, no gacha, no
network. Everything runs offline.

## 2. Design pillars

1. **One world, no loading screens.** The planet is one mesh with streamed content; every pixel you
   can see is walkable.
2. **Touch-native.** A thumb can move and fight at the same time; every button maps to a real
   verb, never to decoration.
3. **Readable depth.** Ten monster archetypes and six spells are enough if the sword feels right:
   light chain, heavy commitment, dodge with i-frames, lock-on for the boss.
4. **A living valley.** Villagers commute on a schedule, day turns to night, and the guild notices
   what you do.

## 3. Core loop (implemented end to end)

```
Main menu → Continue/New Game → spawn at Havenbrook
      ↓
Talk to Registrar Maeve → accept contract (QUEST 1)
      ↓
Explore meadow → gather herbs/ore → fight slimes (XP, gold, loot)
      ↓
Craft potion / equip sword at the forge → heal, hit harder
      ↓
Turn in contracts → guild rank F → E → D → new recipes and quests unlock
      ↓
Rumours point to the Barrow → dungeon → Bone Warden (3 phases) → epic loot table
      ↓
Autosave (45 s + on pause/exit) → resume anywhere on the planet
```

## 4. Moment-to-moment combat

| Verb | Input (touch / desktop) | Behaviour |
| --- | --- | --- |
| Light attack | ⚔ button / `J` | 3-hit chain, 0.55 s recovery, cone sweep 2.6 m, 70° |
| Heavy attack | 💥 button / `K` | 1.1 s commitment, 2.2× damage, 3.4 m reach |
| Dodge | ↷ button / `L` | 0.35 s invulnerability, costs stamina, breaks lock-on |
| Jump | ↑ button / `Space` | Analytic hop against radial gravity |
| Cast | ✦ button / `Q` | Selected spell; 6 spells across fire / frost / arcane |
| Interact | ✋ / `E` | Contextual: chest, node, NPC, shrine, dungeon mouth |
| Lock-on | target frame tap | Hard-locks a monster; camera leads the target |

Damage = `(weapon + skill bonus) × archetype multiplier × crit(1.75×) × phase modifier`, resisted by
armour. Monsters die into a real loot table roll (weights + guaranteed drops) and grant XP/gold.

## 5. Progression

### Levels
XP curve to level 60; each level grants +1 skill point, restores health and bumps max health/mana.

### Guild ranks
| Rank | Requirements (all must hold) | Reward |
| --- | --- | --- |
| **F** | start | copper plate, tier-1 contracts |
| **E** | 2 contracts, 5 kills, 1 region discovered | iron plate, forge tier 2, +1 spell slot |
| **D** | 5 contracts, 15 kills, 3 regions, level 3, boss cleared | steel plate, elixir recipe, dungeon access |
| **C** | declared, requirements not tuned | — |
| **B / A / S** | stubbed in `rank_rules.ORDER` | — |

Promotion is a real check against live state, not a level-up side effect.

### Skills
Three skills × five ranks: **Might** (melee damage), **Focus** (spell power/mana), **Endurance**
(health/stamina). Spend points in the Skills panel; derived stats recalculate immediately.

## 6. World content (as built)

| Content | Count | Where |
| --- | --- | --- |
| Planet | 1 (r=250 m, 6 faces × 16×16 quads) | `scripts/planet/` |
| Biomes | 7 (ocean, beach, meadow, forest, highland, ruins, crag) | `terrain.gd` |
| Streamed regions | 864 (`SIZE=12` per face) | `planet_regions.gd` |
| Village | Havenbrook: 1 registrar hall, forge, shop, 5 shrine markers | `world_builder.gd` |
| Dungeon | 1 — Barrow of the Bone Warden, 3 rooms + boss hall | `dungeon_builder.gd` |
| Monster camps | 10 | `world_builder.gd` |
| Monster archetypes | 10 (9 regular + 1 boss) | `monster_definitions.gd` |
| Quests | 15 | `quest_database.gd` |
| Items | 24 (weapons, armour, potions, materials, trinkets) | `item_database.gd` |
| Recipes | 8 | `item_database.gd` |
| Spells | 6 across 3 schools | `spell_database.gd` |
| Resource nodes | 24 | `world_builder.gd` |
| Chests | 4 + 1 boss vault | `world_builder.gd` |
| NPCs | 3 villagers with 3-slot daily schedules | `world_builder.gd` |
| Shrines (fast travel) | 5 | `world_builder.gd` |
| Loot tables | 6 (per archetype + boss + chests) | `game_world.gd` |

## 7. Living world

- **Clock:** 12-minute day, four phases (dawn/day/dusk/night) driving sun colour, ambient light and
  NPC greetings.
- **NPC schedules:** each villager has three daily anchors (home / market / home). At night they
  return home; greetings change by hour.
- **Monsters:** idle → patrol → chase → attack → return, with leash radius and region-aware sleep.
- **Simulation LOD:** beyond 45 m monsters stop pathing and tick coarsely; at most 24 run at once.
- **Economy:** shops buy at 0.45× and sell at 1.6× base value; sells are gated by rank.
- **Gathering:** ore veins, herb patches, deadwood and crystal outcrops feed 8 recipes.

## 8. Android UX contract

- Landscape only, immersive full-screen, safe-area insets honoured.
- Left thumb: virtual stick with 44 px dead-zone ring. Right thumb: 5 hot buttons in an arc.
- Panels are bottom-sheet style with a single close affordance and no nested modals.
- Text scales with `Theme` scale factor; minimum touch target 44 dp.
- HUD never covers the stick/button zones; the target frame sits top-right.
- **Continue** is disabled (and visibly labelled *No save*) when no save exists.
- Quality presets: **Low** (no shadows, 0.6 render scale), **Medium**, **High**.

## 9. Out of scope for this build

Six continents, kingdoms/interiors beyond Havenbrook and the barrow, weather, seasons, mounts,
crafting-station minigames, PvP, online features, monetisation, localisation (Arabic UI is planned,
not shipped), and a full character creator.
