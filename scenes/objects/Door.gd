extends Node3D

@export var move_speed := 0.5
@export var move_range := 2.5
@export var time_to_close := 1.2
@export var open_only := false
@export var key_needed: String
@export var can_manual_open := true
@export var front_locked := false
@export var back_locked := false
@export var open_door_sound: AudioStream = Preloads.open_door_sound
@export var close_door_sound := Preloads.close_door_sound
@export var stop_sound: AudioStream

var closed_position := position.y
var opened_position: float
var is_opening := false
var tween: Tween
var map: Node3D


func _ready():
	opened_position = closed_position + move_range
	map = get_tree().get_first_node_in_group('map')


func open(side = ""):
	var isUnlocked = true
	if map and key_needed and key_needed not in map.keys_collected:
		isUnlocked = false
		
	if side == "FrontSide" and front_locked:
		Utils.play_sound(Preloads.door_locked_sound, self)
	elif side == "BackSide" and back_locked:
		Utils.play_sound(Preloads.door_locked_sound, self)
	elif isUnlocked:
		is_opening = not is_opening
		if tween and tween.is_running() and not open_only:
			tween.stop()
		if is_opening:
			tween = create_tween()
			var sound = Utils.play_sound(open_door_sound, self)
			await tween.tween_property(self, "position:y", opened_position, move_speed).finished
			sound.stop()
			if stop_sound:
				Utils.play_sound(stop_sound, self)
			if not open_only:
				await get_tree().create_timer(time_to_close).timeout
				open()
		elif not is_opening and not open_only:
			tween = create_tween()
			Utils.play_sound(close_door_sound, self)
			await tween.tween_property(self, "position:y", closed_position, move_speed).finished
	else:
		print("You need the "+key_needed+" key!")
		Utils.play_sound(Preloads.door_locked_sound, self)

