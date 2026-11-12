# Game design: scope and current contract

## Vision (planned)
An offline-first spherical fantasy RPG with exploration, guild progression F–S, combat, magic, living settlements, economy and persistent consequences. The requested six continents, kingdoms, dungeons, extensive crafting, classes, bosses and simulation are design goals, not delivered content.

## Implemented slice
The player begins at a small guild outpost on a smooth sphere. Interacting with the registrar accepts a contract to defeat three slimes. A nearby slime chases the player, attacks on a timer and returns to spawn outside its pursuit limits. A strike works at short range; a targeted arcane attack costs mana and has a cooldown. Kills advance the contract, give XP and gold, and persist; returning to the registrar grants a single reward. Discovering a new coordinate cell gives XP once. Leveling restores and increases maximum health. The world clock rotates the directional light. Death returns the player to the outpost without resetting kills.

A second contract records three gathered herbs. Eight finite herb pickups remain collected after loading; collecting before accepting the contract is credited. A potion costs two herbs and heals up to 40 HP; an iron sword costs two herbs and 12 gold, increases melee damage by eight, and changes the visible equipment. At the registrar, promotion to E requires both contracts, five slime defeats and a discovered cell. D requires seven defeats, four cells, both contracts and level 3. These are simple criteria checks, not separate exam encounters. Rank does not increase automatically with level.

A fogged world map marks only discovered partition cells, the player, and activated waypoints; interacting with the outpost and two shrines activates those locations for fast travel. Travel is blocked when enemies are near the player or destination. No travel points unlock from a legacy save automatically. The map is a simple global diagram, not a terrain map.

Content counts: one spherical test world, three travel points, one outpost, one NPC (registrar), one enemy type (up to eight instances), two contracts, one spell, one forgeable weapon, one potion recipe, zero bosses, zero dungeons. F, E and D are implemented. These are not substitutes for the full MVP.
