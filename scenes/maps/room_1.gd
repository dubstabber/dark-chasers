extends Level


func _ready():
	super._ready()
	spawn_player()

func spawn_player():
	var player: Player = super.spawn_player()
	player.current_room = "MainRoom"
