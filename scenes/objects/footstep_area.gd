extends Area3D

@export var type: String


func _ready():
	connect("body_entered", _on_body_entered)


func _on_body_entered(body):
	# Use GroundTypeReceiver interface for typed ground type assignment
	GroundTypeReceiver.set_ground_type(body, type)
