extends Node
## Small 2D/3D audio façade: pooled one-shots, UI clicks and a simple ambience.

const AssetCatalog = preload("res://scripts/core/asset_catalog.gd")

const POOL_SIZE := 8

var enabled := true
var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)
	_last_played = {}


func _stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var loaded := load(path)
	if loaded is AudioStream:
		_cache[path] = loaded
		return loaded
	_cache[path] = null
	return null


func play(path: String, volume_db: float = -6.0, pitch_jitter: float = 0.06) -> void:
	if not enabled:
		return
	var stream := _stream(path)
	if stream == null:
		return
	# Simple de-duplication so machine-gun triggers do not stack.
	var now := Time.get_ticks_msec()
	if _last_played.has(path) and now - int(_last_played[path]) < 45:
		return
	_last_played[path] = now
	for player in _pool:
		if player.playing:
			continue
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
		player.play()
		return


func play_ui(sound: String) -> void:
	var path: String = AssetCatalog.AUDIO_UI.get(sound, AssetCatalog.AUDIO_CLICK)
	play(path, -10.0, 0.02)


func play_footstep() -> void:
	var index := _rng.randi_range(0, AssetCatalog.AUDIO_FOOTSTEPS.size() - 1)
	play(AssetCatalog.AUDIO_FOOTSTEPS[index], -18.0, 0.12)


func play_attack() -> void:
	play(AssetCatalog.AUDIO_SLICE if _rng.randf() < 0.5 else AssetCatalog.AUDIO_SLICE_2, -8.0)


func play_hit() -> void:
	play(AssetCatalog.AUDIO_CLICK, -12.0, 0.15)


func play_coin() -> void:
	play(AssetCatalog.AUDIO_COINS, -8.0, 0.05)


func play_potion() -> void:
	play(AssetCatalog.AUDIO_POTION, -8.0, 0.05)


## Non-positional 3D emitter helper (used for monster hits).
func play_at_3d(path: String, position: Vector3, volume_db: float = -6.0) -> void:
	if not enabled or not is_inside_tree():
		return
	var stream := _stream(path)
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = 40.0
	get_tree().current_scene.add_child(player)
	player.global_position = position
	player.play()
	player.finished.connect(player.queue_free)
