extends Area3D


func _ready():
	connect("body_entered", _on_body_entered)


func _on_body_entered(body):
	Utils.play_footstep_sound(Preloads.water_splash, body)

