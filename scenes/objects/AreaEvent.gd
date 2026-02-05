extends Area3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal event_triggered(body)

## The domain-specific event type to emit (e.g., GameEventTypes.AREA_PIANO_ALARM).
## This is the SOLE stable identity for the event - no string dispatch needed.
## Set this in the editor by typing the StringName value (e.g., &"area_piano_alarm").
@export var event_type_id: StringName = &""

@export var one_trigger_only := true
@export var door_to_open: Node3D
@export var temporary_camera: Camera3D

var triggered := false


func _ready():
	connect("body_entered", _body_entered)


func _body_entered(body):
	if body.is_in_group('player') and not triggered:
		if one_trigger_only: triggered = true

		# Emit domain-specific typed event via GameEventBus (pure emitter - no direct effects)
		# Effects (door opening, camera switching) are handled by:
		# - Effect components attached as children (DoorOpenerEffect, CameraSwitchEffect)
		# - Event subscribers (level scripts, SequenceDirector)
		#
		# The event_type_id is the SOLE stable identity - no event_name string dispatch.
		if event_type_id != &"":
			GameEventBus.emit(event_type_id, {
				"body": body,
				"area": self,
				"door": door_to_open,
				"camera": temporary_camera
			}, self)

		# Also emit generic AREA_ENTERED for base Level class handling
		# (camera switching, door opening from payload)
		GameEventBus.emit(GameEventTypesScript.AREA_ENTERED, {
			"body": body,
			"area": self,
			"door": door_to_open,
			"camera": temporary_camera
		}, self)

		# Keep legacy signal for effect components to connect to
		event_triggered.emit(body)
