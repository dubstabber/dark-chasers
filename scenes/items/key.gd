@tool
extends Area3D

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
		$Sprite3D.texture = Services.get_key_icons().get_texture(key_type)


func _on_body_entered(body):
	if body.is_in_group('player'):
		var key_icons := Services.get_key_icons()
		var message_text := key_icons.get_pickup_message(key_type) if key_icons else "Picked up a key."

		# Emit domain-specific typed event via GameEventBus
		# The event_type_id is the SOLE stable identity - no event_name string dispatch.
		if event_type_id != &"":
			Services.event_bus.emit(event_type_id, {
				"body": body,
				"key_type": key_type,
				"message": message_text
			}, self)

		# Emit generic event for base Level class handling (key collection tracking)
		Services.event_bus.emit(GameEventTypes.KEY_COLLECTED, {
			"body": body,
			"key_type": key_type,
			"message": message_text
		}, self)

		Services.utils.play_sound(Services.get_sfx_catalog().key_collected, body)
		queue_free()
