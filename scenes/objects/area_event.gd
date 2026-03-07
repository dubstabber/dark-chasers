extends Area3D

signal trigger_entered(body: Node)

## The domain-specific event type to emit (e.g., GameEventTypes.AREA_PIANO_ALARM).
## This is the SOLE stable identity for the event - no string dispatch needed.
## Set this in the editor by typing the StringName value (e.g., &"area_piano_alarm").
@export var event_type_id: StringName = &""

@export var one_trigger_only := true

var triggered := false


func _ready():
	connect("body_entered", _body_entered)


func _body_entered(body: Node) -> void:
	if body.is_in_group('player') and not triggered:
		if one_trigger_only: triggered = true

		# Emit domain-specific typed event via GameEventBus (pure emitter - no direct effects)
		# Effects (door opening, camera switching) are handled by:
		# - Effect components attached as children (DoorOpenerEffect, CameraSwitchEffect)
		# - Event subscribers (level scripts, SequenceDirector)
		#
		# The event_type_id is the SOLE stable identity - no event_name string dispatch.
		# Keep only the triggering body in payload when subscribers need it; the
		# trigger identity is already available through event.source.
		if event_type_id != &"":
			Services.event_bus.emit(event_type_id, {
				"body": body
			}, self)

		trigger_entered.emit(body)
