extends Area3D

@export var level_name: String

var spawn_marker: Marker3D


# Called when the node enters the scene tree for the first time.
func _ready():
	if not level_name:
		for n in get_children():
			if n.is_in_group("spawn_point"):
				spawn_marker = n


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_body_entered(body):
	if level_name:
		get_tree().change_scene_to_file(level_name)
	elif spawn_marker:
		body.position = spawn_marker.global_position
