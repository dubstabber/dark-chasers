extends Level


func _ready():
	super._ready()
	
	spawn_player()


func spawn_player():
	var player = Preloads.PLAYER_SCENE.instantiate() as Player
	players.add_child(player)
	setup_player(player) # Centralized HUD connection via Level base class
	respawn(player)


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position
