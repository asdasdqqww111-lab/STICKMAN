extends RefCounted
## Single source of truth for every vendored asset path.
##
## Paths are `res://assets/vendor/...` and are fetched + hashed by
## tools/fetch_assets.py.  Keeping them in one catalog means the exporter can
## verify that every referenced file exists before the build is shipped.

const PLAYER_BODY := "res://assets/vendor/characters/adventurers/Knight.glb"
const PLAYER_BODY_MAGE := "res://assets/vendor/characters/adventurers/Mage.glb"
const PLAYER_BODY_ROGUE := "res://assets/vendor/characters/adventurers/Rogue.glb"
const NPC_VILLAGER := "res://assets/vendor/characters/adventurers/Barbarian.glb"
const SKELETON_MINION := "res://assets/vendor/characters/skeletons/Skeleton_Minion.glb"
const SKELETON_WARRIOR := "res://assets/vendor/characters/skeletons/Skeleton_Warrior.glb"
const SKELETON_MAGE := "res://assets/vendor/characters/skeletons/Skeleton_Mage.glb"
const SKELETON_ROGUE := "res://assets/vendor/characters/skeletons/Skeleton_Rogue.glb"

const WEAPON_SWORD := "res://assets/vendor/characters/adventurers/sword_1handed.gltf"
const WEAPON_GREATSWORD := "res://assets/vendor/characters/adventurers/sword_2handed.gltf"
const WEAPON_STAFF := "res://assets/vendor/characters/adventurers/staff.gltf"
const WEAPON_DAGGER := "res://assets/vendor/characters/adventurers/dagger.gltf"
const WEAPON_AXE := "res://assets/vendor/characters/adventurers/axe_1handed.gltf"
const WEAPON_SHIELD := "res://assets/vendor/characters/adventurers/shield_round.gltf"

const CITY_BUILDING_A := "res://assets/vendor/city/building_A.gltf"
const CITY_BUILDING_B := "res://assets/vendor/city/building_B.gltf"
const CITY_BUILDING_C := "res://assets/vendor/city/building_C.gltf"
const CITY_BUSH := "res://assets/vendor/city/bush.gltf"
const CITY_BENCH := "res://assets/vendor/city/bench.gltf"
const CITY_BOX := "res://assets/vendor/city/box_A.gltf"
const CITY_ROAD := "res://assets/vendor/city/road_straight.gltf"

const DUNGEON_FLOOR := "res://assets/vendor/dungeon/floor_tile_big_grate.gltf.glb"
const DUNGEON_FLOOR_OPEN := "res://assets/vendor/dungeon/floor_tile_big_grate_open.gltf.glb"
const DUNGEON_FLOOR_SPIKES := "res://assets/vendor/dungeon/floor_tile_big_spikes.glb"
const DUNGEON_WALL := "res://assets/vendor/dungeon/wall.gltf.glb"
const DUNGEON_WALL_CORNER := "res://assets/vendor/dungeon/wall_corner.gltf.glb"
const DUNGEON_WALL_PILLAR := "res://assets/vendor/dungeon/wall_pillar.gltf.glb"
const DUNGEON_WALL_DOORWAY := "res://assets/vendor/dungeon/wall_doorway_scaffold.glb"
const DUNGEON_PILLAR := "res://assets/vendor/dungeon/pillar.gltf.glb"
const DUNGEON_TORCH := "res://assets/vendor/dungeon/torch_mounted.gltf.glb"
const DUNGEON_TORCH_LIT := "res://assets/vendor/dungeon/torch_lit.gltf.glb"
const DUNGEON_CHEST := "res://assets/vendor/dungeon/chest.glb"
const DUNGEON_CHEST_GOLD := "res://assets/vendor/dungeon/chest_gold.glb"
const DUNGEON_COIN := "res://assets/vendor/dungeon/coin.gltf.glb"
const DUNGEON_COIN_STACK := "res://assets/vendor/dungeon/coin_stack_small.gltf.glb"
const DUNGEON_BARREL := "res://assets/vendor/dungeon/barrel_large.gltf.glb"
const DUNGEON_CRATES := "res://assets/vendor/dungeon/crates_stacked.gltf.glb"
const DUNGEON_CANDLE := "res://assets/vendor/dungeon/candle_lit.gltf.glb"
const DUNGEON_STAIRS := "res://assets/vendor/dungeon/stairs.gltf.glb"
const DUNGEON_RUBBLE := "res://assets/vendor/dungeon/rubble_half.gltf.glb"
const DUNGEON_BANNER := "res://assets/vendor/dungeon/banner_red.gltf.glb"

const AUDIO_SLICE := "res://assets/vendor/audio/knife_slice.ogg"
const AUDIO_SLICE_2 := "res://assets/vendor/audio/knife_slice_2.ogg"
const AUDIO_FOOTSTEPS := [
	"res://assets/vendor/audio/footstep_0.ogg",
	"res://assets/vendor/audio/footstep_1.ogg",
	"res://assets/vendor/audio/footstep_2.ogg",
	"res://assets/vendor/audio/footstep_3.ogg",
]
const AUDIO_COINS := "res://assets/vendor/audio/handle_coins.ogg"
const AUDIO_COINS_2 := "res://assets/vendor/audio/handle_coins_2.ogg"
const AUDIO_POTION := "res://assets/vendor/audio/metal_pot_1.ogg"
const AUDIO_CLICK := "res://assets/vendor/audio/metal_click.ogg"
const AUDIO_PAGE := "res://assets/vendor/audio/book_flip_1.ogg"
const AUDIO_DOOR_OPEN := "res://assets/vendor/audio/door_open_1.ogg"
const AUDIO_DOOR_CLOSE := "res://assets/vendor/audio/door_close_1.ogg"
const AUDIO_DRAW := "res://assets/vendor/audio/draw_knife_1.ogg"
const AUDIO_CLOTH := "res://assets/vendor/audio/cloth_1.ogg"

const AUDIO_UI := {
	"click": AUDIO_CLICK,
	"page": AUDIO_PAGE,
	"coins": AUDIO_COINS,
	"potion": AUDIO_POTION,
	"door": AUDIO_DOOR_OPEN,
	"draw": AUDIO_DRAW,
	"cloth": AUDIO_CLOTH,
	"hit": AUDIO_SLICE,
	"hit2": AUDIO_SLICE_2,
}

## Every path the game preloads; validated by tests/test_assets.gd at import time.
const REQUIRED_PATHS := [
	PLAYER_BODY, PLAYER_BODY_MAGE, PLAYER_BODY_ROGUE, NPC_VILLAGER,
	SKELETON_MINION, SKELETON_WARRIOR, SKELETON_MAGE, SKELETON_ROGUE,
	WEAPON_SWORD, WEAPON_GREATSWORD, WEAPON_STAFF, WEAPON_DAGGER, WEAPON_AXE, WEAPON_SHIELD,
	CITY_BUILDING_A, CITY_BUILDING_B, CITY_BUILDING_C, CITY_BUSH, CITY_BENCH, CITY_BOX, CITY_ROAD,
	DUNGEON_FLOOR, DUNGEON_FLOOR_OPEN, DUNGEON_WALL, DUNGEON_WALL_CORNER, DUNGEON_WALL_PILLAR,
	DUNGEON_PILLAR, DUNGEON_TORCH, DUNGEON_CHEST, DUNGEON_CHEST_GOLD, DUNGEON_COIN,
	DUNGEON_BARREL, DUNGEON_CRATES, DUNGEON_CANDLE, DUNGEON_STAIRS, DUNGEON_RUBBLE, DUNGEON_BANNER,
	AUDIO_SLICE, AUDIO_COINS, AUDIO_POTION, AUDIO_CLICK, AUDIO_PAGE,
]

const MONSTER_VISUALS := {
	"slime": SKELETON_MINION,
	"skeleton_minion": SKELETON_MINION,
	"skeleton_warrior": SKELETON_WARRIOR,
	"skeleton_mage": SKELETON_MAGE,
	"skeleton_rogue": SKELETON_ROGUE,
	"wolf": SKELETON_ROGUE,
	"golem": SKELETON_WARRIOR,
	"wraith": SKELETON_MAGE,
	"boar": SKELETON_ROGUE,
	"direwolf": SKELETON_ROGUE,
	"boss_warden": SKELETON_WARRIOR,
}

## All animation clip names observed in the KayKit packs (see ASSET_INTEGRATION_REPORT).
const ANIM = {
	"idle": ["Idle", "Unarmed_Idle", "2H_Melee_Idle"],
	"walk": ["Walking_A", "Walking_B", "Walking_C"],
	"run": ["Running_A", "Running_B", "Running_C"],
	"jump": ["Jump_Start", "Jump_Full_Short", "Jump_Idle"],
	"land": ["Jump_Land", "Jump_Full_Short"],
	"attack_light": ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop"],
	"attack_heavy": ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice", "1H_Melee_Attack_Stab"],
	"spell": ["Spellcast_Shoot", "Spellcast_Raise", "Spellcasting"],
	"dodge": ["Dodge_Forward", "Dodge_Backward", "Dodge_Left", "Dodge_Right"],
	"hit": ["Hit_A", "Hit_B"],
	"death": ["Death_A", "Death_B", "Death_C_Skeletons"],
	"interact": ["Interact", "Use_Item", "PickUp"],
	"cheer": ["Cheer"],
	"spawn": ["Spawn_Ground", "Skeletons_Awaken_Floor"],
}

## Resolve the first clip existing in a loaded animation library.
static func pick_clip(library: AnimationLibrary, candidates: Array) -> String:
	if library == null:
		return ""
	for candidate in candidates:
		if library.has_animation(candidate):
			return candidate
	return ""
