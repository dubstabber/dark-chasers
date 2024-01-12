extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

const AOONI_SCENE := preload("res://scenes/enemies/ao_oni.tscn")

var ruby_key := preload("res://images/items/REDKA0.png")
var weird_key := preload("res://images/items/WEIRA0.png")
var brown_key := preload("res://images/items/BROWA0.png")
var gold_key := preload("res://images/items/YKGOA0.png")
var emerald_key := preload("res://images/items/EMERA0.png")
var silver_key := preload("res://images/items/SILVA0.png")

var door_locked_sound := preload("res://sounds/sfx/DOORLOCK.ogg")
var key_collected_sound := preload("res://sounds/sfx/DSKEYPIC.wav")

var open_door_sound := preload("res://sounds/sfx/DSDOROPN.ogg")
var close_door_sound := preload("res://sounds/sfx/DSDORCLS.ogg")

var kill_player_sound := preload("res://sounds/sfx/DSSLOP.wav")

var creep_amb_sound := preload("res://sounds/music/CREEPAMB.wav")
var aosee_sound := preload("res://sounds/music/AOSEE.wav")

var button_up_1 := preload("res://images/textures/BSW01A.png")
var button_down_1 := preload("res://images/textures/BSW01B.png")
var button_up_5 := preload("res://images/textures/BSW05A.png")
var button_down_5 := preload("res://images/textures/BSW05B.png")

var carpet_footsteps: Array
var dirt_footsteps: Array
var floor_footsteps: Array
var hard_footsteps: Array
var metal1_footsteps: Array
var metal2_footsteps: Array
var wood_footsteps: Array

func _ready():
	load_footsteps(3, "carpet", "DSCARP", carpet_footsteps, false)
	load_footsteps(6, "dirt1", "DSDIRT", dirt_footsteps, false)
	load_footsteps(6, "floor1", "DSTILE", floor_footsteps, true)
	load_footsteps(6, "hard1", "DSHARD", hard_footsteps, false)
	load_footsteps(6, "metal1", "DSMET", metal1_footsteps, true)
	load_footsteps(4, "metal2", "DSMET2", metal2_footsteps, true)
	load_footsteps(3, "wood", "DSWOOD", wood_footsteps, false)

func load_footsteps(steps: int, type: String, file_prefix: String, arr: Array, zero_padding: bool):
	for i in range(1,steps):
		var res: String 
		if i < 10 and zero_padding:
			res = "res://sounds/footsteps/"+type+"/"+file_prefix+"0"+str(i)+".wav"
		else:
			res = "res://sounds/footsteps/"+type+"/"+file_prefix+str(i)+".wav"
		var footstep := load(res)
		arr.push_back(footstep)
