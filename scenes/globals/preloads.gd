extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

const IMAGE_ENEMY_SCENE := preload("res://scenes/enemies/image_enemy.tscn")
const AOONI_SCENE := preload("res://scenes/enemies/ao_oni.tscn")
const ILOPULU_SCENE := preload("res://scenes/enemies/ilopulu.tscn")
const WHITEFACE_SCENE := preload("res://scenes/enemies/white_face.tscn")

const RUBY_KEY_IMAGE := preload("res://images/items/REDKA0.png")
const WEIRD_KEY_IMAGE := preload("res://images/items/WEIRA0.png")
const BROWN_KEY_IMAGE := preload("res://images/items/BROWA0.png")
const GOLD_KEY_IMAGE := preload("res://images/items/YKGOA0.png")
const EMERALD_KEY_IMAGE := preload("res://images/items/EMERA0.png")
const SILVER_KEY_IMAGE := preload("res://images/items/SILVA0.png")

const DOOR_LOCKED_SOUND := preload("res://sounds/sfx/DOORLOCK.ogg")
const KEY_COLLECTED_SOUND := preload("res://sounds/sfx/DSKEYPIC.wav")

const OPEN_DOOR_SOUND := preload("res://sounds/sfx/DSDOROPN.ogg")
const CLOSE_DOOR_SOUND := preload("res://sounds/sfx/DSDORCLS.ogg")

const KILL_PLAYER_SOUND := preload("res://sounds/sfx/DSSLOP.wav")

const CREEP_AMB_SOUND := preload("res://sounds/music/CREEPAMB.wav")
const AOSEE_SOUND := preload("res://sounds/music/AOSEE.wav")
const D_RUNNING_SOUND := preload("res://sounds/music/D_RUNNIN.ogg")
const BAR_SHAKE_SOUND := preload("res://sounds/sfx/BARSHAKE.ogg")
const SPAWN_SOUND := preload("res://sounds/sfx/DSTELEPT.ogg")
const EVENT_SOUND := preload("res://sounds/sfx/CREVENT.wav")
const WALLCUT_SOUND := preload("res://sounds/sfx/WALLCUT.wav")
const WOOD_BREAK_SOUND := preload("res://sounds/sfx/SND1028.wav")

const PISTOL_SHOOT_SOUND := preload("res://sounds/sfx/HIRSHOT.wav")

const BUTTON_UP_1_IMAGE := preload("res://images/textures/BSW01A.png")
const BUTTON_DOWN_1_IMAGE := preload("res://images/textures/BSW01B.png")
const BUTTON_UP_5_IMAGE := preload("res://images/textures/BSW05A.png")
const BUTTON_DOWN_5_IMAGE := preload("res://images/textures/BSW05B.png")

const PUFF_SCENE := preload("res://scenes/particles/puff.tscn")
const POOF_SCENE := preload("res://scenes/particles/poof.tscn")

const WATER_SPLASH_SOUND := preload("res://sounds/footsteps/water/DSSPLSML.wav")

const SMALL_WOOD_IMAGES := [
	preload("res://images/particles/1045A0.png"),
	preload("res://images/particles/1045B0.png"),
	preload("res://images/particles/1045C0.png"),
	preload("res://images/particles/1045D0.png"),
	preload("res://images/particles/1045E0.png"),
	preload("res://images/particles/1045F0.png")
]

const BIG_WOOD_IMAGES := [
	preload("res://images/particles/1046A0.png"),
	preload("res://images/particles/1046B0.png"),
	preload("res://images/particles/1046C0.png"),
	preload("res://images/particles/1046D0.png"),
	preload("res://images/particles/1046E0.png"),
	preload("res://images/particles/1046F0.png"),
	preload("res://images/particles/1046G0.png"),
	preload("res://images/particles/1046H0.png")
]

const WHITE_SCRAP_IMAGES := [
	preload("res://images/particles/1047A0.png"),
	preload("res://images/particles/1047B0.png"),
	preload("res://images/particles/1047C0.png"),
	preload("res://images/particles/1047D0.png")
]

const SCRAP_SCENE := preload("res://scenes/particles/scrap.tscn")

var carpet_footstep_sounds := []
var dirt_footstep_sounds := []
var floor_footstep_sounds := []
var hard_footstep_sounds := []
var metal1_footstep_sounds := []
var metal2_footstep_sounds := []
var wood_footstep_sounds := []

func _ready():
	load_footsteps(3, "carpet", "DSCARP", carpet_footstep_sounds, false)
	load_footsteps(6, "dirt1", "DSDIRT", dirt_footstep_sounds, false)
	load_footsteps(6, "floor1", "DSTILE", floor_footstep_sounds, true)
	load_footsteps(6, "hard1", "DSHARD", hard_footstep_sounds, false)
	load_footsteps(6, "metal1", "DSMET", metal1_footstep_sounds, true)
	load_footsteps(4, "metal2", "DSMET2", metal2_footstep_sounds, true)
	load_footsteps(3, "wood", "DSWOOD", wood_footstep_sounds, false)

func load_footsteps(steps: int, type: String, file_prefix: String, arr: Array, zero_padding: bool):
	for i in range(1,steps):
		var res: String 
		if i < 10 and zero_padding:
			res = "res://sounds/footsteps/"+type+"/"+file_prefix+"0"+str(i)+".wav"
		else:
			res = "res://sounds/footsteps/"+type+"/"+file_prefix+str(i)+".wav"
		var footstep := load(res)
		arr.push_back(footstep)
