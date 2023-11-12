extends Node3D

@onready var transitions: Node3D = $Transitions


func _ready():
	for t in transitions.get_children():
		for m in t.get_children():
			if m.is_in_group('spawn_point'):
				t.connect("body_entered", handle_transition.bind(m))
			if m.is_in_group('manual_spawn_point'):
				t.connect("body_entered", _on_transition_entered.bind(m))
				t.connect("body_exited", _on_transition_exited)
	

func handle_transition(body, transitor):
	if transitor:
		body.position = transitor.global_position


func _on_transition_entered(body, transitor):
	if body.is_in_group('player') and transitor:
		if "transit_pos" in body:
			body.transit_pos = transitor
			
			
func _on_transition_exited(body):
	if body.is_in_group('player'):
		if "transit_pos" in body:
			body.transit_pos = null


func _on_ladder_body_entered(body):
	if body.is_in_group('player'):
		body.is_climbing = true


func _on_ladder_body_exited(body):
	if body.is_in_group('player'):
		body.is_climbing = false
