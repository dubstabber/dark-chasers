extends Level

const STARTING_ROOM := "MainHall"
const STARTING_YAW := PI
const WEATHER_CONTROLLER_PATH := NodePath("WeatherController")
const WEATHER_CONTROLLER_SCRIPT = preload("res://scenes/maps/mansion_2/mansion_2_weather_controller.gd")


func _ready():
	super._ready()
	spawn_player()
	$Doors/AoMovingWall11.open()
	_initialize_weather()
	#open_all_doors()


func _exit_tree():
	var weather_controller: Node = get_node_or_null(WEATHER_CONTROLLER_PATH)
	if weather_controller != null and weather_controller.get_script() == WEATHER_CONTROLLER_SCRIPT:
		weather_controller.call("stop_weather")
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


func _initialize_weather() -> void:
	var weather_controller: Node = get_node_or_null(WEATHER_CONTROLLER_PATH)
	if weather_controller != null and weather_controller.get_script() == WEATHER_CONTROLLER_SCRIPT:
		weather_controller.call("start_weather")


func test_respawn(player: CharacterBody3D) -> void:
	var test_spawn := get_node_or_null("NavigationRegion3D/TestSpawn") as Node3D
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
