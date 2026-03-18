extends Node3D

var map_transitions := {
	"MainHall": {
		"WeirdRoomEntry": "WeirdRoom",
		"FirstFloorUpstairs": "SecondFloor",
		"SmallRoomDoor": "SmallRoom",
		"BasementDownStairs": "SmallBasement",
		"BasementHole": "SmallBasement",
		"FirstFloorUpstairs2": "SecondFloor2",
		"SmallRoom2Door": "SmallRoom2",
		"SmallDarkRoomHole": "SmallDarkRoom",
		"ChurchRoomEntry": "ChurchRoom"
	},
	"WeirdRoom": {
		"ReturnPoint": "MainHall"
	},
	"SmallRoom": {
		"SmallRoomExit": "MainHall"
	},
	"SecondFloor": {
		"SecondFloorDownstairs": "MainHall",
		"SecondFloorUpstairs": "ThirdFloor"
	},
	"ThirdFloor": {
		"ThirdFloorDownstairs": "SecondFloor"
	},
	"SmallBasement": {
		"SmallBasementUpstairs": "MainHall",
		"FirstBigBasementEntry": "FirstBigBasement"
	},
	"FirstBigBasement": {
		"FirstBigBasementExit": "SmallBasement"
	},
	"SmallRoom2": {
		"SmallRoom2Exit": "MainHall"
	},
	"SecondFloor2": {
		"SecondFloor2Downstairs": "MainHall",
		"LongLibraryEntry": "LongLibrary",
		"BlueRoomEntry": "BlueRoom",
		"SecondFloorAbyss": "MainHall"
	},
	"LongLibrary": {
		"LongLibraryExit": "SecondFloor2"
	},
	"BlueRoom": {
		"BlueRoomExit": "SecondFloor2"
	},
	"ChurchRoom": {
		"ChurchRoomExit": "MainHall",
		"SecondBigBasementEntry": "SecondBigBasement"
	},
	"SecondBigBasement": {
		"SecondBigBasementExit": "ChurchRoom",
		"SmallDarkRoomEntry": "SmallDarkRoom",
		"BlueberryRoomEntry": "BlueberryRoom",
		"OutsideEntry": "Outside"
	},
	"SmallDarkRoom": {
		"SmallDarkRoomExit": "SecondBigBasement"
	},
	"BlueberryRoom": {
		"BlueberryRoomExit": "SecondBigBasement"
	}
}

var enemy_exceptions := ["BasementHole", "SmallDarkRoomHole", "SecondFloorAbyss"]

func get_map_transitions() -> Dictionary:
	return map_transitions


func get_enemy_exceptions() -> Array:
	return enemy_exceptions
