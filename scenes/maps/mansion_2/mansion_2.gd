extends Level

const STARTING_ROOM := "MainHall"
const STARTING_YAW := PI

func _ready():
	super._ready()
	spawn_player()


func spawn_player() -> Player:
	var player: Player = super.spawn_player()
	Services.camera_manager.set_player_camera(player.camera_3d)
	RoomAware.set_current_room(player, STARTING_ROOM)
	test_respawn(player)
	
	var player_rotation := player.global_rotation
	player_rotation.y = STARTING_YAW
	player.global_rotation = player_rotation
	
	return player


func test_respawn(player: CharacterBody3D) -> void:
	var test_spawn := get_node_or_null("NavigationRegion3D/TestSpawn") as Node3D
	if test_spawn == null:
		push_warning("mansion_2: TestSpawn node is missing")
		return

	TransitionArrival.apply(player, test_spawn)
	RoomAware.set_current_room(player, STARTING_ROOM)
	Services.utils.play_sound(Services.get_sfx_catalog().get_sound(&"spawn"), player)
