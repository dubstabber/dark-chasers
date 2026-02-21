extends StaticBody3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal button_pressed(body)

## The domain-specific event type to emit (e.g., GameEventTypes.BUTTON_CHECK_TV).
## This is the SOLE stable identity for the event - no string dispatch needed.
## Set this in the editor by typing the StringName value (e.g., &"button_check_tv").
@export var event_type_id: StringName = &""

@export var button_type: String
@export var one_use := true
@export var door_to_open: Node3D
@export var temporary_camera: Camera3D
@export var press_sound: AudioStream

var is_pressed := false

@onready var sprite_3d = get_node_or_null("Sprite3D")


func press(body):
	if not is_pressed:
		# Emit domain-specific typed event via GameEventBus (pure emitter - no direct effects)
		# Effects (door opening, camera switching) are handled by:
		# - Effect components attached as children (DoorOpenerEffect, CameraSwitchEffect)
		# - Event subscribers (level scripts, SequenceDirector)
		#
		# The event_type_id is the SOLE stable identity - no event_name string dispatch.
		if event_type_id != &"":
			Services.event_bus.emit(event_type_id, {
				"body": body,
				"button": self,
				"door": door_to_open,
				"camera": temporary_camera
			}, self)

		# Emit generic event for base Level class handling (door/camera from payload)
		Services.event_bus.emit(GameEventTypesScript.BUTTON_PRESSED, {
			"body": body,
			"button": self,
			"door": door_to_open,
			"camera": temporary_camera
		}, self)

		# Signal for effect components attached as children
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
		sprite_3d.texture = Services.preloads.get_button_images().get_texture(button_type, is_pressed)
