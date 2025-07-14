extends Area3D

signal event_triggered(body, event_name)

@export var one_trigger_only := true
@export var event_name: String
@export var door_to_open: Node3D
@export var temporary_camera: Camera3D

var triggered := false


func _ready():
	connect("body_entered", _body_entered)


func _body_entered(body):
	if body.is_in_group('player') and not triggered:
		if one_trigger_only: triggered = true
		if temporary_camera: temporary_camera.set_current(true)
		if door_to_open and door_to_open.has_method("open"): door_to_open.open()
		event_triggered.emit(body, event_name)
