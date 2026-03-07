extends StaticBody3D

signal button_pressed(body: Node)

## The domain-specific event type to emit (e.g., GameEventTypes.BUTTON_CHECK_TV).
## This is the SOLE stable identity for the event - no string dispatch needed.
## Set this in the editor by typing the StringName value (e.g., &"button_check_tv").
@export var event_type_id: StringName = &""

@export var button_type: String
@export var one_use := true
@export var press_sound: AudioStream

var is_pressed := false

@onready var sprite_3d = get_node_or_null("Sprite3D")


func press(body: Node) -> void:
	if not is_pressed:
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

		button_pressed.emit(body)

		is_pressed = true
		change_sprite()
		if press_sound: Services.utils.play_sound(press_sound, self)
		if not one_use:
			await get_tree().create_timer(1.0).timeout
			is_pressed = false
			change_sprite()
			if press_sound: Services.utils.play_sound(press_sound, self)


func change_sprite():
	if sprite_3d and button_type:
		sprite_3d.texture = Services.get_button_images().get_texture(button_type, is_pressed)
