extends Area3D

var spawn_marker: Marker3D

# Called when the node enters the scene tree for the first time.
func _ready():
	for n in get_children():
		if n.is_in_group('spawn_point'):
			spawn_marker = n

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_body_entered(body):
	if body.is_in_group('player') and spawn_marker:
		body.position = spawn_marker.global_position
	
