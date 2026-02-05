extends Area3D

@export var volume_db: float = 0.0
@export var base_pitch: float = 0.8
@export var pitch_variation: float = 0.0 # set to 0 to disable pitch variation


func _ready():
	connect("body_entered", _on_body_entered)


func _on_body_entered(body):
	var pitch = base_pitch + randf_range(-pitch_variation, pitch_variation)
	var player = Utils.play_sound(Preloads.WATER_SPLASH_SOUND, body, body.global_position, volume_db)
	if player:
		player.pitch_scale = pitch
