extends Node3D

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
