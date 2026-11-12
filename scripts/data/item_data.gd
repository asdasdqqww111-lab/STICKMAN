extends Resource
class_name ItemData
## Data-driven item definition.  Content is added by creating .tres files under
## resources/items/ — no code changes required.

enum Kind { WEAPON, ARMOUR, CONSUMABLE, MATERIAL, QUEST }

@export var id: String = ""
@export var display_name: String = "Unnamed"
@export_enum("WEAPON", "ARMOUR", "CONSUMABLE", "MATERIAL", "QUEST") var kind: int = Kind.MATERIAL
@export_multiline var description: String = ""

## Weapon / armour numbers.  `attack` is added to melee damage, `defence` reduces
## incoming damage, `power` scales spells.
@export var attack: float = 0.0
@export var defence: float = 0.0
@export var power: float = 0.0

## Consumables: health / mana restored on use.
@export var heal: float = 0.0
@export var mana: float = 0.0

@export var value: int = 1
@export var stackable: bool = true
@export var max_stack: int = 99
@export var rarity: int = 0

## Visual: hand-slot model and grip transform (KayKit weapon glTF).
@export_file("*.gltf", "*.glb") var model_path: String = ""
@export var hand_offset: Vector3 = Vector3.ZERO
@export var hand_rotation: Vector3 = Vector3.ZERO
@export var hand_scale: float = 1.0

## Optional icon path (UI falls back to a coloured swatch when empty).
@export_file("*.png", "*.svg") var icon_path: String = ""


func is_equipment() -> bool:
	return kind == Kind.WEAPON or kind == Kind.ARMOUR


func is_weapon() -> bool:
	return kind == Kind.WEAPON


func is_armour() -> bool:
	return kind == Kind.ARMOUR
