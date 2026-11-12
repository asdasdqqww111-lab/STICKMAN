extends RefCounted
## Built-in item catalogue: weapons, armour, consumables, materials.
## UI, crafting, loot and the save validator all read from here.

const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")
const ItemData = preload("res://scripts/data/item_data.gd")

const SWORD_OFFSET := Vector3(0.0, 0.0, 0.0)
const SWORD_ROTATION := Vector3(0.0, 0.0, 0.0)

## key -> definition dictionary.  `kind` uses ItemData.Kind numeric values so the
## file stays a plain const (Resources are created lazily by `create`).
const DEFINITIONS := {
	# --- weapons -----------------------------------------------------------
	"rusty_sword": {
		"name": "Rusty Shortsword", "kind": ItemData.Kind.WEAPON, "attack": 4.0, "value": 6, "rarity": 0,
		"desc": "A chipped blade from the guild armoury. Better than fists.",
		"model": AssetCatalog.WEAPON_SWORD,
	},
	"iron_sword": {
		"name": "Iron Sword", "kind": ItemData.Kind.WEAPON, "attack": 9.0, "value": 24, "rarity": 1,
		"desc": "Forged at Havenbrook's smithy. A dependable blade.",
		"model": AssetCatalog.WEAPON_SWORD,
	},
	"greatsword": {
		"name": "Warden Greatsword", "kind": ItemData.Kind.WEAPON, "attack": 15.0, "value": 60, "rarity": 2,
		"desc": "Two-handed steel recovered from the Bone Warden.",
		"model": AssetCatalog.WEAPON_GREATSWORD, "scale": 1.0,
	},
	"dagger": {
		"name": "Scout Dagger", "kind": ItemData.Kind.WEAPON, "attack": 5.0, "value": 12, "rarity": 0,
		"desc": "Quick, quiet, and good for skinning.",
		"model": AssetCatalog.WEAPON_DAGGER,
	},
	"battle_axe": {
		"name": "Battle Axe", "kind": ItemData.Kind.WEAPON, "attack": 12.0, "value": 38, "rarity": 1,
		"desc": "Heavy, but it bites deep.",
		"model": AssetCatalog.WEAPON_AXE,
	},
	"apprentice_staff": {
		"name": "Apprentice Staff", "kind": ItemData.Kind.WEAPON, "attack": 3.0, "power": 8.0, "value": 20, "rarity": 1,
		"desc": "Channels arcane focus. +8 spell power.",
		"model": AssetCatalog.WEAPON_STAFF,
	},
	"frost_staff": {
		"name": "Frostbound Staff", "kind": ItemData.Kind.WEAPON, "attack": 5.0, "power": 16.0, "value": 55, "rarity": 2,
		"desc": "Cold to the touch. Ice spells cost less to focus.",
		"model": AssetCatalog.WEAPON_STAFF,
	},
	# --- armour ------------------------------------------------------------
	"apprentice_robe": {
		"name": "Apprentice Robe", "kind": ItemData.Kind.ARMOUR, "defence": 3.0, "power": 4.0, "value": 14, "rarity": 0,
		"desc": "Thin cloth, but it does not slow a spellcaster.",
	},
	"guild_leathers": {
		"name": "Guild Leathers", "kind": ItemData.Kind.ARMOUR, "defence": 6.0, "value": 26, "rarity": 1,
		"desc": "Standard issue for registered guild adventurers.",
	},
	"bone_plate": {
		"name": "Bone Plate", "kind": ItemData.Kind.ARMOUR, "defence": 12.0, "value": 70, "rarity": 2,
		"desc": "Warden bone, still humming with old magic.",
	},
	"round_shield": {
		"name": "Round Shield", "kind": ItemData.Kind.ARMOUR, "defence": 5.0, "value": 18, "rarity": 0,
		"desc": "A guild-issue shield of oiled oak.",
		"model": AssetCatalog.WEAPON_SHIELD,
	},
	# --- consumables -------------------------------------------------------
	"healing_potion": {
		"name": "Healing Potion", "kind": ItemData.Kind.CONSUMABLE, "heal": 45.0, "value": 8, "rarity": 0,
		"desc": "Restores 45 health.", "stack": 99,
	},
	"mana_potion": {
		"name": "Mana Potion", "kind": ItemData.Kind.CONSUMABLE, "mana": 35.0, "value": 9, "rarity": 0,
		"desc": "Restores 35 mana.", "stack": 99,
	},
	"elixir": {
		"name": "Warden Elixir", "kind": ItemData.Kind.CONSUMABLE, "heal": 120.0, "mana": 80.0, "value": 40, "rarity": 2,
		"desc": "Restores 120 health and 80 mana.", "stack": 20,
	},
	# --- materials ---------------------------------------------------------
	"purple_herb": {
		"name": "Purple Herb", "kind": ItemData.Kind.MATERIAL, "value": 3, "rarity": 0,
		"desc": "Moonbell herb. Used for potions and poultices.", "stack": 99,
	},
	"iron_ore": {
		"name": "Iron Ore", "kind": ItemData.Kind.MATERIAL, "value": 5, "rarity": 0,
		"desc": "Raw ore from the hills above Havenbrook.", "stack": 99,
	},
	"bone_shard": {
		"name": "Bone Shard", "kind": ItemData.Kind.MATERIAL, "value": 4, "rarity": 0,
		"desc": "Splintered warden bone. Smiths pay well for it.", "stack": 99,
	},
	"wolf_pelt": {
		"name": "Wolf Pelt", "kind": ItemData.Kind.MATERIAL, "value": 7, "rarity": 0,
		"desc": "Thick forest wolf hide.", "stack": 99,
	},
	"amber_resin": {
		"name": "Amber Resin", "kind": ItemData.Kind.MATERIAL, "value": 9, "rarity": 1,
		"desc": "Warm resin used to focus fire enchantments.", "stack": 99,
	},
	"crystal_shard": {
		"name": "Crystal Shard", "kind": ItemData.Kind.MATERIAL, "value": 12, "rarity": 1,
		"desc": "A humming arcane shard from the deep vaults.", "stack": 99,
	},
	# --- quest -------------------------------------------------------------
	"warden_sigil": {
		"name": "Warden Sigil", "kind": ItemData.Kind.QUEST, "value": 0, "rarity": 3,
		"desc": "Proof of the Bone Warden's defeat. The guild will want to see it.",
		"stack": 0,
	},
}

## Crafting recipes: output id, ingredient map, gold cost, required rank.
const RECIPES := {
	"healing_potion": {"inputs": {"purple_herb": 2}, "gold": 2, "rank": "F", "xp": 5},
	"mana_potion": {"inputs": {"purple_herb": 1, "crystal_shard": 1}, "gold": 4, "rank": "F", "xp": 6},
	"iron_sword": {"inputs": {"iron_ore": 3, "purple_herb": 1}, "gold": 12, "rank": "F", "xp": 12},
	"battle_axe": {"inputs": {"iron_ore": 4, "wolf_pelt": 1}, "gold": 16, "rank": "E", "xp": 15},
	"guild_leathers": {"inputs": {"wolf_pelt": 2, "purple_herb": 1}, "gold": 10, "rank": "F", "xp": 10},
	"frost_staff": {"inputs": {"crystal_shard": 3, "amber_resin": 1}, "gold": 25, "rank": "E", "xp": 22},
	"elixir": {"inputs": {"purple_herb": 3, "crystal_shard": 2}, "gold": 30, "rank": "D", "xp": 30},
	"bone_plate": {"inputs": {"bone_shard": 4, "iron_ore": 2}, "gold": 28, "rank": "D", "xp": 28},
}


static func create(id: String) -> Resource:
	if not DEFINITIONS.has(id):
		return null
	var spec: Dictionary = DEFINITIONS[id]
	var item := ItemData.new()
	item.id = id
	item.display_name = spec.get("name", id)
	item.kind = spec.get("kind", ItemData.Kind.MATERIAL)
	item.description = spec.get("desc", "")
	item.attack = spec.get("attack", 0.0)
	item.defence = spec.get("defence", 0.0)
	item.power = spec.get("power", 0.0)
	item.heal = spec.get("heal", 0.0)
	item.mana = spec.get("mana", 0.0)
	item.value = spec.get("value", 1)
	item.rarity = spec.get("rarity", 0)
	item.model_path = spec.get("model", "")
	item.max_stack = spec.get("stack", 99)
	item.stackable = item.max_stack > 1
	return item


static func exists(id: String) -> bool:
	return DEFINITIONS.has(id)


static func ids() -> Array[String]:
	var result: Array[String] = []
	for key in DEFINITIONS.keys():
		result.append(key)
	return result


static func display_name(id: String) -> String:
	if not DEFINITIONS.has(id):
		return id.capitalize()
	return DEFINITIONS[id].get("name", id)


static func recipes_for(rank: String) -> Array[String]:
	var result: Array[String] = []
	for key in RECIPES.keys():
		if _rank_index(RECIPES[key].get("rank", "F")) <= _rank_index(rank):
			result.append(key)
	return result


static func _rank_index(rank: String) -> int:
	var order := ["F", "E", "D", "C", "B", "A", "S"]
	return order.find(rank) if rank in order else 0
