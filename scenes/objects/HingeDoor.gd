extends StaticBody3D

@export var move_speed := 0.8
@export var opened_angle := 82
@export var time_to_close := 1.2
@export var open_only := false

var is_opening := false
var tween: Tween

func _ready():
	pass


func open():
	is_opening = not is_opening
	if tween and tween.is_running() and not open_only:
		tween.stop()
	if is_opening:
		tween = create_tween()
		await tween.tween_property(self, "rotation_degrees:y", opened_angle, move_speed).finished
		if not open_only:
			await get_tree().create_timer(time_to_close).timeout
			open()
	elif not is_opening and not open_only:
		tween = create_tween()
		await tween.tween_property(self, "rotation_degrees:y", 0.0, move_speed).finished

