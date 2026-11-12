extends RefCounted
## Built-in monster archetypes.  Kept in GDScript rather than .tres so the whole
## roster is diffable and testable headlessly; a .tres may override any entry.

const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")
const EnemyData = preload("res://scripts/data/enemy_data.gd")

const DEFINITIONS := {
	"meadow_slime": {
		"display_name": "Meadow Slime", "max_health": 32.0, "damage": 5.0, "move_speed": 1.9,
		"attack_range": 1.8, "attack_cooldown": 1.6, "aggro_radius": 8.0,
		"xp_reward": 10, "gold_min": 1, "gold_max": 4, "ai": EnemyData.AI.AGGRO,
		"model": AssetCatalog.SKELETON_MINION, "scale": 0.55, "loot": "slime",
	},
	"skeleton_minion": {
		"display_name": "Skeleton Minion", "max_health": 46.0, "damage": 7.0, "move_speed": 2.6,
		"attack_range": 2.0, "attack_cooldown": 1.4, "aggro_radius": 11.0,
		"xp_reward": 16, "gold_min": 2, "gold_max": 6, "ai": EnemyData.AI.AGGRO,
		"model": AssetCatalog.SKELETON_MINION, "scale": 0.9, "loot": "skeleton",
	},
	"skeleton_warrior": {
		"display_name": "Skeleton Warrior", "max_health": 78.0, "damage": 11.0, "move_speed": 2.9,
		"attack_range": 2.3, "attack_cooldown": 1.3, "aggro_radius": 12.0, "defence": 3.0,
		"xp_reward": 26, "gold_min": 3, "gold_max": 9, "ai": EnemyData.AI.AGGRO,
		"model": AssetCatalog.SKELETON_WARRIOR, "scale": 0.92, "loot": "skeleton",
	},
	"skeleton_rogue": {
		"display_name": "Skeleton Rogue", "max_health": 58.0, "damage": 13.0, "move_speed": 3.4,
		"attack_range": 1.9, "attack_cooldown": 1.0, "aggro_radius": 13.0,
		"xp_reward": 24, "gold_min": 3, "gold_max": 8, "ai": EnemyData.AI.PATROL,
		"model": AssetCatalog.SKELETON_ROGUE, "scale": 0.9, "loot": "skeleton",
	},
	"skeleton_mage": {
		"display_name": "Skeleton Mage", "max_health": 52.0, "damage": 15.0, "move_speed": 2.2,
		"attack_range": 9.0, "attack_cooldown": 2.4, "aggro_radius": 15.0,
		"xp_reward": 30, "gold_min": 4, "gold_max": 10, "ai": EnemyData.AI.DEFENSIVE,
		"model": AssetCatalog.SKELETON_MAGE, "scale": 0.9, "loot": "mage", "resist_fire": 0.3,
	},
	"forest_wolf": {
		"display_name": "Forest Wolf", "max_health": 44.0, "damage": 9.0, "move_speed": 4.0,
		"attack_range": 1.8, "attack_cooldown": 0.9, "aggro_radius": 16.0,
		"xp_reward": 20, "gold_min": 1, "gold_max": 4, "ai": EnemyData.AI.PATROL,
		"model": AssetCatalog.SKELETON_ROGUE, "scale": 0.85, "loot": "slime", "resist_ice": 0.25,
	},
	"earth_golem": {
		"display_name": "Earth Golem", "max_health": 130.0, "damage": 16.0, "move_speed": 1.6,
		"attack_range": 2.6, "attack_cooldown": 2.0, "aggro_radius": 10.0, "defence": 8.0,
		"xp_reward": 45, "gold_min": 6, "gold_max": 14, "ai": EnemyData.AI.DEFENSIVE,
		"model": AssetCatalog.SKELETON_WARRIOR, "scale": 1.3, "loot": "golem", "resist_ice": 0.2,
	},
	"wraith": {
		"display_name": "Wraith", "max_health": 66.0, "damage": 14.0, "move_speed": 3.0,
		"attack_range": 8.0, "attack_cooldown": 2.0, "aggro_radius": 14.0,
		"xp_reward": 34, "gold_min": 4, "gold_max": 11, "ai": EnemyData.AI.AGGRO,
		"model": AssetCatalog.SKELETON_MAGE, "scale": 1.0, "loot": "mage", "resist_arcane": 0.4,
	},
	"boar": {
		"display_name": "Wild Boar", "max_health": 38.0, "damage": 7.0, "move_speed": 3.2,
		"attack_range": 1.7, "attack_cooldown": 1.5, "aggro_radius": 7.0,
		"xp_reward": 12, "gold_min": 1, "gold_max": 3, "ai": EnemyData.AI.DEFENSIVE,
		"model": AssetCatalog.SKELETON_MINION, "scale": 0.8, "loot": "slime",
	},
	"boss_bone_warden": {
		"display_name": "The Bone Warden", "max_health": 620.0, "damage": 22.0, "move_speed": 2.2,
		"attack_range": 3.2, "attack_cooldown": 1.7, "aggro_radius": 26.0, "defence": 6.0,
		"xp_reward": 320, "gold_min": 60, "gold_max": 90, "ai": EnemyData.AI.BOSS,
		"model": AssetCatalog.SKELETON_WARRIOR, "scale": 1.75, "loot": "boss",
	},
}

## Peaceful wildlife (rendered + simulated with their own AI, never hostile).
const PASSIVE := ["deer", "rabbit"]


static func create(id: String) -> Resource:
	if not DEFINITIONS.has(id):
		return null
	var spec: Dictionary = DEFINITIONS[id]
	var data := EnemyData.new()
	data.id = id
	data.display_name = spec.get("display_name", id)
	data.max_health = spec.get("max_health", 40.0)
	data.damage = spec.get("damage", 6.0)
	data.defence = spec.get("defence", 0.0)
	data.attack_range = spec.get("attack_range", 2.0)
	data.attack_cooldown = spec.get("attack_cooldown", 1.5)
	data.move_speed = spec.get("move_speed", 2.4)
	data.aggro_radius = spec.get("aggro_radius", 9.0)
	data.xp_reward = spec.get("xp_reward", 10)
	data.gold_min = spec.get("gold_min", 1)
	data.gold_max = spec.get("gold_max", 5)
	data.loot_table_id = spec.get("loot", "")
	data.model_path = spec.get("model", AssetCatalog.SKELETON_MINION)
	data.model_scale = spec.get("scale", 1.0)
	data.ai = spec.get("ai", EnemyData.AI.AGGRO)
	data.resist_fire = spec.get("resist_fire", 0.0)
	data.resist_ice = spec.get("resist_ice", 0.0)
	data.resist_arcane = spec.get("resist_arcane", 0.0)
	return data


static func ids() -> Array[String]:
	var result: Array[String] = []
	for key in DEFINITIONS.keys():
		result.append(key)
	return result
