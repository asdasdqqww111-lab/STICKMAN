extends RefCounted
## Built-in spell roster: three schools (Ember, Frost, Arcane) with six spells.

const SpellData = preload("res://scripts/data/spell_data.gd")

const DEFINITIONS := {
	"ember_bolt": {
		"name": "Ember Bolt", "school": "ember", "element": SpellData.Element.FIRE,
		"shape": SpellData.Shape.PROJECTILE, "mana": 8.0, "cooldown": 1.6, "damage": 26.0,
		"range": 16.0, "radius": 2.0, "level": 1, "rank": "F",
		"desc": "Hurls a mote of flame. Sets a small area ablaze.", "color": Color("ef7a3a"),
	},
	"flame_wave": {
		"name": "Flame Wave", "school": "ember", "element": SpellData.Element.FIRE,
		"shape": SpellData.Shape.AURA, "mana": 22.0, "cooldown": 5.5, "damage": 42.0,
		"range": 6.0, "radius": 6.0, "level": 4, "rank": "E",
		"desc": "A ring of fire burns everything close by.", "color": Color("ff5c2b"),
	},
	"frost_bolt": {
		"name": "Frost Bolt", "school": "frost", "element": SpellData.Element.ICE,
		"shape": SpellData.Shape.PROJECTILE, "mana": 10.0, "cooldown": 2.0, "damage": 22.0,
		"range": 18.0, "radius": 2.0, "level": 2, "rank": "F",
		"desc": "A shard of ice that slows the target.", "color": Color("6fd3ff"),
	},
	"glacial_spike": {
		"name": "Glacial Spike", "school": "frost", "element": SpellData.Element.ICE,
		"shape": SpellData.Shape.MELEE_ARC, "mana": 18.0, "cooldown": 4.0, "damage": 48.0,
		"range": 5.0, "radius": 3.5, "level": 5, "rank": "D",
		"desc": "Bursts spikes from the ground in front of the caster.", "color": Color("9fe8ff"),
	},
	"arcane_shot": {
		"name": "Arcane Shot", "school": "arcane", "element": SpellData.Element.ARCANE,
		"shape": SpellData.Shape.PROJECTILE, "mana": 12.0, "cooldown": 2.2, "damage": 30.0,
		"range": 20.0, "radius": 2.4, "level": 1, "rank": "F",
		"desc": "A lance of raw arcana. Ignores a little armour.", "color": Color("a98bff"),
	},
	"mending_light": {
		"name": "Mending Light", "school": "arcane", "element": SpellData.Element.ARCANE,
		"shape": SpellData.Shape.HEAL, "mana": 20.0, "cooldown": 6.0, "damage": 0.0,
		"heal": 55.0, "range": 0.0, "radius": 0.0, "level": 3, "rank": "F",
		"desc": "Weaves restorative light into the caster.", "color": Color("ffe6a3"),
	},
}

const SCHOOLS := {
	"ember": {"name": "School of Ember", "color": Color("ef7a3a")},
	"frost": {"name": "School of Frost", "color": Color("6fd3ff")},
	"arcane": {"name": "School of Arcane", "color": Color("a98bff")},
}


static func create(id: String) -> Resource:
	if not DEFINITIONS.has(id):
		return null
	var spec: Dictionary = DEFINITIONS[id]
	var spell := SpellData.new()
	spell.id = id
	spell.display_name = spec.get("name", id)
	spell.school = spec.get("school", "arcane")
	spell.element = spec.get("element", SpellData.Element.ARCANE)
	spell.shape = spec.get("shape", SpellData.Shape.PROJECTILE)
	spell.mana_cost = spec.get("mana", 10.0)
	spell.cooldown = spec.get("cooldown", 2.0)
	spell.damage = spec.get("damage", 20.0)
	spell.range_metres = spec.get("range", 12.0)
	spell.radius = spec.get("radius", 2.5)
	spell.heal_amount = spec.get("heal", 0.0)
	spell.required_level = spec.get("level", 1)
	spell.required_rank = spec.get("rank", "F")
	spell.description = spec.get("desc", "")
	spell.effect_color = spec.get("color", Color("8f7dff"))
	return spell


static func ids() -> Array[String]:
	var result: Array[String] = []
	for key in DEFINITIONS.keys():
		result.append(key)
	return result


static func exists(id: String) -> bool:
	return DEFINITIONS.has(id)
