extends StaticBody3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal button_pressed(body, event_name)

@export var button_type: String
@export var event_name: String
@export var one_use := true
@export var door_to_open: Node3D
@export var temporary_camera: Camera3D
@export var press_sound: AudioStream

var is_pressed := false

@onready var sprite_3d = get_node_or_null("Sprite3D")


func press(body):
	if not is_pressed:
		# Emit typed event via GameEventBus (pure emitter - no direct effects)
		# Effects (door opening, camera switching) are handled by:
		# - Effect components attached as children (DoorOpenerEffect, CameraSwitchEffect)
		# - Event subscribers (level scripts, SequenceDirector)
		GameEventBus.emit(GameEventTypesScript.BUTTON_PRESSED, {
			"body": body,
			"event_name": event_name,
			"button": self,
			"door": door_to_open,
			"camera": temporary_camera
		}, self)
		
		# Keep legacy signal for effect components to connect to
		button_pressed.emit(body, event_name)
		
		is_pressed = true
		change_sprite()
		if press_sound: Utils.play_sound(press_sound, self)
		if not one_use:
			await get_tree().create_timer(1.0).timeout
			is_pressed = false
			change_sprite()
			if press_sound: Utils.play_sound(press_sound, self)


func change_sprite():
	match button_type:
		"lever":
			if is_pressed: sprite_3d.texture = Preloads.BUTTON_DOWN_5_IMAGE
			else: sprite_3d.texture = Preloads.BUTTON_UP_5_IMAGE
		"circle":
			if is_pressed: sprite_3d.texture = Preloads.BUTTON_DOWN_1_IMAGE
			else: sprite_3d.texture = Preloads.BUTTON_UP_1_IMAGE
