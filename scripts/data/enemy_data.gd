extends Resource
class_name EnemyData
## Defines a monster archetype: stats, AI behaviour, visuals and rewards.

enum AI { PASSIVE, DEFENSIVE, AGGRO, PATROL, BOSS }

@export var id: String = ""
@export var display_name: String = "Monster"
@export var max_health: float = 40.0
@export var damage: float = 6.0
@export var defence: float = 0.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var move_speed: float = 2.4
@export var aggro_radius: float = 9.0
@export var leash_radius: float = 22.0
@export_enum("PASSIVE", "DEFENSIVE", "AGGRO", "PATROL", "BOSS") var ai: int = AI.AGGRO

@export var xp_reward: int = 12
@export var gold_min: int = 1
@export var gold_max: int = 5
@export var loot_table_id: String = ""

## Visual + animation source (vendored KayKit character).
@export_file("*.glb") var model_path: String = ""
@export var model_scale: float = 1.0

## Optional elemental / magic affinity used by the spell system.
@export var resist_fire: float = 0.0
@export var resist_ice: float = 0.0
@export var resist_arcane: float = 0.0


func is_boss() -> bool:
	return ai == AI.BOSS
