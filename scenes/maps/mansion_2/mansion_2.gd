extends Level

const STARTING_ROOM := "MainHall"
const STARTING_YAW := PI


func _ready():
	super._ready()
	$Doors/AoMovingWall11.open()
	#open_all_doors()


func _exit_tree():
	super._exit_tree()


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
	var test_spawn := _find_unique_test_spawn_marker() as Node3D
	if test_spawn == null:
		test_spawn = get_node_or_null("NavigationRegion3D/TestSpawn") as Node3D
	if test_spawn == null:
		push_warning("mansion_2: TestSpawn node is missing")
		return

	TransitionArrival.apply(player, test_spawn)
	RoomAware.set_current_room(player, STARTING_ROOM)
	Services.utils.play_sound(Services.get_sfx_catalog().get_sound(&"spawn"), player)


# For testing purposes
func open_all_doors():
	keys_collected = ['ruby', 'weird', 'brown', 'gold', 'emerald', 'silver']
	# Update the key display when keys are added programmatically
	refresh_key_display()
	# Use explicit $Doors node reference instead of group discovery
	var doors_node = get_node_or_null("Doors")
	if doors_node:
		for door in doors_node.get_children():
			if door is Door:
				door.open()
