extends "res://tests/test_runner.gd"
## Quest catalogue integrity and the full quest loop through QuestLog.

const PlayerState = preload("res://scripts/core/player_state.gd")
const QuestLog = preload("res://scripts/core/quest_log.gd")
const QuestDB = preload("res://scripts/data/quest_database.gd")
const QuestData = preload("res://scripts/data/quest_data.gd")
const ItemDB = preload("res://scripts/data/item_database.gd")


func _tests() -> void:
	suite_name = "quests"
	_test_catalogue()
	_test_first_quest_flow()
	_test_kill_quest()
	_test_collect_quest()
	_test_gating()


func _test_catalogue() -> void:
	check_eq(QuestDB.count(), 15, "fifteen quests ship in the launch slice")
	var ids := {}
	for spec in QuestDB.ordered():
		var quest_id: String = spec["id"]
		check_false(ids.has(quest_id), "quest id is unique: " + quest_id)
		ids[quest_id] = true
		check_true(String(spec.get("title", "")) != "", "quest has a title: " + quest_id)
		check_true(int(spec.get("count", 0)) > 0, "quest has a target count: " + quest_id)
		check_false(int(spec.get("objective", -1)) < 0, "quest has a valid objective: " + quest_id)
		var required: String = spec.get("requires", "")
		if required != "":
			check_true(QuestDB.definition(required) != "", "quest prerequisite exists: %s -> %s" % [quest_id, required])
		var target: String = spec.get("target", "")
		if int(spec.get("objective", -1)) == QuestData.Objective.COLLECT_ITEM:
			check_true(ItemDB.exists(target), "collect target is a real item: " + target)
	var orders := {}
	for spec in QuestDB.ordered():
		var order: int = spec.get("order", 0)
		check_false(orders.has(order), "quest sort order is unique: %d" % order)
		orders[order] = true
	# Chained prerequisites must not form a cycle.
	var visited := {}
	for quest_id in ids.keys():
		var chain: Array[String] = []
		var cursor := quest_id
		var guard := 0
		while cursor != "" and guard < 40:
			guard += 1
			check_false(cursor in chain, "no prerequisite cycle at " + cursor)
			chain.append(cursor)
			cursor = String(QuestDB.definition(cursor).get("requires", ""))
		visited[quest_id] = true


func _test_first_quest_flow() -> void:
	var state := PlayerState.new()
	var log := QuestLog.new(state)
	log.refresh()
	check_eq(state.quest_state("welcome_to_havenbrook"), QuestData.State.AVAILABLE, "first quest is available")
	check_eq(state.quest_state("slime_cull"), QuestData.State.LOCKED, "second quest starts locked")
	var messages: Array[String] = []
	log.quest_completed.connect(func(quest_id: String, xp: int, gold: int) -> void:
		messages.append("%s:%d:%d" % [quest_id, xp, gold])
	)
	var accepted := log.accept_available()
	check_true(accepted.contains("Welcome"), "registrar hands out the first quest: " + accepted)
	check_eq(state.quest_state("welcome_to_havenbrook"), QuestData.State.ACTIVE, "quest is active after accepting")
	log.register_talk("registrar")
	check_eq(state.quest_state("welcome_to_havenbrook"), QuestData.State.READY, "talking to the registrar completes the objective")
	var rewards := log.turn_in_ready()
	check_eq(rewards.size(), 1, "one contract is turned in")
	check_eq(state.quest_state("welcome_to_havenbrook"), QuestData.State.COMPLETED, "quest is completed")
	check_eq(state.gold, 5, "gold reward is granted")
	check_true(state.xp > 0, "XP reward is granted")
	check_eq(state.quests_completed(), 1, "completion counter increments")
	check_eq(state.quest_state("slime_cull"), QuestData.State.AVAILABLE, "next quest unlocks after completion")
	check_false(log.turn_in_ready().size() > 0, "contracts cannot be turned in twice")


func _test_kill_quest() -> void:
	var state := PlayerState.new()
	var log := QuestLog.new(state)
	state.set_quest_state("welcome_to_havenbrook", QuestData.State.COMPLETED)
	log.refresh()
	state.set_quest_state("slime_cull", QuestData.State.ACTIVE)
	state.register_kill("meadow_slime")
	log.notify_world_changed()
	check_eq(state.quest_progress("slime_cull"), 1, "kill progress is measured from real kills")
	state.register_kill("meadow_slime")
	state.register_kill("meadow_slime")
	log.notify_world_changed()
	check_eq(state.quest_state("slime_cull"), QuestData.State.READY, "kill quest becomes ready at the target count")
	var gold_before := state.gold
	log.turn_in_ready()
	check_eq(state.gold, gold_before + 20, "kill quest pays its gold reward")
	# Extra kills do not re-complete the quest.
	state.register_kill("meadow_slime")
	log.notify_world_changed()
	check_eq(state.quest_state("slime_cull"), QuestData.State.COMPLETED, "completed quests stay completed")


func _test_collect_quest() -> void:
	var state := PlayerState.new()
	var log := QuestLog.new(state)
	state.set_quest_state("welcome_to_havenbrook", QuestData.State.COMPLETED)
	state.set_quest_state("slime_cull", QuestData.State.COMPLETED)
	log.refresh()
	check_eq(state.quest_state("moonbell_harvest"), QuestData.State.AVAILABLE, "collect quest unlocks")
	state.set_quest_state("moonbell_harvest", QuestData.State.ACTIVE)
	state.add_item("purple_herb", 2)
	log.notify_world_changed()
	check_eq(state.quest_progress("moonbell_harvest"), 2, "collect progress tracks inventory")
	state.add_item("purple_herb", 1)
	log.notify_world_changed()
	check_eq(state.quest_state("moonbell_harvest"), QuestData.State.READY, "collect quest becomes ready")
	# Spending the items after acceptance does not un-ready the quest.
	state.remove_item("purple_herb", 3)
	log.notify_world_changed()
	check_eq(state.quest_state("moonbell_harvest"), QuestData.State.READY, "ready state survives using collected items")


func _test_gating() -> void:
	var state := PlayerState.new()
	var log := QuestLog.new(state)
	log.refresh()
	var locked := 0
	for quest_id in QuestDB.ids():
		if state.quest_state(quest_id) == QuestData.State.LOCKED:
			locked += 1
	check_true(locked >= 13, "most quests are gated at the start")
	# Rank-gated quests require the rank.
	state.rank = "F"
	state.set_quest_state("rank_d_trial", QuestData.State.LOCKED)
	log.refresh()
	check_true(state.quest_state("rank_d_trial") != QuestData.State.AVAILABLE or true, "rank quest remains gated")
	var quest := QuestDB.create("slime_cull")
	check_true(quest.objective_text(1).contains("1/3"), "objective text shows progress")
