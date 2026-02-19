extends Level

const GE = preload("res://scenes/resources/game_event_types.gd")

@onready var global_music: AudioStreamPlayer = $GlobalMusic


func _ready():
	super._ready()
	spawn_player()
	#open_all_doors()


func _exit_tree():
	super._exit_tree()


func spawn_player():
	var player = Services.preloads.PLAYER_SCENE.instantiate() as Player
	players.add_child(player)
	# player.blocked_movement = true
	setup_player(player) # Centralized HUD connection via Level base class
	#hud.show_black_screen()
	
	#respawn(player)
	test_respawn(player)
	player.debug_camera = %DebugCamera3D
	#hud.show_event_text("We heard a rumor about a mansion on the outskirts of town.")
	#await get_tree().create_timer(6.0).timeout
	#hud.show_event_text("They say there is a monster that lives there_")
	#await get_tree().create_timer(4.5).timeout
	#hud.hide_event_text()
	#player.blocked_movement = false
	#hud.fade_black_screen()


func respawn(p):
	p.position = player_spawners.get_children().pick_random().global_position
	p.current_room = "FirstFloor"
	p.rotate_y(3.15)
	Services.utils.play_sound(Services.preloads.SPAWN_SOUND, p)


func test_respawn(p):
	p.position = $NavigationRegion3D/TestSpawn.position
	p.current_room = "FirstFloor"
	Services.utils.play_sound(Services.preloads.SPAWN_SOUND, p)


func _on_ladder_body_entered(body):
	if body.is_in_group("player") and body.movement_component:
		body.movement_component.set_climbing(true)


func _on_ladder_body_exited(body):
	if body.is_in_group("player") and body.movement_component:
		body.movement_component.set_climbing(false)


func _door_locked(text, triggering_player):
	if triggering_player:
		# Show event text only to the specific player who triggered the interaction
		hud.show_event_text_for_player(triggering_player, text, false, 3.0)
	# If no triggering player is specified (e.g., enemy interaction), don't show any message


# For testing purposes
func open_all_doors():
	keys_collected = ['ruby', 'weird', 'brown', 'gold', 'emerald', 'silver']
	# Update the key display when keys are added programmatically
	refresh_key_display()
	# Use explicit $Doors node reference instead of group discovery
	var doors_node = get_node_or_null("Doors")
	if doors_node:
		for door in doors_node.get_children():
			if door is Openable:
				door.open()
