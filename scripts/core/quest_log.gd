extends RefCounted
## Evaluates quest objectives against real gameplay events.
##
## QuestLog owns *no* state: every value is read from / written to PlayerState so
## saving and loading remain a single serialisation path.

signal quest_available(quest_id: String)
signal quest_started(quest_id: String)
signal quest_ready(quest_id: String)
signal quest_completed(quest_id: String, xp: int, gold: int)
signal objective_progress(quest_id: String, progress: int, target: int)

const QuestDB = preload("res://scripts/data/quest_database.gd")
const QuestData = preload("res://scripts/data/quest_data.gd")
const ItemDB = preload("res://scripts/data/item_database.gd")
const RankRules = preload("res://scripts/core/rank_rules.gd")

var state: RefCounted


func _init(player_state: RefCounted = null) -> void:
	state = player_state


## Recompute availability after any progress change (rank, discovery, predecessors).
func refresh() -> void:
	if state == null:
		return
	for spec in QuestDB.ordered():
		var quest_id: String = spec.get("id", "")
		var current: int = state.quest_state(quest_id)
		if current == QuestData.State.LOCKED and _requirements_met(spec):
			state.set_quest_state(quest_id, QuestData.State.AVAILABLE)
			emit_signal("quest_available", quest_id)
		elif current == QuestData.State.AVAILABLE and not _requirements_met(spec):
			state.set_quest_state(quest_id, QuestData.State.LOCKED)
	_update_progress()


func _requirements_met(spec: Dictionary) -> bool:
	var required_quest: String = spec.get("requires", "")
	if required_quest != "" and state.quest_state(required_quest) != QuestData.State.COMPLETED:
		return false
	var required_rank: String = spec.get("rank", "F")
	if not RankRules.at_least(state.rank, required_rank):
		return false
	var required_level: int = spec.get("level", 1)
	if state.level < required_level:
		return false
	return true


## Recompute the progress counter of every active/ready quest from world facts.
func _update_progress() -> void:
	for quest_id in state.quests.keys():
		var current: int = state.quest_state(quest_id)
		if current != QuestData.State.ACTIVE and current != QuestData.State.READY:
			continue
		var spec := QuestDB.definition(quest_id)
		if spec.is_empty():
			continue
		var progress := measure(spec)
		state.set_quest_progress(quest_id, progress)
		var target: int = spec.get("count", 1)
		if progress >= target and current == QuestData.State.ACTIVE:
			state.set_quest_state(quest_id, QuestData.State.READY)
			emit_signal("quest_ready", quest_id)


## Convert world facts into an objective count for one quest definition.
func measure(spec: Dictionary) -> int:
	match int(spec.get("objective", -1)):
		QuestData.Objective.KILL_ENEMY:
			return state.total_kills_of(String(spec.get("target", "")))
		QuestData.Objective.DEFEAT_BOSS:
			return 1 if String(spec.get("target", "")) in state.defeated_bosses else 0
		QuestData.Objective.COLLECT_ITEM:
			return state.item_count(String(spec.get("target", "")))
		QuestData.Objective.DISCOVER_REGION:
			return state.discovered.size()
		QuestData.Objective.LIGHT_SHRINE:
			return state.waypoints.size()
		QuestData.Objective.REACH_RANK:
			return 1 if RankRules.at_least(state.rank, String(spec.get("target", "F"))) else 0
		QuestData.Objective.CRAFT_ITEM:
			return int(state.crafted_counts.get(String(spec.get("target", "")), 0))
		QuestData.Objective.ENTER_DUNGEON:
			return 1 if state.dungeon_cleared else 0
		QuestData.Objective.TALK_NPC:
			return int(state.stats.get("talked_" + String(spec.get("target", "")), 0))
	return 0


## Called by the registrar when the player interacts with them.
func accept_available() -> String:
	refresh()
	var available: Array[String] = state.available_quest_ids()
	if available.is_empty():
		return ""
	# Only one quest per giver conversation; pick the lowest sort order.
	var best := ""
	var best_order := 9999
	for quest_id in available:
		var spec := QuestDB.definition(quest_id)
		var order: int = spec.get("order", 0)
		if order < best_order:
			best = quest_id
			best_order = order
	if best == "":
		return ""
	state.set_quest_state(best, QuestData.State.ACTIVE)
	emit_signal("quest_started", best)
	_update_progress()
	var spec := QuestDB.definition(best)
	return "New contract: %s — %s" % [spec.get("title", best), spec.get("giver_text", "")]


## Turn in every READY quest claimed at the registrar.  Returns a summary line.
func turn_in_ready() -> Array[Dictionary]:
	refresh()
	var rewards: Array[Dictionary] = []
	for quest_id in QuestDB.ids():
		if state.quest_state(quest_id) != QuestData.State.READY:
			continue
		var spec := QuestDB.definition(quest_id)
		state.set_quest_state(quest_id, QuestData.State.COMPLETED)
		state.stats["quests_completed"] = int(state.stats.get("quests_completed", 0)) + 1
		var xp: int = spec.get("xp", 0)
		var gold: int = spec.get("gold", 0)
		state.gain_xp(xp)
		state.add_gold(gold)
		state.add_reputation(2)
		rewards.append({"id": quest_id, "title": spec.get("title", quest_id), "xp": xp, "gold": gold})
		emit_signal("quest_completed", quest_id, xp, gold)
	refresh()
	return rewards


## Called whenever gameplay facts change (kill, pickup, discovery, craft, rank).
func notify_world_changed() -> void:
	refresh()


func register_talk(npc_id: String) -> void:
	state.stats["talked_" + npc_id] = int(state.stats.get("talked_" + npc_id, 0)) + 1
	refresh()


func active_summaries() -> Array[String]:
	var lines: Array[String] = []
	refresh()
	for quest_id in state.active_quest_ids():
		var spec := QuestDB.definition(quest_id)
		var quest := QuestDB.create(quest_id)
		if quest == null:
			continue
		lines.append("%s — %s" % [spec.get("title", quest_id), quest.objective_text(state.quest_progress(quest_id))])
	return lines


func ready_summaries() -> Array[String]:
	var lines: Array[String] = []
	for quest_id in QuestDB.ids():
		if state.quest_state(quest_id) != QuestData.State.READY:
			continue
		var spec := QuestDB.definition(quest_id)
		lines.append(String(spec.get("title", quest_id)))
	return lines
