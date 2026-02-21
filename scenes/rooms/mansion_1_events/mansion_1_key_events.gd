extends "res://scenes/rooms/mansion_1_events/mansion_1_event_base.gd"

const GE = preload("res://scenes/resources/game_event_types.gd")
const SequenceDataScript = preload("res://scenes/resources/sequence_data.gd")

@export var aooni_chase_spawn: NodePath = NodePath("NavigationRegion3D/EventSpawners/FirstAoOniChase")
@export var aooni_chase_disappear_zone: NodePath = NodePath("NavigationRegion3D/DisappearZones/LibraryExitArea")

@export var bars_camera: NodePath = NodePath("NavigationRegion3D/Cameras/BarsCamera2")
@export var bars_spawn: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniBars")
@export var bars_disappear_zone: NodePath = NodePath("NavigationRegion3D/DisappearZones/BarsAoOniRunAway")
@export var bars_break_1: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniBarsBreak")
@export var bars_break_2: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniBarsBreak2")
@export var bars_giveup: NodePath = NodePath("NavigationRegion3D/EventSpawners/AoOniBarsGiveup")

@export var void_spawn: NodePath = NodePath("NavigationRegion3D/PrankSpawners/VoidSpawn")

@export var whiteface_spawn: NodePath = NodePath("NavigationRegion3D/EventSpawners/WhiteFaceSpawn")

var _bars_aooni: CharacterBody3D = null


func _ready() -> void:
	Services.event_bus.subscribe(GE.KEY_SPAWN_AO_ONI_LIBRARY, _on_key_spawn_ao_oni_library)
	Services.event_bus.subscribe(GE.KEY_AO_ONI_TRIES_BARS, _on_key_ao_oni_tries_bars)
	Services.event_bus.subscribe(GE.KEY_TELEPORT_TO_VOID, _on_key_teleport_to_void)
	Services.event_bus.subscribe(GE.KEY_SPAWN_WHITE_FACE, _on_key_spawn_white_face)


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GE.KEY_SPAWN_AO_ONI_LIBRARY, _on_key_spawn_ao_oni_library)
	Services.event_bus.unsubscribe(GE.KEY_AO_ONI_TRIES_BARS, _on_key_ao_oni_tries_bars)
	Services.event_bus.unsubscribe(GE.KEY_TELEPORT_TO_VOID, _on_key_teleport_to_void)
	Services.event_bus.unsubscribe(GE.KEY_SPAWN_WHITE_FACE, _on_key_spawn_white_face)


func _on_key_spawn_ao_oni_library(event: RefCounted) -> void:
	var level := _level()
	var enemies := _enemies()
	if not (level and enemies):
		return

	var body = event.get_body()
	var aooni = Services.get_scene_catalog().aooni_scene.instantiate() as CharacterBody3D
	enemies.add_child(aooni)

	var spawn_node = level.get_node_or_null(aooni_chase_spawn)
	if spawn_node:
		aooni.global_position = spawn_node.global_position
		aooni.current_room = "FirstFloor"
		aooni.current_target = body
		aooni.makepath()

	var disappear_zone = level.get_node_or_null(aooni_chase_disappear_zone)
	if disappear_zone:
		aooni.add_disappear_zone(disappear_zone)

	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().ao_see
		music.volume_db = -5
		music.play()
		aooni.tree_exited.connect(music.stop)

	var hud := _hud()
	if hud:
		hud.show_event_text("THE AO ONI! RUN!", false, 3.0)

	aooni.tree_exited.connect(_on_monster_disappeared)


func _on_key_ao_oni_tries_bars(_event: RefCounted) -> void:
	var level := _level()
	if not level:
		return

	var seq = SequenceDataScript.create(&"ao_oni_tries_bars")
	seq.custom(_spawn_bars_aooni)
	seq.block_players()

	var cam = level.get_node_or_null(bars_camera)
	if cam:
		seq.camera_cut(cam)

	seq.wait(3.0)
	seq.custom(_play_bar_shake)
	seq.wait(0.6)
	seq.custom(_play_bar_shake)
	seq.wait(0.25)
	seq.custom(_play_bar_shake)
	seq.wait(0.25)
	seq.custom(_play_bar_shake)
	seq.wait(0.5)
	seq.custom(_play_bar_shake)
	seq.wait(2.5)
	seq.custom(_bars_aooni_give_up)
	Services.sequence_director.play_sequence(seq)


func _spawn_bars_aooni() -> void:
	var level := _level()
	var enemies := _enemies()
	if not (level and enemies):
		return

	_bars_aooni = Services.get_scene_catalog().aooni_scene.instantiate() as CharacterBody3D
	enemies.add_child(_bars_aooni)

	var spawn_node = level.get_node_or_null(bars_spawn)
	if spawn_node:
		_bars_aooni.global_position = spawn_node.global_position
	_bars_aooni.current_room = "SecondFloor"

	var disappear_zone = level.get_node_or_null(bars_disappear_zone)
	if disappear_zone:
		_bars_aooni.add_disappear_zone(disappear_zone)

	var break_1 = level.get_node_or_null(bars_break_1)
	if break_1:
		_bars_aooni.waypoints.push_back(break_1.position)
	var break_2 = level.get_node_or_null(bars_break_2)
	if break_2:
		_bars_aooni.waypoints.push_back(break_2.position)

	_bars_aooni.tree_exited.connect(_on_ao_oni_gave_up)
	_bars_aooni.makepath()


func _play_bar_shake() -> void:
	if is_instance_valid(_bars_aooni):
		Services.utils.play_sound(Services.get_sfx_catalog().bar_shake, _bars_aooni)


func _bars_aooni_give_up() -> void:
	var level := _level()
	if not level:
		return
	if is_instance_valid(_bars_aooni):
		var giveup_node = level.get_node_or_null(bars_giveup)
		if giveup_node:
			_bars_aooni.waypoints.push_back(giveup_node.position)


func _on_key_teleport_to_void(event: RefCounted) -> void:
	var level := _level()
	if not level:
		return
	var body = event.get_body()
	var spawn_node = level.get_node_or_null(void_spawn)
	if spawn_node:
		body.position = spawn_node.position


func _on_key_spawn_white_face(event: RefCounted) -> void:
	var level := _level()
	var enemies := _enemies()
	if not (level and enemies):
		return

	var body = event.get_body()
	var whiteface = Services.get_scene_catalog().whiteface_scene.instantiate()
	enemies.add_child(whiteface)

	var spawn_node = level.get_node_or_null(whiteface_spawn)
	if spawn_node:
		whiteface.global_position = spawn_node.global_position
	whiteface.current_room = "BigHall"
	whiteface.current_target = body
	whiteface.makepath()


func _on_monster_disappeared() -> void:
	_show_monster_disappeared_text()


func _on_ao_oni_gave_up() -> void:
	var players := _players()
	if not players:
		return
	for player in players.get_children():
		if player is Player:
			Services.camera_manager.set_active_camera(player.camera_3d)
			player.blocked_movement = false
