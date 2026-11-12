extends "res://tests/test_runner.gd"
## Player stats, XP curve, inventory, equipment, crafting, magic and rank rules.

const PlayerState = preload("res://scripts/core/player_state.gd")
const RankRules = preload("res://scripts/core/rank_rules.gd")
const ItemDB = preload("res://scripts/data/item_database.gd")
const SpellDB = preload("res://scripts/data/spell_database.gd")


func _tests() -> void:
	suite_name = "player"
	_test_initial_state()
	_test_xp_and_levels()
	_test_inventory()
	_test_equipment()
	_test_crafting()
	_test_magic()
	_test_damage_and_healing()
	_test_rank_rules()


func _test_initial_state() -> void:
	var state := PlayerState.new()
	check_eq(state.level, 1, "new player starts at level 1")
	check_eq(state.xp, 0, "new player starts with 0 XP")
	check_eq(state.gold, 0, "new player starts with 0 gold")
	check_eq(state.rank, "F", "new player starts at rank F")
	check_near(state.health, state.max_health(), 0.001, "new player starts at full health")
	check_eq(state.equipment.get("weapon", ""), "rusty_sword", "new player owns the starter sword")
	check_true("ember_bolt" in state.known_spells, "new player knows one spell")
	check_eq(state.inventory.size(), 0, "new inventory is empty")
	check_true(state.is_alive(), "new player is alive")
	check_eq(state.xp_needed(), 40, "level 1 requires 40 XP")
	check_true(state.can_promote() == false, "new player cannot promote immediately")


func _test_xp_and_levels() -> void:
	var state := PlayerState.new()
	state.gain_xp(39)
	check_eq(state.level, 1, "39 XP is not enough to level up")
	state.gain_xp(1)
	check_eq(state.level, 2, "40 XP levels up once")
	check_eq(state.xp, 0, "leftover XP is carried correctly")
	check_near(state.max_health(), 112.0, 0.001, "max health grows with level")
	var levels := 0
	state.gain_xp(100000)
	check_true(state.level > 2, "large XP grants levels")
	check_true(state.level <= PlayerState.MAX_LEVEL, "level is capped")
	check_true(state.xp < state.xp_needed(), "XP remainder stays below the next threshold")
	check_true(state.unspent_skill_points > 0, "level ups grant skill points")
	# Skill points actually change derived stats.
	var before := state.max_health()
	var spent := state.spend_skill_point("toughness")
	check_true(spent, "skill point can be spent")
	check_true(state.max_health() > before, "toughness raises max health")
	check_false(state.spend_skill_point("nonexistent"), "unknown skill cannot be upgraded")


func _test_inventory() -> void:
	var state := PlayerState.new()
	check_true(state.add_item("purple_herb", 3), "adding a known item succeeds")
	check_eq(state.item_count("purple_herb"), 3, "item count reflects the add")
	check_false(state.add_item("not_an_item", 1), "unknown items cannot be added")
	check_false(state.add_item("purple_herb", 0), "adding zero is rejected")
	check_true(state.remove_item("purple_herb", 2), "removing held items succeeds")
	check_eq(state.item_count("purple_herb"), 1, "removal updates the count")
	check_false(state.remove_item("purple_herb", 5), "cannot remove more than held")
	# Stack overflow creates a second row.
	state.add_item("purple_herb", 250)
	check_true(state.inventory.size() >= 3, "stack overflow creates extra rows")
	check_eq(state.item_count("purple_herb"), 251, "total count survives stacking")
	# Non-stackable items keep separate rows.
	state.add_item("warden_sigil", 1)
	state.add_item("warden_sigil", 1)
	check_eq(state.item_count("warden_sigil"), 2, "non-stackable items accumulate as rows")
	# Consumables heal for their declared amount.
	state.health = 10.0
	state.add_item("healing_potion", 1)
	var message := state.use_item("healing_potion")
	check_true(state.health > 10.0, "healing potion restores health: " + message)
	check_eq(state.item_count("healing_potion"), 0, "used potion is consumed")
	check_eq(state.use_item("healing_potion"), "You have no Healing Potion.", "using a missing item reports it")


func _test_equipment() -> void:
	var state := PlayerState.new()
	var base_attack := state.attack_power()
	check_true(state.add_item("iron_sword", 1), "can hold an iron sword")
	check_true(state.equip("iron_sword"), "iron sword equips")
	check_eq(state.equipment["weapon"], "iron_sword", "weapon slot updated")
	check_true(state.attack_power() > base_attack, "equipping a weapon raises attack")
	check_false(state.has_item("iron_sword"), "equipped item leaves the bag")
	check_eq(state.item_count("rusty_sword"), 1, "previous weapon returns to the bag")
	var defense_before := state.defence()
	state.add_item("bone_plate", 1)
	check_true(state.equip("bone_plate"), "armour equips")
	check_true(state.defence() > defense_before, "armour raises defence")
	check_true(state.unequip("armour"), "armour can be unequipped")
	check_eq(state.equipment["armour"], "", "armour slot is empty again")
	check_false(state.equip("purple_herb"), "materials cannot be equipped")
	# Two-handed weapon clears the offhand.
	state.add_item("round_shield", 1)
	state.equip("round_shield")
	check_eq(state.equipment["offhand"], "round_shield", "shield equips to the offhand")
	state.add_item("greatsword", 1)
	state.equip("greatsword")
	check_eq(state.equipment["offhand"], "", "two-handed weapon clears the offhand")
	check_eq(state.equipment["weapon"], "greatsword", "two-handed weapon equips")


func _test_crafting() -> void:
	var state := PlayerState.new()
	check_false(state.can_craft("guild_leathers"), "cannot craft without materials")
	state.add_item("wolf_pelt", 2)
	state.add_item("purple_herb", 1)
	check_false(state.can_craft("guild_leathers"), "cannot craft without gold")
	state.add_gold(10)
	check_true(state.can_craft("guild_leathers"), "crafting becomes possible with materials and gold")
	var message := state.craft("guild_leathers")
	check_true(message.begins_with("Crafted"), "craft reports success: " + message)
	check_eq(state.item_count("guild_leathers"), 1, "crafted item enters the bag")
	check_eq(state.item_count("wolf_pelt"), 0, "inputs are consumed")
	check_eq(state.gold, 0, "gold cost is charged")
	check_eq(int(state.crafted_counts.get("guild_leathers", 0)), 1, "crafting is tracked for quests")
	check_false(state.can_craft("bone_plate"), "rank-gated recipe blocked at rank F")
	check_eq(state.craft("unknown_recipe"), "Unknown recipe.", "unknown recipe is rejected")


func _test_magic() -> void:
	var state := PlayerState.new()
	var spell := SpellDB.create("ember_bolt")
	check_true(spell != null, "ember bolt exists")
	check_eq(spell.mana_cost, 8.0, "ember bolt mana cost matches data")
	check_false(state.knows_spell("flame_wave"), "flame wave is not known at level 1")
	check_false(state.unlock_spell("flame_wave"), "spells respect level and rank gates")
	var damage := state.spell_damage("ember_bolt")
	check_true(damage > 0.0, "spell damage derives from spell power")
	check_true(state.spell_ready("ember_bolt", 0.0), "spell starts off cooldown")
	state.start_spell_cooldown("ember_bolt", 0.0)
	check_false(state.spell_ready("ember_bolt", 0.5), "cooldown blocks recasting")
	check_true(state.spell_ready("ember_bolt", 5.0), "cooldown expires")
	check_true(state.spend_mana(8.0), "mana can be spent")
	check_eq(state.mana, state.max_mana() - 8.0, "mana decreases")
	check_false(state.spend_mana(9999.0), "cannot overspend mana")
	# Levelling unlocks the next spell tier automatically.
	state.gain_xp(100000)
	check_true(state.level >= 4, "levelled enough for flame wave")
	check_true(state.knows_spell("frost_bolt"), "frost bolt unlocked by level")
	check_eq(SpellDB.ids().size(), 6, "six spells ship in the roster")


func _test_damage_and_healing() -> void:
	var state := PlayerState.new()
	state.add_item("bone_plate", 1)
	state.equip("bone_plate")
	var defence := state.defence()
	var applied := state.take_damage(30.0)
	check_true(applied < 30.0, "armour mitigates damage")
	check_true(applied > 0.0, "damage is never fully negated")
	check_near(applied, 30.0 - defence * 0.55, 0.01, "mitigation formula matches defence")
	var healed := state.heal(10.0)
	check_true(healed > 0.0, "healing works")
	var missing := state.max_health() - state.health
	check_near(state.heal(9999.0), missing, 0.01, "healing is capped at max health")
	# Death.
	var deaths := int(state.stats.get("deaths", 0))
	state.take_damage(9999.0)
	check_false(state.is_alive(), "lethal damage kills the player")
	check_eq(int(state.stats.get("deaths", 0)), deaths + 1, "death is counted")
	state.revive_at(Vector3(0, 0, 1))
	check_true(state.is_alive(), "revive restores the player")
	check_true(state.health < state.max_health(), "revive restores partial health")
	check_near(state.mana, state.max_mana(), 0.01, "revive restores full mana")


func _test_rank_rules() -> void:
	check_eq(RankRules.next_rank("F"), "E", "F promotes to E")
	check_eq(RankRules.next_rank("E"), "D", "E promotes to D")
	check_eq(RankRules.next_rank("S"), "", "S has no next rank")
	check_true(RankRules.at_least("D", "F"), "D is at least F")
	check_false(RankRules.at_least("F", "D"), "F is not at least D")
	check_false(RankRules.at_least("X", "F"), "unknown rank comparisons fail safely")
	var stats := {"kills": 8}
	check_false(RankRules.eligible_for_next("F", stats, 0, 0, 1, 0), "rank E needs more than kills")
	check_true(RankRules.eligible_for_next("F", stats, 4, 3, 3, 10), "rank E requirements can be met")
	var described := RankRules.describe("F", stats, 0, 0, 1, 0)
	check_true(described.contains("Rank E"), "description names the next rank")
	# Promotion through the state object.
	var state := PlayerState.new()
	state.gain_xp(100000)
	state.stats["kills"] = 50
	state.reputation = 100
	for i in range(20):
		state.discover("pz:%d:%d" % [i % 12, i / 12])
		state.craft("healing_potion")
	var quests := 0
	for quest_id in state.quests.keys():
		if quests >= 12:
			break
		state.set_quest_state(quest_id, 4)
		quests += 1
	check_true(state.can_promote(), "fully qualified player can promote")
	check_true(state.try_promote(), "promotion succeeds")
	check_eq(state.rank, "E", "rank advanced to E")
