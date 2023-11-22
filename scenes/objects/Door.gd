extends Area3D

var closed_position := position.y
var opened_position: float
var is_opening := false
var tween: Tween

@export var move_speed := 0.5
@export var move_range := 2.5
@export var time_to_close := 1.2
@export var open_only := false


func _ready():
	opened_position = closed_position + move_range
	

func open():
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

