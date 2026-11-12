extends RefCounted
## Guild rank ladder F -> S.  Only F, E and D have tuned requirements for the
## launch slice; higher ranks are declared so content can be added without a
## code change, but `requirements_for_next` returns an "unlocked in a future
## chapter" marker for them.

const ORDER := ["F", "E", "D", "C", "B", "A", "S"]

## Requirements to reach each rank.  `None` means "not yet implemented".
const REQUIREMENTS := {
	"E": {"kills": 8, "regions": 4, "quests": 3, "level": 3, "reputation": 10},
	"D": {"kills": 20, "regions": 8, "quests": 7, "level": 6, "reputation": 30},
	"C": {"kills": 45, "regions": 14, "quests": 12, "level": 10, "reputation": 70},
	"B": null,
	"A": null,
	"S": null,
}

const RANK_TITLES := {
	"F": "Copper Plate", "E": "Iron Plate", "D": "Steel Plate",
	"C": "Silver Plate", "B": "Gold Plate", "A": "Mithril Plate", "S": "Star Plate",
}


static func index_of(rank: String) -> int:
	return ORDER.find(rank)


static func at_least(rank: String, required: String) -> bool:
	var have := index_of(rank)
	var need := index_of(required)
	if have < 0 or need < 0:
		return false
	return have >= need


static func next_rank(rank: String) -> String:
	var index := index_of(rank)
	if index < 0 or index >= ORDER.size() - 1:
		return ""
	return ORDER[index + 1]


static func requirements_for(target: String) -> Variant:
	return REQUIREMENTS.get(target, null)


## Requirements for the *next* rank, or {} when at the top of the ladder.
static func requirements_for_next(rank: String, stats: Dictionary, regions: int, quests: int, level: int, reputation: int) -> Dictionary:
	var target := next_rank(rank)
	if target == "":
		return {}
	var requirement: Variant = REQUIREMENTS.get(target, null)
	if requirement == null:
		return {}
	var result := {}
	for key in requirement.keys():
		var needed: int = int(requirement[key])
		var have := 0
		match key:
			"kills": have = int(stats.get("kills", 0))
			"regions": have = regions
			"quests": have = quests
			"level": have = level
			"reputation": have = reputation
		result[key] = {"have": have, "need": needed, "met": have >= needed}
	return result


static func eligible_for_next(rank: String, stats: Dictionary, regions: int, quests: int, level: int, reputation: int) -> bool:
	var requirements := requirements_for_next(rank, stats, regions, quests, level, reputation)
	if requirements.is_empty():
		return false
	for key in requirements.keys():
		if not requirements[key]["met"]:
			return false
	return true


static func describe(rank: String, stats: Dictionary, regions: int, quests: int, level: int, reputation: int) -> String:
	var target := next_rank(rank)
	if target == "":
		return "You hold the highest rank."
	var requirements := requirements_for_next(rank, stats, regions, quests, level, reputation)
	if requirements.is_empty():
		return "Rank %s contracts are sealed until the next chapter." % target
	var parts: Array[String] = []
	for key in ["kills", "regions", "quests", "level", "reputation"]:
		if not requirements.has(key):
			continue
		var row: Dictionary = requirements[key]
		parts.append("%s %d/%d" % [key.capitalize(), row["have"], row["need"]])
	return "Rank %s needs: %s" % [target, ", ".join(parts)]


static func title(rank: String) -> String:
	return RANK_TITLES.get(rank, "Unknown")
