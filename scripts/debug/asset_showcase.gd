extends Node3D
## Visual integration test for every vendored 3D asset.
##
## Run with: godot --path . scenes/AssetShowcase.tscn
## Each row is one asset category; the on-screen report lists which models loaded,
## which animation clips resolved and which failed — the same data that
## tools/check_assets.py asserts in CI.

const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")
const CharacterAnimator = preload("res://scripts/core/character_animator.gd")
const Math3D = preload("res://scripts/planet/sphere_math.gd")

var _report: Label
var _loaded: Array[String] = []
var _failed: Array[String] = []
var _animators: Array[Node] = []
var _elapsed := 0.0


func _ready() -> void:
	_build_environment()
	_build_characters(Vector3(-7, 0, -2))
	_build_monsters(Vector3(0, 0, -2))
	_build_weapons(Vector3(7, 0, -2))
	_build_props(Vector3(-7, 0, 5))
	_build_dungeon(Vector3(2, 0, 6))
	_build_audio()
	_build_report()


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("16233a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cfe3f0")
	environment.ambient_light_energy = 1.1
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 36, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(46, 30)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("26364a")
	floor_mesh.material_override = material
	add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 11, 20)
	camera.look_at(Vector3(0, 1.0, 1.0))
	camera.current = true
	add_child(camera)


func _spawn(path: String, position: Vector3, scale_value: float = 1.0, animate: bool = false) -> Node3D:
	if not ResourceLoader.exists(path):
		_failed.append(path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		_failed.append(path)
		return null
	var instance: Node3D = scene.instantiate()
	instance.position = position
	instance.scale = Vector3.ONE * scale_value
	instance.rotation.y = PI
	add_child(instance)
	_loaded.append(path.get_file())
	if animate:
		var animator := CharacterAnimator.new()
		add_child(animator)
		if animator.setup(instance):
			animator.play("idle")
			_animators.append(animator)
		else:
			_failed.append(path.get_file() + " (no AnimationPlayer)")
	return instance


func _row_label(text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.006
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _build_characters(origin: Vector3) -> void:
	_row_label("PLAYERS / NPC", origin + Vector3(0, 3.2, 0))
	var entries := [
		[AssetCatalog.PLAYER_BODY, "Knight"],
		[AssetCatalog.PLAYER_BODY_MAGE, "Mage"],
		[AssetCatalog.PLAYER_BODY_ROGUE, "Rogue"],
		[AssetCatalog.NPC_VILLAGER, "Barbarian"],
	]
	for i in range(entries.size()):
		_spawn(entries[i][0], origin + Vector3(i * 2.6, 0, 0), 1.0, true)


func _build_monsters(origin: Vector3) -> void:
	_row_label("MONSTERS", origin + Vector3(0, 2.6, 0))
	var entries := [
		[AssetCatalog.SKELETON_MINION, "Minion"],
		[AssetCatalog.SKELETON_WARRIOR, "Warrior"],
		[AssetCatalog.SKELETON_MAGE, "Mage"],
		[AssetCatalog.SKELETON_ROGUE, "Rogue"],
	]
	for i in range(entries.size()):
		_spawn(entries[i][0], origin + Vector3(i * 2.2, 0, 0), 0.92, true)


func _build_weapons(origin: Vector3) -> void:
	_row_label("WEAPONS", origin + Vector3(0, 2.4, 0))
	var entries := [
		[AssetCatalog.WEAPON_SWORD, "1H Sword"],
		[AssetCatalog.WEAPON_GREATSWORD, "2H Sword"],
		[AssetCatalog.WEAPON_STAFF, "Staff"],
		[AssetCatalog.WEAPON_AXE, "Axe"],
		[AssetCatalog.WEAPON_DAGGER, "Dagger"],
		[AssetCatalog.WEAPON_SHIELD, "Shield"],
	]
	for i in range(entries.size()):
		var node := _spawn(entries[i][0], origin + Vector3((i % 3) * 1.4, 1.0 + (i / 3) * 1.4, 0))
		if node != null:
			node.rotation = Vector3(0, 0, PI * 0.5)


func _build_props(origin: Vector3) -> void:
	_row_label("CITY / NATURE", origin + Vector3(2.4, 3.0, 0))
	var entries := [
		[AssetCatalog.CITY_BUILDING_A, 1.6],
		[AssetCatalog.CITY_BUILDING_B, 1.6],
		[AssetCatalog.CITY_BUILDING_C, 1.6],
		[AssetCatalog.CITY_BUSH, 1.4],
		[AssetCatalog.CITY_BENCH, 1.6],
		[AssetCatalog.CITY_BOX, 1.4],
		[AssetCatalog.CITY_ROAD, 1.6],
	]
	for i in range(entries.size()):
		_spawn(entries[i][0], origin + Vector3((i % 4) * 2.6, 0, (i / 4) * 2.6), entries[i][1])


func _build_dungeon(origin: Vector3) -> void:
	_row_label("DUNGEON KIT", origin + Vector3(3.5, 3.2, 0))
	var entries := [
		[AssetCatalog.DUNGEON_FLOOR, 1.0],
		[AssetCatalog.DUNGEON_WALL, 1.0],
		[AssetCatalog.DUNGEON_WALL_CORNER, 1.0],
		[AssetCatalog.DUNGEON_PILLAR, 1.0],
		[AssetCatalog.DUNGEON_TORCH_LIT, 1.0],
		[AssetCatalog.DUNGEON_CHEST, 1.0],
		[AssetCatalog.DUNGEON_CHEST_GOLD, 1.0],
		[AssetCatalog.DUNGEON_BARREL, 1.0],
		[AssetCatalog.DUNGEON_CRATES, 1.0],
		[AssetCatalog.DUNGEON_CANDLE, 1.0],
		[AssetCatalog.DUNGEON_BANNER, 1.0],
		[AssetCatalog.DUNGEON_RUBBLE, 1.0],
	]
	for i in range(entries.size()):
		_spawn(entries[i][0], origin + Vector3((i % 4) * 3.4, 0, (i / 4) * 3.4), entries[i][1])


func _build_audio() -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	if ResourceLoader.exists(AssetCatalog.AUDIO_SLICE):
		player.stream = load(AssetCatalog.AUDIO_SLICE)
		_loaded.append("knife_slice.ogg")


func _build_report() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	canvas.add_child(panel)
	_report = Label.new()
	_report.add_theme_font_size_override("font_size", 15)
	panel.add_child(_report)
	var lines: Array[String] = []
	lines.append("ASSET SHOWCASE — %d loaded, %d failed" % [_loaded.size(), _failed.size()])
	lines.append("Loaded:")
	for name in _loaded:
		lines.append("  ✔ " + name)
	if not _failed.is_empty():
		lines.append("Failed:")
		for name in _failed:
			lines.append("  ✘ " + name)
	lines.append("Animators: %d" % _animators.size())
	lines.append("Oscillating through clips; see ASSET_INTEGRATION_REPORT.md")
	if not OS.get_cmdline_user_args().is_empty() and "--verify" in OS.get_cmdline_user_args():
		print("\n".join(lines))
		print("SHOWCASE_RESULT: %s" % ("PASS" if _failed.is_empty() and _animators.size() > 0 else "FAIL"))
	_report.text = "\n".join(lines)


func _process(delta: float) -> void:
	_elapsed += delta
	# Cycle each animated character through its clips as a visible smoke test.
	if int(_elapsed * 2.0) % 6 == 0:
		for animator in _animators:
			if is_instance_valid(animator) and not animator.is_busy():
				animator.set_locomotion(1.0, true)
