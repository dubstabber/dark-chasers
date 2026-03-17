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
	
	var player_rotation := player.global_rotation
	player_rotation.y = STARTING_YAW
	player.global_rotation = player_rotation
	
	return player
