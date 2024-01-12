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

