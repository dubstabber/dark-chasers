extends Level


func _ready():
	super._ready()

func spawn_player() -> Player:
	var player: Player = super.spawn_player()
	player.current_room = "MainRoom"
	return player
