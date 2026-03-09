extends Level

const STARTING_ROOM := "FirstFloor"
const STARTING_YAW := PI
const USE_TEST_SPAWN := false

@onready var global_music: AudioStreamPlayer = $GlobalMusic


func _ready():
	super._ready()
	spawn_player()
	#open_all_doors()


func _exit_tree():
	super._exit_tree()


func spawn_player() -> Player:
	var player: Player = super.spawn_player()
	Services.camera_manager.set_debug_camera(%DebugCamera3D)
	Services.camera_manager.set_player_camera(player.camera_3d)

	if USE_TEST_SPAWN:
		player.blocked_movement = false
		return player

	player.blocked_movement = true
	if hud:
		hud.show_black_screen()
	_run_intro_sequence(player)
	return player


func _run_intro_sequence(player: Player) -> void:
	if not hud:
		player.blocked_movement = false
		return

	await get_tree().process_frame
	await hud.show_event_text("We heard a rumor about a mansion on the outskirts of town.")
	await get_tree().create_timer(6.0).timeout
	await hud.show_event_text("They say there is a monster that lives there_")
	await get_tree().create_timer(4.5).timeout
	await hud.hide_event_text()
	if not is_instance_valid(player):
		return
	player.blocked_movement = false
	hud.fade_black_screen()


func respawn(player: CharacterBody3D) -> void:
	if USE_TEST_SPAWN:
		test_respawn(player)
		return

	super.respawn(player)
	RoomAware.set_current_room(player, STARTING_ROOM)

	var player_rotation := player.global_rotation
	player_rotation.y = STARTING_YAW
	player.global_rotation = player_rotation

	Services.utils.play_sound(Services.get_sfx_catalog().get_sound(&"spawn"), player)


func test_respawn(player: CharacterBody3D) -> void:
	var test_spawn := get_node_or_null("NavigationRegion3D/TestSpawn") as Node3D
	if test_spawn == null:
		push_warning("mansion_1: TestSpawn node is missing")
		return

	TransitionArrival.apply(player, test_spawn)
	RoomAware.set_current_room(player, STARTING_ROOM)
	Services.utils.play_sound(Services.get_sfx_catalog().get_sound(&"spawn"), player)


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
			if door is Door:
				door.open()
