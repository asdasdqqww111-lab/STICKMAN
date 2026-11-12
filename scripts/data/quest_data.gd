extends Resource
class_name QuestData
## A quest definition.  Objectives are declarative so the quest tracker can
## evaluate them from gameplay events without bespoke code per quest.

enum Objective { KILL_ENEMY, COLLECT_ITEM, DISCOVER_REGION, TALK_NPC, REACH_RANK, DEFEAT_BOSS, CRAFT_ITEM, LIGHT_SHRINE, ENTER_DUNGEON }
enum State { LOCKED, AVAILABLE, ACTIVE, READY, COMPLETED }

@export var id: String = ""
@export var title: String = "Quest"
@export_multiline var summary: String = ""
@export_multiline var completion_text: String = ""

## Objective kind (see enum Objective) plus its target id and count.
@export_enum("KILL_ENEMY", "COLLECT_ITEM", "DISCOVER_REGION", "TALK_NPC", "REACH_RANK", "DEFEAT_BOSS", "CRAFT_ITEM", "LIGHT_SHRINE", "ENTER_DUNGEON")
var objective: int = Objective.KILL_ENEMY
@export var target_id: String = ""
@export var target_count: int = 1

## Requirements.
@export var required_rank: String = "F"
@export var required_quest: String = ""
@export var required_level: int = 1

## Rewards.
@export var xp_reward: int = 0
@export var gold_reward: int = 0
@export var item_rewards: Array[Dictionary] = []
@export var reputation_reward: int = 0

## Giver NPC id + dialogue.
@export var giver: String = "registrar"
@export var giver_text: String = ""

## Ordering hint for the journal.
@export var sort_order: int = 0


func objective_text(progress: int) -> String:
	var verb := ""
	match objective:
		Objective.KILL_ENEMY: verb = "Defeat %s" % _pretty(target_id)
		Objective.COLLECT_ITEM: verb = "Collect %s" % _pretty(target_id)
		Objective.DISCOVER_REGION: verb = "Discover %d regions" % target_count
		Objective.TALK_NPC: verb = "Speak to %s" % _pretty(target_id)
		Objective.REACH_RANK: verb = "Reach guild rank %s" % target_id
		Objective.DEFEAT_BOSS: verb = "Defeat %s" % _pretty(target_id)
		Objective.CRAFT_ITEM: verb = "Craft %s" % _pretty(target_id)
		Objective.LIGHT_SHRINE: verb = "Activate %d waypoint shrines" % target_count
		Objective.ENTER_DUNGEON: verb = "Enter %s" % _pretty(target_id)
	return "%s (%d/%d)" % [verb, mini(progress, target_count), target_count]


func _pretty(value: String) -> String:
	return value.replace("_", " ").capitalize()
