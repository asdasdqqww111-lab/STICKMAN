extends Resource
class_name LootTable
## Weighted loot table with guaranteed drops and independent chance entries.

@export var id: String = ""

## entries: Array[Dictionary] with keys:
##   item_id: String, weight: float, min: int, max: int,
##   chance: float (0..1, optional exact probability instead of weight),
##   unique: bool (at most one per table roll)
@export var entries: Array = []

## Always granted when the table rolls.
@export var guaranteed: Array = []

## Roll count bounds (e.g. a chest rolls 2-4 times).
@export var min_rolls: int = 1
@export var max_rolls: int = 1


## Deterministic sample: `rng` is passed in so tests can reproduce results.
func roll(rng: RandomNumberGenerator) -> Array:
	var drops: Array = []
	for entry in guaranteed:
		drops.append(_make_drop(entry, rng))
	var rolls := rng.randi_range(maxi(1, min_rolls), maxi(1, max_rolls))
	var total_weight := 0.0
	for entry in entries:
		total_weight += float(entry.get("weight", 1.0))
	for i in range(rolls):
		if entries.is_empty() or total_weight <= 0.0:
			break
		var pick := rng.randf() * total_weight
		var chosen: Dictionary = {}
		for entry in entries:
			pick -= float(entry.get("weight", 1.0))
			if pick <= 0.0:
				chosen = entry
				break
		if chosen.is_empty():
			continue
		if chosen.has("chance") and rng.randf() > float(chosen["chance"]):
			continue
		drops.append(_make_drop(chosen, rng))
	return drops


func _make_drop(entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var low: int = int(entry.get("min", 1))
	var high: int = int(entry.get("max", low))
	return {
		"item_id": String(entry.get("item_id", "")),
		"count": rng.randi_range(mini(low, high), maxi(low, high)),
	}
