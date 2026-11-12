extends Node
## Region streaming + simulation LOD for props, monsters and NPCs.
##
## Regions are 6x12x12 cube-sphere cells.  Only regions within `stream_radius`
## of the player keep fully-simulated monsters; everything else is either culled
## (props) or reduced to a cheap simulation tick (monsters), which is what keeps
## the frame budget intact on a mid-range phone.

signal region_entered(region_id: String, first_time: bool)
signal stream_updated(active_regions: Array[String])

const Regions = preload("res://scripts/planet/planet_regions.gd")
const Math3D = preload("res://scripts/planet/sphere_math.gd")

## Radius in regions around the player that stays loaded.
@export var stream_radius := 2
## Distance (metres) beyond which a monster drops to simulation LOD.
@export var simulation_distance := 45.0
## Maximum monsters fully simulated at once.
@export var max_active_monsters := 24

var player: Node3D
var player_state: RefCounted
var regions := {}                     # region id -> Array[Node]
var monsters: Array = []
var current_region := ""
var streaming_enabled := true
var rebuild_timer := 0.0
var last_active: Array[String] = []


func bind(player_node: Node3D, state: RefCounted) -> void:
	player = player_node
	player_state = state


func register_prop(region_id: String, node: Node) -> void:
	if not regions.has(region_id):
		regions[region_id] = []
	regions[region_id].append(node)


func register_monster(monster: Node) -> void:
	monsters.append(monster)


func unregister_monster(monster: Node) -> void:
	monsters.erase(monster)


func _physics_process(delta: float) -> void:
	if player == null or not streaming_enabled:
		return
	rebuild_timer += delta
	if rebuild_timer < 0.35:
		return
	rebuild_timer = 0.0
	_update_streaming()


func _update_streaming() -> void:
	var region := Regions.region_of(player.current_direction)
	if region == "":
		return
	if region != current_region:
		current_region = region
		var first_time: bool = player_state != null and player_state.discover(region)
		emit_signal("region_entered", region, first_time)
	var active: Array[String] = []
	var neighbourhood := Regions.neighborhood(player.current_direction, stream_radius)
	for id in neighbourhood:
		active.append(id)
		if regions.has(id):
			for node in regions[id]:
				if is_instance_valid(node):
					node.visible = true
	# Hide props in regions that fell out of range.
	for id in regions.keys():
		if id in active:
			continue
		for node in regions[id]:
			if is_instance_valid(node):
				node.visible = false
	if active != last_active:
		last_active = active
		emit_signal("stream_updated", active)
	_apply_monster_lod()


func _apply_monster_lod() -> void:
	var simulated := 0
	var candidates := []
	for monster in monsters:
		if not is_instance_valid(monster) or not monster.alive:
			continue
		var distance: float = Math3D.arc_distance(player.current_direction, monster.current_direction)
		candidates.append({"node": monster, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for entry in candidates:
		var monster: Node = entry["node"]
		var near: bool = entry["distance"] <= simulation_distance and simulated < max_active_monsters
		monster.visible = entry["distance"] <= simulation_distance * 1.8
		monster.set_physics_process(near)
		if near:
			simulated += 1


func loaded_region_count() -> int:
	return regions.size()


func active_region_count() -> int:
	return last_active.size()


func total_monsters() -> int:
	var count := 0
	for monster in monsters:
		if is_instance_valid(monster) and monster.alive:
			count += 1
	return count
