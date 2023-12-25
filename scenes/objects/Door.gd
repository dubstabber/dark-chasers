extends Area3D

@export var move_speed := 0.5
@export var move_range := 2.5
@export var time_to_close := 1.2
@export var open_only := false
@export var key_needed: String
@export var trigger: String

var closed_position := position.y
var opened_position: float
var is_opening := false
var tween: Tween
var map: Node3D

func _ready():
	opened_position = closed_position + move_range
	map = get_tree().get_first_node_in_group('map')

func open():
	var isUnlocked = true
	if key_needed and not key_needed in map.keys_collected:
		isUnlocked = false
	
	if isUnlocked:
		is_opening = not is_opening
		if tween and tween.is_running() and not open_only:
			tween.stop()
		if is_opening:
			tween = create_tween()
			await tween.tween_property(self, "position:y", opened_position, move_speed).finished
			if not open_only:
				await get_tree().create_timer(time_to_close).timeout
				open()
		elif not is_opening and not open_only:
			tween = create_tween()
			await tween.tween_property(self, "position:y", closed_position, move_speed).finished
	else:
		print("You need the "+key_needed+" key!")

