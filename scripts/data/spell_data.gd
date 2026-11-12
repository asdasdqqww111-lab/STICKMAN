extends Resource
class_name SpellData
## A magic school spell.  Three schools ship: Frost, Ember and Arcane.

enum Element { PHYSICAL, FIRE, ICE, ARCANE }
enum Shape { PROJECTILE, MELEE_ARC, AURA, HEAL }

@export var id: String = ""
@export var display_name: String = "Spell"
@export_enum("FIRE", "ICE", "ARCANE", "PHYSICAL") var element: int = Element.ARCANE
@export_enum("PROJECTILE", "MELEE_ARC", "AURA", "HEAL") var shape: int = Shape.PROJECTILE
@export var school: String = "arcane"

@export var mana_cost: float = 10.0
@export var cooldown: float = 2.0
@export var damage: float = 20.0
@export var range_metres: float = 12.0
@export var radius: float = 2.5
@export var heal_amount: float = 0.0

@export var required_level: int = 1
@export var required_rank: String = "F"
@export_multiline var description: String = ""

@export var effect_color: Color = Color("8f7dff")


func element_name() -> String:
	return ["Physical", "Fire", "Ice", "Arcane"][element]
