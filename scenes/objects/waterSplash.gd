extends Area3D

@export var volume_db: float = 0.0
@export var base_pitch: float = 0.8
@export var pitch_variation: float = 0.0 # set to 0 to disable pitch variation
@export var max_distance: float = 40.0


func _ready():
	connect("body_entered", _on_body_entered)


func _on_body_entered(body):
	var sound = AudioStreamPlayer3D.new()
	body.add_child(sound)
	sound.stream = Preloads.WATER_SPLASH_SOUND
	sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	sound.volume_db = volume_db
	sound.pitch_scale = base_pitch + randf_range(-pitch_variation, pitch_variation)
	sound.max_distance = max_distance
	sound.connect("finished", sound.queue_free)
	sound.play()
