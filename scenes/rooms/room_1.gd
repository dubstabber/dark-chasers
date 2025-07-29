extends Level


func _ready():
	super._ready()
	
	spawn_player()


func spawn_player():
	var player = Preloads.PLAYER_SCENE.instantiate() as Player
	players.add_child(player)
	player.hud = hud
	respawn(player)


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position
