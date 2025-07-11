extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
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

const DOOR_LOCKED_SOUND := preload("res://sounds/sfx/DOORLOCK.ogg") # TODO: remove
const KEY_COLLECTED_SOUND := preload("res://sounds/sfx/DSKEYPIC.wav")

const KILL_PLAYER_SOUND := preload("res://sounds/sfx/DSSLOP.wav")

const CREEP_AMB_SOUND := preload("res://sounds/music/CREEPAMB.wav")
const AOSEE_SOUND := preload("res://sounds/music/AOSEE.wav")
const D_RUNNING_SOUND := preload("res://sounds/music/D_RUNNIN.ogg")
const BAR_SHAKE_SOUND := preload("res://sounds/sfx/BARSHAKE.ogg")
const SPAWN_SOUND := preload("res://sounds/sfx/DSTELEPT.ogg")
const EVENT_SOUND := preload("res://sounds/sfx/CREVENT.wav")
const WALLCUT_SOUND := preload("res://sounds/sfx/WALLCUT.wav")
const WOOD_BREAK_SOUND := preload("res://sounds/sfx/SND1028.wav")
const POT_BREAK_SOUND := preload("res://sounds/sfx/SND1048.wav")
const PAPER_BREAK_SOUND := preload("res://sounds/sfx/SND1023.wav")
const GLASS_BREAK_SOUND := preload("res://sounds/sfx/GLASSBRK.wav")

const BUTTON_UP_1_IMAGE := preload("res://images/textures/BSW01A.png")
const BUTTON_DOWN_1_IMAGE := preload("res://images/textures/BSW01B.png")
const BUTTON_UP_5_IMAGE := preload("res://images/textures/BSW05A.png")
const BUTTON_DOWN_5_IMAGE := preload("res://images/textures/BSW05B.png")

const WATER_SPLASH_SOUND := preload("res://sounds/sfx/footsteps/water/DSSPLSML.wav")

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
const POT_SCRAP_IMAGES := [
	preload("res://images/particles/1075C0.png"),
	preload("res://images/particles/1075D0.png"),
	preload("res://images/particles/1075E0.png"),
	preload("res://images/particles/1075F0.png"),
	preload("res://images/particles/1075G0.png"),
	preload("res://images/particles/1075H0.png"),
	preload("res://images/particles/1075I0.png"),
	preload("res://images/particles/1075J0.png")
]
const CIRCLE_GROUND_SCRAP_IMAGE := preload("res://images/particles/1075K0.png")
const SMALL_GROUND_SCRAP_IMAGE := preload("res://images/particles/1075L0.png")
const GRASS_SCRAP_IMAGES := [
	preload("res://images/particles/1075M0.png"),
	preload("res://images/particles/1075N0.png"),
	preload("res://images/particles/1075O0.png"),
	preload("res://images/particles/1075P0.png")
]

const PAPER_SCRAP_IMAGES := [
	preload("res://images/particles/1035A0.png"),
	preload("res://images/particles/1035B0.png"),
	preload("res://images/particles/1035C0.png"),
	preload("res://images/particles/1035D0.png"),
	preload("res://images/particles/1035E0.png")
]

const GLASS_SCRAP_IMAGES := [
	preload("res://images/particles/GLACA0.png"),
	preload("res://images/particles/GLACB0.png"),
	preload("res://images/particles/GLACC0.png"),
	preload("res://images/particles/GLACD0.png"),
	preload("res://images/particles/GLACE0.png"),
	preload("res://images/particles/GLACF0.png"),
	preload("res://images/particles/GLACG0.png"),
	preload("res://images/particles/GLACH0.png"),
	preload("res://images/particles/GLACI0.png")
]

const DOOM_DECAL_IMAGES := [
	preload("res://images/particles/chip1.png"),
	preload("res://images/particles/chip2.png"),
	preload("res://images/particles/chip3.png"),
	preload("res://images/particles/chip4.png"),
	preload("res://images/particles/chip5.png")
]

const SCRAP_SCENE := preload("res://scenes/particles/scrap.tscn")
