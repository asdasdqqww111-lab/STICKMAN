extends RefCounted
## Promotion is explicit at the registrar; level alone never grants rank.
const ORDER := ["F", "E", "D"]
const REQUIREMENTS := {
	"E": {"slimes": 5, "regions": 1, "quests": 2, "level": 1},
	"D": {"slimes": 7, "regions": 4, "quests": 2, "level": 3},
}

static func next_rank(rank: String) -> String:
	var index := ORDER.find(rank)
	if index < 0 or index >= ORDER.size() - 1: return ""
	return ORDER[index + 1]

static func eligible(rank: String, slimes: int, regions: int, quests: int, level: int) -> bool:
	var next := next_rank(rank)
	if next.is_empty(): return false
	var req: Dictionary = REQUIREMENTS[next]
	return slimes >= req.slimes and regions >= req.regions and quests >= req.quests and level >= req.level

static func describe(rank: String) -> String:
	var next := next_rank(rank)
	if next.is_empty(): return "D is the highest implemented rank."
	var req: Dictionary = REQUIREMENTS[next]
	return "Rank %s requirements: %d slimes, %d regions, %d contracts, level %d." % [next, req.slimes, req.regions, req.quests, req.level]
