extends Area3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

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
		
		# Emit typed event via GameEventBus (pure emitter - no direct effects)
		# Effects (door opening, camera switching) are handled by:
		# - Effect components attached as children (DoorOpenerEffect, CameraSwitchEffect)
		# - Event subscribers (level scripts, SequenceDirector)
		GameEventBus.emit(GameEventTypesScript.AREA_ENTERED, {
			"body": body,
			"event_name": event_name,
			"area": self,
			"door": door_to_open,
			"camera": temporary_camera
		}, self)
		
		# Keep legacy signal for effect components to connect to
		event_triggered.emit(body, event_name)
