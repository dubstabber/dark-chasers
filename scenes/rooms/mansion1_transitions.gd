extends Node3D

## Implements TransitionsData interface for typed access.

var map_transitions := {
	"FirstFloor": {"FirstFloorUpstairs": "SecondFloor", "BigHallEntry": "BigHall"},
	"SecondFloor":
	{
		"SecondFloorDownstairs": "FirstFloor",
		"SecondFloorUpstairs": "ThirdFloor",
		"PianoRoomEntry": "PianoRoom",
	},
	"ThirdFloor":
	{
		"ThirdFloorDownstairs": "SecondFloor",
		"ThirdFloorAbyss": "PianoRoom",
	},
	"PianoRoom":
	{
		"PianoRoomExit": "SecondFloor",
	},
	"BigHall":
	{
		"FirstFloorEntry": "FirstFloor",
		"BasementGap": "Basement",
	},
	"Basement":
	{
		"BasementLadder": "BigHall",
	},
}

var enemy_exceptions := ["ThirdFloorAbyss"]


func get_map_transitions() -> Dictionary:
	return map_transitions


func get_enemy_exceptions() -> Array:
	return enemy_exceptions
