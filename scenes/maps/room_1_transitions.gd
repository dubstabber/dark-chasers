extends Node3D

var map_transitions := {
	"MainRoom": {"HiddenPassage": "SmallRoom"},
	"HiddenPassage": {"ReturningSphere": "MainRoom"}
}

var enemy_exceptions := []

func get_map_transitions() -> Dictionary:
	return map_transitions


func get_enemy_exceptions() -> Array:
	return enemy_exceptions
