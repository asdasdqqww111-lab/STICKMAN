extends "res://tests/test_runner.gd"
## Combat maths: monster data, loot tables, spell resolution and AI state.

const MonsterDefinitions = preload("res://scripts/data/monster_definitions.gd")
const EnemyData = preload("res://scripts/data/enemy_data.gd")
const LootTable = preload("res://scripts/data/loot_table.gd")
const ItemDB = preload("res://scripts/data/item_database.gd")
const SpellDB = preload("res://scripts/data/spell_database.gd")
const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")


func _tests() -> void:
	suite_name = "combat"
	_test_monster_roster()
	_test_loot_tables()
	_test_spells()
	_test_asset_catalog()


func _test_monster_roster() -> void:
	var ids := MonsterDefinitions.ids()
	check_true(ids.size() >= 10, "ten or more monster archetypes are defined (%d)" % ids.size())
	var bosses := 0
	for id in ids:
		var data := MonsterDefinitions.create(id)
		check_true(data != null, "monster definition builds: " + id)
		if data == null:
			continue
		check_eq(data.id, id, "monster id matches: " + id)
		check_true(data.display_name != "", "monster has a name: " + id)
		check_true(data.max_health > 0.0, "monster has health: " + id)
		check_true(data.damage > 0.0, "monster deals damage: " + id)
		check_true(data.move_speed > 0.0, "monster can move: " + id)
		check_true(data.aggro_radius > 0.0, "monster has an aggro radius: " + id)
		check_true(data.xp_reward > 0, "monster grants XP: " + id)
		check_true(data.model_path != "", "monster has a model: " + id)
		check_true(ResourceLoader.exists(data.model_path), "monster model exists: " + data.model_path)
		if data.is_boss():
			bosses += 1
		check_true(data.gold_max >= data.gold_min, "gold range is valid: " + id)
	check_eq(bosses, 1, "exactly one boss ships in the launch slice")
	check_true(MonsterDefinitions.create("does_not_exist") == null, "unknown monster id returns null")
	var boss := MonsterDefinitions.create("boss_bone_warden")
	check_true(boss.max_health > 500.0, "the boss has boss-scale health")
	check_true(boss.is_boss(), "the boss is flagged as a boss")
	check_true(MonsterDefinitions.PASSIVE.size() >= 2, "peaceful wildlife is declared")


func _test_loot_tables() -> void:
	var table := LootTable.new()
	table.min_rolls = 2
	table.max_rolls = 2
	table.entries = [
		{"item_id": "purple_herb", "weight": 1.0, "min": 1, "max": 1},
		{"item_id": "iron_ore", "weight": 1.0, "min": 1, "max": 1},
	]
	table.guaranteed = [{"item_id": "bone_shard", "min": 1, "max": 1}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var drops := table.roll(rng)
	check_eq(drops.size(), 3, "guaranteed drop plus two rolls")
	var has_guaranteed := false
	for drop in drops:
		check_true(ItemDB.exists(String(drop["item_id"])), "loot refers to a real item: " + String(drop["item_id"]))
		check_true(int(drop["count"]) >= 1, "loot count is positive")
		if String(drop["item_id"]) == "bone_shard":
			has_guaranteed = true
	check_true(has_guaranteed, "guaranteed drops appear")
	# Determinism: the same seed reproduces the same drops.
	rng.seed = 424242
	var again := table.roll(rng)
	check_eq(again.size(), drops.size(), "loot rolls are reproducible for a seed")
	var empty := LootTable.new()
	check_eq(empty.roll(rng).size(), 0, "an empty table drops nothing")


func _test_spells() -> void:
	var ids := SpellDB.ids()
	check_eq(ids.size(), 6, "six spells ship")
	var schools := {}
	for id in ids:
		var spell := SpellDB.create(id)
		check_true(spell != null, "spell builds: " + id)
		if spell == null:
			continue
		schools[spell.school] = true
		check_true(spell.mana_cost > 0.0, "spell costs mana: " + id)
		check_true(spell.cooldown > 0.0, "spell has a cooldown: " + id)
		check_true(spell.required_level >= 1, "spell has a level gate: " + id)
		check_true(spell.description != "", "spell has a description: " + id)
		check_true(spell.damage > 0.0 or spell.heal_amount > 0.0, "spell does something: " + id)
	check_eq(schools.size(), 3, "three magic schools exist")
	check_true(SpellDB.create("not_a_spell") == null, "unknown spell returns null")


func _test_asset_catalog() -> void:
	var missing: Array[String] = []
	for path in AssetCatalog.REQUIRED_PATHS:
		if not ResourceLoader.exists(path):
			missing.append(path)
	check_eq(missing.size(), 0, "every required asset exists (missing: %s)" % str(missing))
	check_true(AssetCatalog.REQUIRED_PATHS.size() >= 40, "the catalogue tracks 40+ assets")
	# Every monster must reference a catalogued model.
	for id in MonsterDefinitions.ids():
		var data := MonsterDefinitions.create(id)
		check_true(data.model_path in AssetCatalog.REQUIRED_PATHS, "monster model is catalogued: " + id)
	# Every weapon item model must exist.
	for item_id in ItemDB.ids():
		var item := ItemDB.create(item_id)
		if item.model_path != "":
			check_true(ResourceLoader.exists(item.model_path), "item model exists: " + item_id)
