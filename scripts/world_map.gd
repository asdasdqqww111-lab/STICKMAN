extends Control
## Equirectangular view of discovered cube cells; unknown areas remain dark.
const Cells = preload("res://scripts/world_cells.gd")
const Sphere = preload("res://scripts/sphere.gd")
const Waypoints = preload("res://scripts/waypoints.gd")
var state: RefCounted

func _ready() -> void:
	custom_minimum_size = Vector2(400, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _map_position(dir: Vector3) -> Vector2:
	var ll: Vector2 = Sphere.coordinates(dir)
	return Vector2((ll.x / TAU + 0.5) * size.x, (0.5 - ll.y / PI) * size.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("111b2b"))
	for i in range(1, 4):
		draw_line(Vector2(size.x * i / 4.0, 0), Vector2(size.x * i / 4.0, size.y), Color("263c50"))
		draw_line(Vector2(0, size.y * i / 4.0), Vector2(size.x, size.y * i / 4.0), Color("263c50"))
	if state == null: return
	for id in state.discovered:
		var dir: Vector3 = Cells.point(id)
		if dir != Vector3.ZERO: draw_circle(_map_position(dir), 3.0, Color("83b586"))
	for id in state.waypoints:
		draw_circle(_map_position(Waypoints.position(id)), 5.0, Color("dcbf76"))
	draw_circle(_map_position(state.direction), 5.0, Color("f7f3e8"))
