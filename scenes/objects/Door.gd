extends Area3D

@export var move_speed := 0.5
@export var move_range := 2.5
@export var time_to_close := 1.2
@export var open_only := false
@export var key_needed: String
@export var trigger: Node3D

var closed_position := position.y
var opened_position: float
var is_opening := false
var tween: Tween
var map: Node3D


func _ready():
	opened_position = closed_position + move_range
	connect("body_entered",_door_body_entered)
	connect("body_exited",_door_body_exited)
	if trigger:
		trigger.connect("button_pressed", open)
	map = get_tree().get_first_node_in_group('map')


func open(_button_event = null):
	var isUnlocked = true
	if map and key_needed and key_needed not in map.keys_collected:
		isUnlocked = false

	if isUnlocked:
		is_opening = not is_opening
		if tween and tween.is_running() and not open_only:
			tween.stop()
		if is_opening:
			tween = create_tween()
			Utils.play_sound(Preloads.open_door_sound, self)
			await tween.tween_property(self, "position:y", opened_position, move_speed).finished
			if not open_only:
				await get_tree().create_timer(time_to_close).timeout
				open()
		elif not is_opening and not open_only:
			tween = create_tween()
			Utils.play_sound(Preloads.close_door_sound, self)
			await tween.tween_property(self, "position:y", closed_position, move_speed).finished
	else:
		print("You need the "+key_needed+" key!")
		Utils.play_sound(Preloads.door_locked_sound, self)


func _door_body_entered(body):
	if not trigger:
		if body.is_in_group("player"):
			if "door_to_open" in body:
				body.door_to_open = self
		if body.is_in_group("enemy"):
			open()


func _door_body_exited(body):
	if not trigger:
		if "door_to_open" in body:
			body.door_to_open = null
