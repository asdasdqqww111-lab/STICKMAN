extends RefCounted
## The 15 launch quests.  Every objective is evaluated by QuestLog against real
## gameplay events (kills, pickups, discoveries, ranks, crafting, boss kills).

const QuestData = preload("res://scripts/data/quest_data.gd")

const DEFINITIONS := [
	{
		"id": "welcome_to_havenbrook", "title": "Welcome to Havenbrook", "order": 0,
		"summary": "Registrar Maeve wants to meet every new face at the guild hall.",
		"objective": QuestData.Objective.TALK_NPC, "target": "registrar", "count": 1,
		"xp": 15, "gold": 5, "giver": "registrar",
		"giver_text": "Another hopeful. Sign the ledger and I'll find you work.",
	},
	{
		"id": "slime_cull", "title": "Slime Infestation", "order": 1,
		"summary": "Meadow slimes are spoiling the eastern fields.",
		"objective": QuestData.Objective.KILL_ENEMY, "target": "meadow_slime", "count": 3,
		"xp": 40, "gold": 20, "giver": "registrar", "requires": "welcome_to_havenbrook",
		"giver_text": "Three slimes should send a message.",
	},
	{
		"id": "moonbell_harvest", "title": "Moonbell Harvest", "order": 2,
		"summary": "Gather moonbell herbs for the guild's potion stores.",
		"objective": QuestData.Objective.COLLECT_ITEM, "target": "purple_herb", "count": 3,
		"xp": 35, "gold": 15, "giver": "registrar", "requires": "slime_cull",
		"giver_text": "The purple ones. Two petals, never three.",
	},
	{
		"id": "survey_the_sphere", "title": "Survey the Sphere", "order": 3,
		"summary": "The cartographers need first-hand reports from uncharted ground.",
		"objective": QuestData.Objective.DISCOVER_REGION, "target": "", "count": 6,
		"xp": 30, "gold": 12, "giver": "registrar", "requires": "moonbell_harvest",
		"giver_text": "Walk until the map stops being blank.",
	},
	{
		"id": "bones_in_the_meadow", "title": "Bones in the Meadow", "order": 4,
		"summary": "Skeletons have crawled out of the east field. Put them back.",
		"objective": QuestData.Objective.KILL_ENEMY, "target": "skeleton_minion", "count": 4,
		"xp": 60, "gold": 25, "giver": "registrar", "requires": "survey_the_sphere",
		"giver_text": "Bone does not bleed, but it still breaks.",
	},
	{
		"id": "shrine_light", "title": "Kindle the Shrines", "order": 5,
		"summary": "Waypoint shrines have gone dark. Wake two of them.",
		"objective": QuestData.Objective.LIGHT_SHRINE, "target": "", "count": 2,
		"xp": 45, "gold": 18, "giver": "registrar", "requires": "bones_in_the_meadow",
		"giver_text": "Each shrine you wake shortens the road home.",
	},
	{
		"id": "wolf_pelts", "title": "Winter Is Coming", "order": 6,
		"summary": "The village needs pelts before the cold season.",
		"objective": QuestData.Objective.COLLECT_ITEM, "target": "wolf_pelt", "count": 2,
		"xp": 55, "gold": 22, "giver": "registrar", "requires": "shrine_light",
		"giver_text": "Forest wolves, not the meadow strays.",
	},
	{
		"id": "rank_e_trial", "title": "Trial of Rank E", "order": 7,
		"summary": "Prove yourself and be promoted to Rank E.",
		"objective": QuestData.Objective.REACH_RANK, "target": "E", "count": 1,
		"xp": 80, "gold": 30, "giver": "registrar", "requires": "wolf_pelts",
		"giver_text": "Do the work, then ask me for the stripe.",
	},
	{
		"id": "forge_fire", "title": "Forge Fire", "order": 8,
		"summary": "Craft an iron sword at the village forge.",
		"objective": QuestData.Objective.CRAFT_ITEM, "target": "iron_sword", "count": 1,
		"xp": 50, "gold": 20, "giver": "registrar", "requires": "rank_e_trial",
		"giver_text": "Bring ore and herb. The forge does the rest.",
	},
	{
		"id": "skeleton_warriors", "title": "The Armoured Dead", "order": 9,
		"summary": "Skeleton warriors guard the northern ridge.",
		"objective": QuestData.Objective.KILL_ENEMY, "target": "skeleton_warrior", "count": 3,
		"xp": 90, "gold": 35, "giver": "registrar", "requires": "forge_fire",
		"giver_text": "Heavy bone. Bring a shield, or be quick.",
	},
	{
		"id": "into_the_barrow", "title": "Into the Barrow", "order": 10,
		"summary": "A dungeon mouth has opened in the northern hills.",
		"objective": QuestData.Objective.ENTER_DUNGEON, "target": "barrow", "count": 1,
		"xp": 85, "gold": 30, "giver": "registrar", "requires": "skeleton_warriors",
		"giver_text": "Down the stairs, past the iron door. Don't linger.",
	},
	{
		"id": "the_bone_warden", "title": "The Bone Warden", "order": 11,
		"summary": "Something old and armoured rules the barrow's deepest hall.",
		"objective": QuestData.Objective.DEFEAT_BOSS, "target": "boss_bone_warden", "count": 1,
		"xp": 220, "gold": 90, "giver": "registrar", "requires": "into_the_barrow",
		"giver_text": "Kill it before it remembers how to rule.",
	},
	{
		"id": "sigil_bearer", "title": "Sigil Bearer", "order": 12,
		"summary": "Return the Warden's sigil to the guild hall.",
		"objective": QuestData.Objective.COLLECT_ITEM, "target": "warden_sigil", "count": 1,
		"xp": 140, "gold": 60, "giver": "registrar", "requires": "the_bone_warden",
		"giver_text": "Hand it over and the guild will remember your name.",
	},
	{
		"id": "rank_d_trial", "title": "Trial of Rank D", "order": 13,
		"summary": "Rank D opens the sealed contracts of the realm.",
		"objective": QuestData.Objective.REACH_RANK, "target": "D", "count": 1,
		"xp": 180, "gold": 70, "giver": "registrar", "requires": "sigil_bearer",
		"giver_text": "You've earned the right to ask.",
	},
	{
		"id": "earthbound_golem", "title": "Earthbound", "order": 14,
		"summary": "A stone golem has woken on the high ridge.",
		"objective": QuestData.Objective.KILL_ENEMY, "target": "earth_golem", "count": 1,
		"xp": 160, "gold": 65, "giver": "registrar", "requires": "rank_d_trial",
		"giver_text": "Some stone only listens to a blade.",
	},
]


static func create(id: String) -> Resource:
	var spec := definition(id)
	if spec.is_empty():
		return null
	var quest := QuestData.new()
	quest.id = id
	quest.title = spec.get("title", id)
	quest.summary = spec.get("summary", "")
	quest.objective = spec.get("objective", QuestData.Objective.KILL_ENEMY)
	quest.target_id = spec.get("target", "")
	quest.target_count = spec.get("count", 1)
	quest.required_quest = spec.get("requires", "")
	quest.required_rank = spec.get("rank", "F")
	quest.required_level = spec.get("level", 1)
	quest.xp_reward = spec.get("xp", 0)
	quest.gold_reward = spec.get("gold", 0)
	quest.item_rewards = spec.get("items", [])
	quest.giver = spec.get("giver", "registrar")
	quest.giver_text = spec.get("giver_text", "")
	quest.sort_order = spec.get("order", 0)
	return quest


static func definition(id: String) -> Dictionary:
	for spec in DEFINITIONS:
		if spec.get("id", "") == id:
			return spec
	return {}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for spec in DEFINITIONS:
		result.append(spec.get("id", ""))
	return result


static func ordered() -> Array[Dictionary]:
	var copy := DEFINITIONS.duplicate(true)
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("order", 0) < b.get("order", 0))
	return copy


static func count() -> int:
	return DEFINITIONS.size()
