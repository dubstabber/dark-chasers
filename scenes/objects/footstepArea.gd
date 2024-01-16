extends Area3D

@export var type: String


func _ready():
	connect("body_entered", _on_body_entered)


func _on_body_entered(body):
	if "ground_type" in body:
		body.ground_type = type
