extends Node3D

signal door_locked(text)

@export var move_speed := 0.8
@export var opened_angle := 82
@export var time_to_close := 1.2
@export var open_only := false
@export var can_manual_open := true
@export var front_locked := false
@export var back_locked := false
@export var can_interrupt := true

var is_opening := false
var tween: Tween


func open(side = ""):
	if side == "FrontSide" and front_locked:
		door_locked.emit("The door is locked.")
		Utils.play_sound(Preloads.door_locked_sound, self)
	elif side == "BackSide" and back_locked:
		door_locked.emit("The door is locked.")
		Utils.play_sound(Preloads.door_locked_sound, self)
	elif not is_opening:
			is_opening = true
			if tween and tween.is_running() and not open_only:
				tween.stop()
			tween = create_tween()
			await tween.tween_property(self, "rotation_degrees:y", opened_angle, move_speed).finished
			if not open_only:
				await get_tree().create_timer(time_to_close).timeout
				if is_opening:
					tween = create_tween()
					await tween.tween_property(self, "rotation_degrees:y", 0.0, move_speed).finished
					is_opening = false
	elif can_interrupt and is_opening and not open_only:
		if tween and tween.is_running():
			tween.stop()
		tween = create_tween()
		await tween.tween_property(self, "rotation_degrees:y", 0.0, move_speed).finished
		is_opening = false

