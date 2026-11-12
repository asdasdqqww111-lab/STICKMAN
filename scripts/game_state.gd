extends RefCounted
## Mutable rules are independent of the scene and save I/O.
const RankRules = preload("res://scripts/rank_rules.gd")
const Cells = preload("res://scripts/world_cells.gd")
const Waypoints = preload("res://scripts/waypoints.gd")
const XP_BASE := 30
const MAX_HEALTH := 100.0
const MAX_MANA := 50.0
const HERB_TARGET := 3
const HERB_IDS := ["herb_0", "herb_1", "herb_2", "herb_3", "herb_4", "herb_5", "herb_6", "herb_7"]
var level := 1
var xp := 0
var gold := 0
var health := MAX_HEALTH
var mana := MAX_MANA
var kills := 0
var quest := "available" # slime contract
var herb_quest := "locked"
var rank := "F"
var discovered: Array[String] = []
var legacy_discovered: Array[String] = []
var legacy_discovery_credit := 0
var waypoints: Array[String] = []
var defeated: Array[String] = []
var gathered: Array[String] = []
var herbs := 0
var potions := 0
var sword_forged := false
var direction := Vector3(0, 0, 1)
var time_of_day := 0.32

func xp_needed() -> int:
	return XP_BASE + (level - 1) * 20

func gain_xp(amount: int) -> void:
	if amount <= 0: return
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		health = max_health()

func max_health() -> float:
	return MAX_HEALTH + (level - 1) * 10

func slime_count() -> int:
	var total := 0
	for id in defeated:
		if id.begins_with("meadow_slime_"): total += 1
	return total

func completed_contracts() -> int:
	return int(quest == "completed") + int(herb_quest == "completed")

func discovery_count() -> int:
	# Preserve the old exploration milestone even if mapped cell centers collapse.
	return discovered.size() + legacy_discovery_credit

func defeat(id: String) -> bool:
	if id in defeated: return false
	defeated.append(id)
	gain_xp(12)
	gold += 3
	if quest == "active" and id.begins_with("meadow_slime_"):
		kills = mini(3, kills + 1)
		if kills >= 3: quest = "ready"
	return true

func gather(id: String) -> bool:
	if id not in HERB_IDS or id in gathered: return false
	gathered.append(id)
	herbs += 1
	if herb_quest == "active" and gathered.size() >= HERB_TARGET: herb_quest = "ready"
	return true

func interact_guild() -> String:
	match quest:
		"available":
			kills = mini(slime_count(), 3)
			quest = "ready" if kills >= 3 else "active"
			return "Contract ready to claim!" if quest == "ready" else "Guild contract: defeat 3 slimes."
		"active": return "Contract progress: %d / 3 slimes." % kills
		"ready":
			quest = "completed"; herb_quest = "available"
			gold += 20; gain_xp(30)
			return "Contract complete! +20 gold, +30 XP. Talk again."
	if herb_quest == "available":
		herb_quest = "ready" if gathered.size() >= HERB_TARGET else "active"
		return "Herb contract ready to claim!" if herb_quest == "ready" else "New contract: gather 3 purple herbs."
	if herb_quest == "active": return "Herb contract: %d / 3 gathered." % mini(gathered.size(), HERB_TARGET)
	if herb_quest == "ready":
		herb_quest = "completed"; gold += 15; gain_xp(25)
		return "Herb report complete! +15 gold, +25 XP. Talk again for promotion."
	if RankRules.eligible(rank, slime_count(), discovery_count(), completed_contracts(), level):
		rank = RankRules.next_rank(rank)
		return "Guild requirements met! Promoted to rank %s." % rank
	return RankRules.describe(rank)

func craft_potion() -> String:
	if herbs < 2: return "Need 2 herbs to craft a potion."
	herbs -= 2; potions += 1; gain_xp(5)
	return "Crafted a healing potion: -2 herbs, +5 XP."

func use_potion() -> String:
	if potions <= 0: return "No healing potions."
	if health >= max_health(): return "Health is already full."
	potions -= 1; health = minf(max_health(), health + 40.0)
	return "Used a healing potion: +40 HP (up to maximum)."

func forge_sword() -> String:
	if sword_forged: return "Iron sword already equipped."
	if herbs < 2 or gold < 12: return "Iron sword needs 2 herbs and 12 gold."
	herbs -= 2; gold -= 12; sword_forged = true; gain_xp(10)
	return "Iron sword equipped! Melee damage +8."

func melee_damage() -> float:
	return 12.0 + level * 2 + (8.0 if sword_forged else 0.0)

func discover(id: String) -> bool:
	if id in discovered: return false
	discovered.append(id); gain_xp(2)
	return true

func unlock_waypoint(id: String) -> bool:
	if not Waypoints.POINTS.has(id) or id in waypoints: return false
	waypoints.append(id)
	return true

func serialize() -> Dictionary:
	return {"version": 3, "waypoints": waypoints, "legacy_discovered": legacy_discovered, "level": level, "xp": xp, "gold": gold, "health": health, "mana": mana, "kills": kills, "quest": quest, "rank": rank, "discovered": discovered, "defeated": defeated, "direction": [direction.x, direction.y, direction.z], "time_of_day": time_of_day, "herb_quest": herb_quest, "gathered": gathered, "herbs": herbs, "potions": potions, "sword_forged": sword_forged}

func restore(input: Dictionary) -> bool:
	# Migrate old saves on a copy. Validate everything before touching live state.
	var d := input.duplicate(true)
	if d.get("version") == 1:
		d.version = 2
		d.herb_quest = "available" if d.get("quest") == "completed" else "locked"
		d.gathered = []; d.herbs = 0; d.potions = 0; d.sword_forged = false
	if d.get("version") == 2:
		if not d.get("discovered") is Array: return false
		var migrated: Array[String] = []
		var old_cells: Array[String] = []
		for old_id in d.discovered:
			if not old_id is String or old_id in old_cells: return false
			old_cells.append(old_id)
			var id: String = Cells.from_legacy(old_id)
			if id not in migrated: migrated.append(id)
		d.legacy_discovered = old_cells
		d.discovered = migrated
		d.waypoints = []
		d.version = 3
	for key in ["version", "level", "xp", "gold", "health", "mana", "kills", "quest", "rank", "discovered", "defeated", "direction", "time_of_day", "herb_quest", "gathered", "herbs", "potions", "sword_forged", "waypoints", "legacy_discovered"]:
		if not d.has(key): return false
	for key in ["version", "level", "xp", "gold", "health", "mana", "kills", "time_of_day", "herbs", "potions"]:
		if typeof(d[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(d[key]): return false
	for key in ["version", "level", "xp", "gold", "kills", "herbs", "potions"]:
		if d[key] != floor(d[key]): return false
	if d.version != 3 or d.level < 1 or d.level > 1000 or d.xp < 0 or d.xp >= XP_BASE + (int(d.level) - 1) * 20 or d.gold < 0 or d.kills < 0 or d.kills > 3 or d.herbs < 0 or d.potions < 0: return false
	if d.quest not in ["available", "active", "ready", "completed"] or d.rank not in RankRules.ORDER: return false
	if d.herb_quest not in ["locked", "available", "active", "ready", "completed"] or typeof(d.sword_forged) != TYPE_BOOL: return false
	if not (d.discovered is Array and d.defeated is Array and d.gathered is Array and d.waypoints is Array and d.legacy_discovered is Array and d.direction is Array and d.direction.size() == 3): return false
	for list in [d.discovered, d.defeated, d.gathered, d.waypoints, d.legacy_discovered]:
		var seen := {}
		for item in list:
			if not item is String or seen.has(item): return false
			seen[item] = true
	for id in d.gathered:
		if id not in HERB_IDS: return false
	for id in d.waypoints:
		if not Waypoints.POINTS.has(id): return false
	if d.herbs + d.potions * 2 + (2 if d.sword_forged else 0) > d.gathered.size(): return false
	for value in d.direction:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value): return false
	var dir := Vector3(d.direction[0], d.direction[1], d.direction[2])
	if dir.length() < 0.5 or dir.length() > 1.5: return false
	if d.health < 0 or d.health > MAX_HEALTH + (int(d.level) - 1) * 10 or d.mana < 0 or d.mana > MAX_MANA or d.time_of_day < 0 or d.time_of_day >= 1: return false
	level = int(d.level); xp = int(d.xp); gold = int(d.gold)
	health = float(d.health); mana = float(d.mana); kills = int(d.kills)
	quest = d.quest; rank = d.rank; herb_quest = d.herb_quest
	herbs = int(d.herbs); potions = int(d.potions); sword_forged = d.sword_forged
	discovered.assign(d.discovered); defeated.assign(d.defeated); gathered.assign(d.gathered); waypoints.assign(d.waypoints); legacy_discovered.assign(d.legacy_discovered)
	var legacy_mapped := {}
	for id in legacy_discovered: legacy_mapped[Cells.from_legacy(id)] = true
	legacy_discovery_credit = maxi(0, legacy_discovered.size() - legacy_mapped.size())
	direction = dir.normalized(); time_of_day = float(d.time_of_day)
	return true
