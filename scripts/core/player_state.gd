extends RefCounted
## The entire persistent player/world state.
##
## Deliberately free of scene dependencies so it can be unit-tested headlessly:
## every mutation goes through a method, emits a signal, and is serialisable.

signal stats_changed
signal items_changed
signal gold_changed(amount: int, gold_total: int)
signal level_up(new_level: int)
signal rank_changed(new_rank: String, old_rank: String)
signal died
signal spell_unlocked(spell_id: String)
signal notice(text: String)

const ItemDB = preload("res://scripts/data/item_database.gd")
const SpellDB = preload("res://scripts/data/spell_database.gd")
const QuestDB = preload("res://scripts/data/quest_database.gd")
const RankRules = preload("res://scripts/core/rank_rules.gd")

const MAX_LEVEL := 60
const BASE_HEALTH := 100.0
const BASE_MANA := 60.0
const BASE_STAMINA := 100.0
const BASE_ATTACK := 10.0
const BASE_DEFENCE := 0.0

const EQUIP_SLOTS := ["weapon", "offhand", "armour"]

var save_version := 4

# --- identity --------------------------------------------------------------
var hero_name := "Wanderer"

# --- core stats ------------------------------------------------------------
var level := 1
var xp := 0
var health := BASE_HEALTH
var mana := BASE_MANA
var stamina := BASE_STAMINA
var gold := 0

# --- progression -----------------------------------------------------------
var rank := "F"
var reputation := 0

# --- inventory -------------------------------------------------------------
## Array of {"id": String, "count": int}.  Non-stackable items use count 1 + separate rows.
var inventory: Array[Dictionary] = []
## slot -> item id ("" = empty)
var equipment: Dictionary = {"weapon": "rusty_sword", "offhand": "", "armour": ""}

# --- magic / skills --------------------------------------------------------
var known_spells: Array[String] = ["ember_bolt"]
var spell_cooldowns: Dictionary = {}
## Passive skill levels (id -> level), e.g. "toughness", "focus", "swiftness".
var skills: Dictionary = {"toughness": 0, "focus": 0, "swiftness": 0}
var unspent_skill_points := 0

# --- quests ----------------------------------------------------------------
var quests: Dictionary = {}            # quest_id -> {"state": int, "progress": int}
var quest_log_dirty := true

# --- world state -----------------------------------------------------------
var direction := Vector3(0.0, 0.0, 1.0)     # player position on the sphere
var yaw := 0.0                              # player facing (radians, local frame)
var time_of_day := 0.30                     # 0..1, sunrise at 0.25
var day := 1
var discovered: Array[String] = []           # region ids
var waypoints: Array[String] = []            # activated shrine ids
var defeated: Array[String] = []             # persistent enemy instance ids
var gathered: Array[String] = []             # harvested resource node ids
var opened_chests: Array[String] = []
var defeated_bosses: Array[String] = []
var dungeon_cleared := false
var properties: Array[String] = []           # owned buildings / upgrades
var kill_counts: Dictionary = {}             # enemy archetype id -> count
var crafted_counts: Dictionary = {}
var stats := {"kills": 0, "deaths": 0, "quests_completed": 0, "damage_dealt": 0.0, "played_seconds": 0.0}

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	_init_quests()


# ---------------------------------------------------------------------------
# Derived statistics
# ---------------------------------------------------------------------------

func max_health() -> float:
	return BASE_HEALTH + (level - 1) * 12.0 + skills.get("toughness", 0) * 15.0


func max_mana() -> float:
	return BASE_MANA + (level - 1) * 6.0 + skills.get("focus", 0) * 12.0


func max_stamina() -> float:
	return BASE_STAMINA + (level - 1) * 2.0 + skills.get("swiftness", 0) * 10.0


func xp_needed() -> int:
	# Gentle curve: 40, 60, 85, 115, ... capped growth.
	return int(round(40.0 * pow(float(level), 1.35)))


func weapon_item() -> Resource:
	return ItemDB.create(equipment.get("weapon", ""))


func offhand_item() -> Resource:
	return ItemDB.create(equipment.get("offhand", ""))


func armour_item() -> Resource:
	return ItemDB.create(equipment.get("armour", ""))


func attack_power() -> float:
	var total := BASE_ATTACK + (level - 1) * 1.6
	var weapon := weapon_item()
	if weapon != null:
		total += weapon.attack
	var offhand := offhand_item()
	if offhand != null:
		total += offhand.attack
	return total


func spell_power() -> float:
	var focus_skill: float = float(skills.get("focus", 0))
	var total := 1.0 + (level - 1) * 0.06 + focus_skill * 0.08
	var weapon := weapon_item()
	if weapon != null:
		total += weapon.power * 0.05
	var offhand := offhand_item()
	if offhand != null:
		total += offhand.power * 0.05
	return total


func defence() -> float:
	var total := BASE_DEFENCE
	var armour := armour_item()
	if armour != null:
		total += armour.defence
	var offhand := offhand_item()
	if offhand != null:
		total += offhand.defence
	return total


func move_speed() -> float:
	return 4.6 + skills.get("swiftness", 0) * 0.35


func is_alive() -> bool:
	return health > 0.0


func health_ratio() -> float:
	return clampf(health / maxf(1.0, max_health()), 0.0, 1.0)


func mana_ratio() -> float:
	return clampf(mana / maxf(1.0, max_mana()), 0.0, 1.0)


func stamina_ratio() -> float:
	return clampf(stamina / maxf(1.0, max_stamina()), 0.0, 1.0)


# ---------------------------------------------------------------------------
# Experience & levels
# ---------------------------------------------------------------------------

func gain_xp(amount: int) -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		health = max_health()
		mana = max_mana()
		stamina = max_stamina()
		unspent_skill_points += 1
		emit_signal("level_up", level)
		emit_signal("notice", "Level %d reached!" % level)
		_check_spell_unlocks()
	emit_signal("stats_changed")


func spend_skill_point(skill_id: String) -> bool:
	if unspent_skill_points <= 0 or not skills.has(skill_id):
		return false
	if skills[skill_id] >= 5:
		return false
	skills[skill_id] = int(skills[skill_id]) + 1
	unspent_skill_points -= 1
	if skill_id == "toughness":
		health = minf(max_health(), health + 15.0)
	emit_signal("stats_changed")
	emit_signal("notice", "%s improved to %d." % [skill_id.capitalize(), skills[skill_id]])
	return true


# ---------------------------------------------------------------------------
# Health / mana / stamina
# ---------------------------------------------------------------------------

func take_damage(amount: float) -> float:
	if amount <= 0.0 or not is_alive():
		return 0.0
	var mitigated := maxf(1.0, amount - defence() * 0.55)
	health = maxf(0.0, health - mitigated)
	emit_signal("stats_changed")
	if health <= 0.0:
		stats["deaths"] = int(stats.get("deaths", 0)) + 1
		emit_signal("died")
	return mitigated


func heal(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before := health
	health = minf(max_health(), health + amount)
	emit_signal("stats_changed")
	return health - before


func restore_mana(amount: float) -> float:
	var before := mana
	mana = minf(max_mana(), mana + amount)
	emit_signal("stats_changed")
	return mana - before


func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	emit_signal("stats_changed")
	return true


func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	emit_signal("stats_changed")
	return true


func regenerate(delta: float, in_combat: bool) -> void:
	mana = minf(max_mana(), mana + delta * (2.5 if not in_combat else 1.2))
	stamina = minf(max_stamina(), stamina + delta * (12.0 if not in_combat else 6.0))
	if not in_combat:
		health = minf(max_health(), health + delta * 0.6)
	emit_signal("stats_changed")


## Respawn after death: half health, full mana, keep all progression.
func revive_at(respawn_direction: Vector3) -> void:
	health = maxf(1.0, max_health() * 0.6)
	mana = max_mana()
	stamina = max_stamina()
	direction = respawn_direction.normalized()
	emit_signal("stats_changed")


# ---------------------------------------------------------------------------
# Gold
# ---------------------------------------------------------------------------

func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold = maxi(0, gold + amount)
	emit_signal("gold_changed", amount, gold)
	emit_signal("stats_changed")


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	emit_signal("gold_changed", -amount, gold)
	emit_signal("stats_changed")
	return true


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

func item_count(item_id: String) -> int:
	var total := 0
	for row in inventory:
		if row.get("id", "") == item_id:
			total += int(row.get("count", 0))
	return total


func has_item(item_id: String, amount: int = 1) -> bool:
	return item_count(item_id) >= amount


func add_item(item_id: String, count: int = 1) -> bool:
	if count <= 0 or not ItemDB.exists(item_id):
		return false
	var definition := ItemDB.create(item_id)
	if definition == null:
		return false
	var remaining := count
	if definition.stackable:
		for row in inventory:
			if row.get("id", "") != item_id:
				continue
			var space: int = definition.max_stack - int(row.get("count", 0))
			if space <= 0:
				continue
			var moved := mini(space, remaining)
			row["count"] = int(row["count"]) + moved
			remaining -= moved
			if remaining <= 0:
				break
	while remaining > 0:
		var chunk := mini(definition.max_stack, remaining) if definition.stackable else 1
		inventory.append({"id": item_id, "count": chunk})
		remaining -= chunk
	emit_signal("items_changed")
	return true


func remove_item(item_id: String, count: int = 1) -> bool:
	if count <= 0 or item_count(item_id) < count:
		return false
	var remaining := count
	for index in range(inventory.size() - 1, -1, -1):
		var row := inventory[index]
		if row.get("id", "") != item_id:
			continue
		var taken := mini(int(row.get("count", 0)), remaining)
		row["count"] = int(row["count"]) - taken
		remaining -= taken
		if int(row["count"]) <= 0:
			inventory.remove_at(index)
		if remaining <= 0:
			break
	emit_signal("items_changed")
	return true


func inventory_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row in inventory:
		if int(row.get("count", 0)) > 0:
			rows.append(row)
	return rows


func inventory_slots_used() -> int:
	return inventory_rows().size()


func equip(item_id: String) -> bool:
	if not ItemDB.exists(item_id) or not has_item(item_id):
		return false
	var definition := ItemDB.create(item_id)
	if definition == null or not definition.is_equipment():
		return false
	var slot := "weapon" if definition.is_weapon() else "armour"
	if definition.is_armour() and item_id == "round_shield":
		slot = "offhand"
	# Two-handed weapons free the offhand slot.
	if definition.is_weapon() and definition.model_path.contains("2handed"):
		unequip("offhand")
	var previous: String = equipment.get(slot, "")
	remove_item(item_id, 1)
	if previous != "":
		add_item(previous, 1)
	equipment[slot] = item_id
	emit_signal("items_changed")
	emit_signal("stats_changed")
	emit_signal("notice", "Equipped %s." % definition.display_name)
	return true


func unequip(slot: String) -> bool:
	if not equipment.has(slot):
		return false
	var current: String = equipment[slot]
	if current == "":
		return false
	add_item(current, 1)
	equipment[slot] = ""
	emit_signal("items_changed")
	emit_signal("stats_changed")
	return true


func use_item(item_id: String) -> String:
	if not has_item(item_id):
		return "You have no %s." % ItemDB.display_name(item_id)
	var definition := ItemDB.create(item_id)
	if definition == null:
		return "Unknown item."
	if definition.is_equipment():
		if equip(item_id):
			return "Equipped %s." % definition.display_name
		return "Cannot equip that."
	if definition.heal <= 0.0 and definition.mana <= 0.0:
		return "%s cannot be used directly." % definition.display_name
	if definition.heal > 0.0 and health >= max_health() and definition.mana <= 0.0:
		return "Health is already full."
	remove_item(item_id, 1)
	var gained := ""
	if definition.heal > 0.0:
		gained += "+%d HP " % int(heal(definition.heal))
	if definition.mana > 0.0:
		gained += "+%d MP" % int(restore_mana(definition.mana))
	emit_signal("notice", "Used %s: %s" % [definition.display_name, gained.strip_edges()])
	return "Used %s: %s" % [definition.display_name, gained.strip_edges()]


func sell_price(item_id: String) -> int:
	if not ItemDB.exists(item_id):
		return 0
	return maxi(1, int(round(float(ItemDB.DEFINITIONS[item_id].get("value", 1)) * 0.45)))


func sell_item(item_id: String, count: int = 1) -> bool:
	if not remove_item(item_id, count):
		return false
	add_gold(sell_price(item_id) * count)
	return true


# ---------------------------------------------------------------------------
# Crafting
# ---------------------------------------------------------------------------

func can_craft(recipe_id: String) -> bool:
	if not ItemDB.RECIPES.has(recipe_id):
		return false
	var recipe: Dictionary = ItemDB.RECIPES[recipe_id]
	if not RankRules.at_least(rank, recipe.get("rank", "F")):
		return false
	for input_id in recipe.get("inputs", {}).keys():
		if not has_item(input_id, int(recipe["inputs"][input_id])):
			return false
	return gold >= int(recipe.get("gold", 0))


func craft(recipe_id: String) -> String:
	if not ItemDB.RECIPES.has(recipe_id):
		return "Unknown recipe."
	if not can_craft(recipe_id):
		var recipe: Dictionary = ItemDB.RECIPES[recipe_id]
		if not RankRules.at_least(rank, recipe.get("rank", "F")):
			return "Requires guild rank %s." % recipe.get("rank", "F")
		if gold < int(recipe.get("gold", 0)):
			return "Not enough gold."
		return "Missing materials."
	var recipe: Dictionary = ItemDB.RECIPES[recipe_id]
	for input_id in recipe["inputs"].keys():
		remove_item(input_id, int(recipe["inputs"][input_id]))
	spend_gold(int(recipe.get("gold", 0)))
	add_item(recipe_id, 1)
	crafted_counts[recipe_id] = int(crafted_counts.get(recipe_id, 0)) + 1
	gain_xp(int(recipe.get("xp", 5)))
	return "Crafted %s." % ItemDB.display_name(recipe_id)


func craftable_recipes() -> Array[String]:
	var result: Array[String] = []
	for recipe_id in ItemDB.RECIPES.keys():
		if can_craft(recipe_id):
			result.append(recipe_id)
	return result


# ---------------------------------------------------------------------------
# Magic
# ---------------------------------------------------------------------------

func knows_spell(spell_id: String) -> bool:
	return spell_id in known_spells


func unlock_spell(spell_id: String) -> bool:
	if not SpellDB.exists(spell_id) or spell_id in known_spells:
		return false
	var spell := SpellDB.create(spell_id)
	if spell == null:
		return false
	if level < spell.required_level or not RankRules.at_least(rank, spell.required_rank):
		return false
	known_spells.append(spell_id)
	emit_signal("spell_unlocked", spell_id)
	emit_signal("notice", "New spell learned: %s" % spell.display_name)
	return true


func _check_spell_unlocks() -> void:
	for spell_id in SpellDB.ids():
		if spell_id in known_spells:
			continue
		var spell := SpellDB.create(spell_id)
		if spell == null:
			continue
		if level >= spell.required_level and RankRules.at_least(rank, spell.required_rank):
			unlock_spell(spell_id)


func spell_damage(spell_id: String) -> float:
	var spell := SpellDB.create(spell_id)
	if spell == null:
		return 0.0
	return spell.damage * spell_power()


func spell_ready(spell_id: String, now: float) -> bool:
	return now >= float(spell_cooldowns.get(spell_id, 0.0))


func start_spell_cooldown(spell_id: String, now: float) -> void:
	var spell := SpellDB.create(spell_id)
	if spell == null:
		return
	spell_cooldowns[spell_id] = now + spell.cooldown


# ---------------------------------------------------------------------------
# Ranks & reputation
# ---------------------------------------------------------------------------

func quests_completed() -> int:
	var total := 0
	for quest_id in quests.keys():
		if int(quests[quest_id].get("state", 0)) == 4:
			total += 1
	return total


func add_reputation(amount: int) -> void:
	reputation += amount


func rank_requirements() -> Dictionary:
	return RankRules.requirements_for_next(rank, stats, discovered.size(), quests_completed(), level, reputation)


func can_promote() -> bool:
	return RankRules.eligible_for_next(rank, stats, discovered.size(), quests_completed(), level, reputation)


func try_promote() -> bool:
	if not can_promote():
		return false
	var old := rank
	rank = RankRules.next_rank(rank)
	if rank == "":
		rank = old
		return false
	emit_signal("rank_changed", rank, old)
	emit_signal("notice", "Promoted to guild rank %s!" % rank)
	_check_spell_unlocks()
	return true


# ---------------------------------------------------------------------------
# World facts
# ---------------------------------------------------------------------------

func discover(region_id: String) -> bool:
	if region_id == "" or region_id in discovered:
		return false
	discovered.append(region_id)
	gain_xp(3)
	return true


func unlock_waypoint(waypoint_id: String) -> bool:
	if waypoint_id == "" or waypoint_id in waypoints:
		return false
	waypoints.append(waypoint_id)
	gain_xp(8)
	return true


func register_kill(enemy_archetype: String) -> void:
	kill_counts[enemy_archetype] = int(kill_counts.get(enemy_archetype, 0)) + 1
	stats["kills"] = int(stats.get("kills", 0)) + 1


func total_kills_of(archetype: String) -> int:
	return int(kill_counts.get(archetype, 0))


func register_damage(amount: float) -> void:
	stats["damage_dealt"] = float(stats.get("damage_dealt", 0.0)) + amount


func owns_property(property_id: String) -> bool:
	return property_id in properties


func buy_property(property_id: String, cost: int) -> bool:
	if owns_property(property_id) or not spend_gold(cost):
		return false
	properties.append(property_id)
	return true


# ---------------------------------------------------------------------------
# Quests
# ---------------------------------------------------------------------------

func _init_quests() -> void:
	for quest_id in QuestDB.ids():
		quests[quest_id] = {"state": 0, "progress": 0}
	# The first quest is available from the start (the registrar introduces it).
	if quests.has("welcome_to_havenbrook"):
		quests["welcome_to_havenbrook"]["state"] = 1


func quest_state(quest_id: String) -> int:
	if not quests.has(quest_id):
		return 0
	return int(quests[quest_id].get("state", 0))


func set_quest_state(quest_id: String, new_state: int) -> void:
	if not quests.has(quest_id):
		return
	quests[quest_id]["state"] = new_state
	quest_log_dirty = true


func quest_progress(quest_id: String) -> int:
	if not quests.has(quest_id):
		return 0
	return int(quests[quest_id].get("progress", 0))


func set_quest_progress(quest_id: String, value: int) -> void:
	if not quests.has(quest_id):
		return
	quests[quest_id]["progress"] = value
	quest_log_dirty = true


func active_quest_ids() -> Array[String]:
	var result: Array[String] = []
	for quest_id in quests.keys():
		var state := int(quests[quest_id].get("state", 0))
		if state == 2 or state == 3:
			result.append(quest_id)
	return result


func available_quest_ids() -> Array[String]:
	var result: Array[String] = []
	for quest_id in quests.keys():
		if int(quests[quest_id].get("state", 0)) == 1:
			result.append(quest_id)
	return result


# ---------------------------------------------------------------------------
# Serialisation (the save schema lives here; SaveGame owns IO/migration)
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var quest_rows := {}
	for quest_id in quests.keys():
		quest_rows[quest_id] = {
			"state": int(quests[quest_id].get("state", 0)),
			"progress": int(quests[quest_id].get("progress", 0)),
		}
	var cooldowns := {}
	for spell_id in spell_cooldowns.keys():
		cooldowns[spell_id] = float(spell_cooldowns[spell_id])
	return {
		"version": save_version,
		"hero_name": hero_name,
		"level": level,
		"xp": xp,
		"health": health,
		"mana": mana,
		"stamina": stamina,
		"gold": gold,
		"rank": rank,
		"reputation": reputation,
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"known_spells": known_spells.duplicate(),
		"skills": skills.duplicate(),
		"unspent_skill_points": unspent_skill_points,
		"quests": quest_rows,
		"direction": [direction.x, direction.y, direction.z],
		"yaw": yaw,
		"time_of_day": time_of_day,
		"day": day,
		"discovered": discovered.duplicate(),
		"waypoints": waypoints.duplicate(),
		"defeated": defeated.duplicate(),
		"gathered": gathered.duplicate(),
		"opened_chests": opened_chests.duplicate(),
		"defeated_bosses": defeated_bosses.duplicate(),
		"dungeon_cleared": dungeon_cleared,
		"properties": properties.duplicate(),
		"kill_counts": kill_counts.duplicate(),
		"crafted_counts": crafted_counts.duplicate(),
		"stats": stats.duplicate(),
		"spell_cooldowns": cooldowns,
	}


## Restore from a *validated, migrated* dictionary.  Returns false on bad data
## without mutating any live state.
func restore(data: Dictionary) -> bool:
	var next: RefCounted = get_script().new()
	next.hero_name = String(data.get("hero_name", "Wanderer"))
	next.level = int(data.get("level", 1))
	next.xp = int(data.get("xp", 0))
	next.health = float(data.get("health", BASE_HEALTH))
	next.mana = float(data.get("mana", BASE_MANA))
	next.stamina = float(data.get("stamina", BASE_STAMINA))
	next.gold = int(data.get("gold", 0))
	next.rank = String(data.get("rank", "F"))
	next.reputation = int(data.get("reputation", 0))
	next.inventory = _copy_rows(data.get("inventory", []))
	next.equipment = {
		"weapon": String(data.get("equipment", {}).get("weapon", "")),
		"offhand": String(data.get("equipment", {}).get("offhand", "")),
		"armour": String(data.get("equipment", {}).get("armour", "")),
	}
	next.known_spells = _copy_strings(data.get("known_spells", []))
	next.skills = {}
	for key in skills.keys():
		next.skills[key] = int(data.get("skills", {}).get(key, 0))
	next.unspent_skill_points = int(data.get("unspent_skill_points", 0))
	next.quests = {}
	for quest_id in QuestDB.ids():
		var row: Dictionary = data.get("quests", {}).get(quest_id, {})
		next.quests[quest_id] = {"state": int(row.get("state", 0)), "progress": int(row.get("progress", 0))}
	next.direction = _to_direction(data.get("direction", [0.0, 0.0, 1.0]))
	next.yaw = float(data.get("yaw", 0.0))
	next.time_of_day = float(data.get("time_of_day", 0.3))
	next.day = maxi(1, int(data.get("day", 1)))
	next.discovered = _copy_strings(data.get("discovered", []))
	next.waypoints = _copy_strings(data.get("waypoints", []))
	next.defeated = _copy_strings(data.get("defeated", []))
	next.gathered = _copy_strings(data.get("gathered", []))
	next.opened_chests = _copy_strings(data.get("opened_chests", []))
	next.defeated_bosses = _copy_strings(data.get("defeated_bosses", []))
	next.dungeon_cleared = bool(data.get("dungeon_cleared", false))
	next.properties = _copy_strings(data.get("properties", []))
	next.kill_counts = data.get("kill_counts", {}).duplicate(true)
	next.crafted_counts = data.get("crafted_counts", {}).duplicate(true)
	next.stats = data.get("stats", {}).duplicate(true)
	next.spell_cooldowns = {}
	next.health = clampf(next.health, 0.0, next.max_health())
	next.mana = clampf(next.mana, 0.0, next.max_mana())
	next.stamina = clampf(next.stamina, 0.0, next.max_stamina())
	if not validate(next):
		return false
	_assign_from(next)
	emit_signal("stats_changed")
	emit_signal("items_changed")
	return true


static func validate(candidate: RefCounted) -> bool:
	if candidate.level < 1 or candidate.level > MAX_LEVEL:
		return false
	if candidate.xp < 0 or candidate.xp >= candidate.xp_needed():
		return false
	if candidate.gold < 0 or candidate.reputation < 0:
		return false
	if not RankRules.ORDER.has(candidate.rank):
		return false
	if candidate.direction.length_squared() < 0.5:
		return false
	for row in candidate.inventory:
		if not ItemDB.exists(String(row.get("id", ""))):
			return false
		if int(row.get("count", 0)) <= 0:
			return false
	for slot in candidate.equipment.keys():
		var item_id: String = candidate.equipment[slot]
		if item_id != "" and not ItemDB.exists(item_id):
			return false
	for spell_id in candidate.known_spells:
		if not SpellDB.exists(spell_id):
			return false
	if candidate.waypoints.size() > 64 or candidate.discovered.size() > 4096:
		return false
	return true


func _assign_from(other: RefCounted) -> void:
	hero_name = other.hero_name
	level = other.level
	xp = other.xp
	health = other.health
	mana = other.mana
	stamina = other.stamina
	gold = other.gold
	rank = other.rank
	reputation = other.reputation
	inventory = other.inventory
	equipment = other.equipment
	known_spells = other.known_spells
	skills = other.skills
	unspent_skill_points = other.unspent_skill_points
	quests = other.quests
	direction = other.direction
	yaw = other.yaw
	time_of_day = other.time_of_day
	day = other.day
	discovered = other.discovered
	waypoints = other.waypoints
	defeated = other.defeated
	gathered = other.gathered
	opened_chests = other.opened_chests
	defeated_bosses = other.defeated_bosses
	dungeon_cleared = other.dungeon_cleared
	properties = other.properties
	kill_counts = other.kill_counts
	crafted_counts = other.crafted_counts
	stats = other.stats
	spell_cooldowns = other.spell_cooldowns


func _copy_rows(source: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not source is Array:
		return rows
	for row in source:
		if row is Dictionary:
			rows.append({"id": String(row.get("id", "")), "count": int(row.get("count", 0))})
	return rows


func _copy_strings(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if not source is Array:
		return result
	for value in source:
		if value is String and value not in result:
			result.append(value)
	return result


func _to_direction(source: Variant) -> Vector3:
	if not source is Array or source.size() != 3:
		return Vector3(0.0, 0.0, 1.0)
	var vector := Vector3(float(source[0]), float(source[1]), float(source[2]))
	if vector.length_squared() < 0.5 or not is_finite(vector.length()):
		return Vector3(0.0, 0.0, 1.0)
	return vector.normalized()
