extends RefCounted
## The Barrow: a three-room dungeon built from KayKit dungeon tiles, with a boss
## hall, torch lighting, traps and a chest.  Rooms are laid out in local space
## and then attached to the dungeon anchor on the planet surface.

const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")
const Math3D = preload("res://scripts/planet/sphere_math.gd")
const Terrain = preload("res://scripts/planet/terrain.gd")

## Tile size of the KayKit dungeon kit in metres.
const TILE := 4.0

## Room definitions in local tile coordinates (x, z) and size in tiles.
const ROOMS := [
	{"id": "entry", "x": 0, "z": 0, "w": 3, "d": 3, "torches": [[0, -1], [2, -1]]},
	{"id": "hall", "x": 0, "z": -3, "w": 5, "d": 4, "torches": [[0, 0], [4, 0], [0, 3], [4, 3]]},
	{"id": "vault", "x": 1, "z": -7, "w": 3, "d": 2, "torches": [[0, 1], [2, 1]]},
]


## Spawn points for monsters, in dungeon local space.
static func monster_spawns() -> Array[Dictionary]:
	return [
		{"archetype": "skeleton_minion", "position": Vector3(TILE * 3.0, 0.0, -TILE * 3.5)},
		{"archetype": "skeleton_minion", "position": Vector3(TILE * 0.5, 0.0, -TILE * 4.5)},
		{"archetype": "skeleton_rogue", "position": Vector3(TILE * 2.0, 0.0, -TILE * 5.5)},
		{"archetype": "skeleton_mage", "position": Vector3(TILE * 4.0, 0.0, -TILE * 6.0)},
		{"archetype": "skeleton_warrior", "position": Vector3(TILE * 2.0, 0.0, -TILE * 7.5)},
		{"archetype": "boss_bone_warden", "position": Vector3(TILE * 2.0, 0.0, -TILE * 8.0)},
	]


static func chest_position() -> Vector3:
	return Vector3(TILE * 2.0, 0.0, -TILE * 8.5)


## Build the dungeon under `parent`, anchored at `anchor_direction` on the planet.
## Returns a dictionary with the nodes that gameplay needs to reference.
static func build(parent: Node3D, anchor_direction: Vector3, shadow_material: Material = null) -> Dictionary:
	var root := Node3D.new()
	root.name = "BarrowDungeon"
	parent.add_child(root)
	# Place the dungeon entrance 4 m below the surface so the stair reads as a descent.
	var up := anchor_direction.normalized()
	var anchor_height := Terrain.elevation(up) - 3.2
	root.global_position = Math3D.surface_point(up, anchor_height)
	root.global_transform.basis = Math3D.frame_at(up)

	var floor_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_FLOOR)
	var wall_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_WALL)
	var corner_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_WALL_CORNER)
	var pillar_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_PILLAR)
	var torch_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_TORCH_LIT)
	var barrel_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_BARREL)
	var crates_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_CRATES)
	var rubble_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_RUBBLE)
	var chest_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_CHEST_GOLD)
	var banner_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_BANNER)
	var stairs_scene: PackedScene = _load_asset(AssetCatalog.DUNGEON_STAIRS)

	var floor_count := 0
	var wall_count := 0
	var torch_count := 0

	for room in ROOMS:
		var width: int = room["w"]
		var depth: int = room["d"]
		var origin_x: int = room["x"]
		var origin_z: int = room["z"]
		for ix in range(width):
			for iz in range(depth):
				var local := Vector3((origin_x + ix) * TILE, 0.0, (origin_z + iz) * TILE)
				if floor_scene != null:
					var floor: Node3D = floor_scene.instantiate()
					root.add_child(floor)
					floor.position = local
					floor_count += 1
		# Perimeter walls (skip the shared edge towards the next room).
		for ix in range(width):
			for edge in [0, depth]:
				var local := Vector3((origin_x + ix) * TILE, 0.0, (origin_z + edge) * TILE)
				var skip := false
				# Doorways between rooms: leave the middle tile open on the north wall.
				if edge == 0 and ix == int(width / 2.0):
					skip = true
				if skip:
					continue
				wall_count += _place(root, wall_scene, local)
		for iz in range(depth):
			for edge in [0, width]:
				var local := Vector3((origin_x + edge) * TILE, 0.0, (origin_z + iz) * TILE)
				var rot := PI * 0.5
				wall_count += _place(root, wall_scene, local, rot)
		for corner in [[0, 0], [width, 0], [0, depth], [width, depth]]:
			var local := Vector3((origin_x + corner[0]) * TILE, 0.0, (origin_z + corner[1]) * TILE)
			wall_count += _place(root, corner_scene, local)
		for torch in room["torches"]:
			var local := Vector3((origin_x + torch[0]) * TILE, 2.2, (origin_z + torch[1]) * TILE)
			torch_count += _place(root, torch_scene, local, 0.0, 1.4)
			_add_light(root, local, Color("ffb066"), 2.4, 9.0)
	# Central pillars in the boss hall.
	for offset in [Vector3(TILE, 0, -TILE * 4.0), Vector3(TILE * 4.0, 0, -TILE * 4.0)]:
		wall_count += _place(root, pillar_scene, offset)
	# Props.
	_place(root, barrel_scene, Vector3(TILE * 0.4, 0, -TILE * 0.4))
	_place(root, crates_scene, Vector3(TILE * 4.5, 0, -TILE * 5.4))
	_place(root, rubble_scene, Vector3(TILE * 1.2, 0, -TILE * 2.6))
	_place(root, banner_scene, Vector3(TILE * 2.0, 0, -TILE * 6.9))
	# Entrance stairs and the vault chest.
	_place(root, stairs_scene, Vector3(TILE * 1.0, -1.2, TILE * 1.1), PI)
	var chest := _place_node(root, chest_scene, chest_position())
	# A dark roof plane + ambient darkening volume keep the interior legible.
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(TILE * 12.0, 0.4, TILE * 13.0)
	roof.mesh = roof_mesh
	roof.position = Vector3(TILE * 2.0, 4.2, -TILE * 4.0)
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color("1d1a19")
	roof.material_override = roof_material
	root.add_child(roof)

	var monster_root := Node3D.new()
	monster_root.name = "Monsters"
	root.add_child(monster_root)

	return {
		"root": root,
		"monster_root": monster_root,
		"monster_spawns": monster_spawns(),
		"chest": chest,
		"chest_position": chest_position(),
		"floors": floor_count,
		"walls": wall_count,
		"torches": torch_count,
	}


static func _load_asset(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	return resource as PackedScene


static func _place(parent: Node3D, scene: PackedScene, local: Vector3, yaw: float = 0.0, scale_value: float = 1.0) -> int:
	var node := _place_node(parent, scene, local, yaw, scale_value)
	return 0 if node == null else 1


static func _place_node(parent: Node3D, scene: PackedScene, local: Vector3, yaw: float = 0.0, scale_value: float = 1.0) -> Node3D:
	if scene == null:
		return null
	var instance: Node3D = scene.instantiate()
	parent.add_child(instance)
	instance.position = local
	instance.rotation.y = yaw
	instance.scale = Vector3.ONE * scale_value
	return instance


static func _add_light(parent: Node3D, local: Vector3, colour: Color, energy: float, range_metres: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = range_metres
	light.position = local
	light.shadow_enabled = false
	parent.add_child(light)
