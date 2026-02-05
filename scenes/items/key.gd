@tool
extends Area3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal key_collected(body, type, message_text)

## The domain-specific event type to emit (e.g., GameEventTypes.KEY_SPAWN_AO_ONI_LIBRARY).
## This is the SOLE stable identity for the event - no string dispatch needed.
## Set this in the editor by typing the StringName value (e.g., &"key_spawn_ao_oni_library").
@export var event_type_id: StringName = &""

@export var key_type: String

func _ready():
	if Engine.is_editor_hint():
		# In editor, load texture directly to avoid placeholder autoload issue
		var key_icons: KeyIconLibrary = load("res://scenes/resources/key_icon_library.tres")
		if key_icons:
			$Sprite3D.texture = key_icons.get_texture(key_type)
	else:
		$Sprite3D.texture = Preloads.get_key_texture(key_type)


func _on_body_entered(body):
	if body.is_in_group('player'):
		var message_text: String
		match key_type:
			"ruby":
				message_text = "Picked up a ruby key."
			"weird":
				message_text = "Picked up some odd looking key."
			"brown":
				message_text = "Picked up a rusty brown key."
			"gold":
				message_text = "Picked up a fancy gold key."
			"emerald":
				message_text = "Picked up an emerald key."
			"silver":
				message_text = "Picked up a shiny silver key."
			"useless":
				message_text = 'Congratulations! You just picked up the useless key!'
			_:
				message_text = "Picked up a key."

		# Emit domain-specific typed event via GameEventBus
		# The event_type_id is the SOLE stable identity - no event_name string dispatch.
		if event_type_id != &"":
			GameEventBus.emit(event_type_id, {
				"body": body,
				"key_type": key_type,
				"message": message_text
			}, self)

		# Also emit generic KEY_COLLECTED for base Level class handling
		# (key collection tracking, HUD updates)
		GameEventBus.emit(GameEventTypesScript.KEY_COLLECTED, {
			"body": body,
			"key_type": key_type,
			"message": message_text
		}, self)

		# Keep legacy signal for backward compatibility
		key_collected.emit(body, key_type, message_text)
		Utils.play_sound(Preloads.KEY_COLLECTED_SOUND, body)
		queue_free()
