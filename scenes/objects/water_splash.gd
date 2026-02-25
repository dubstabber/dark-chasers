extends Area3D

@export var volume_db: float = 0.0
@export var base_pitch: float = 0.8
@export var pitch_variation: float = 0.0 # set to 0 to disable pitch variation


func _ready():
	connect("body_entered", _on_body_entered)


func _on_body_entered(body):
	play_splash_sound(body, body.global_position)


func play_splash_sound(sound_parent: Node, sound_position: Vector3) -> void:
	if sound_parent == null:
		sound_parent = self
		sound_position = global_position

	var pitch = base_pitch + randf_range(-pitch_variation, pitch_variation)
	var sfx: SfxCatalog = Services.get_sfx_catalog()
	var player = Services.utils.play_sound(sfx.get_sound(&"water_splash"), sound_parent, sound_position, volume_db)
	if player:
		player.pitch_scale = pitch
