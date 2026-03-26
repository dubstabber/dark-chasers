extends Node


@export var hidden_narrow_door: Door
@export var small_basement_aomika_spawn: Marker3D
@export var small_basement_aomika_disappear_zone: Area3D

@export var quick_aooni_behind_door: Enemy



func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.AREA_SECRET_AOONI_PRANK, _on_area_aooni_prank)
	Services.event_bus.subscribe(GameEventTypes.AREA_SMALL_BASMENT_AOMIKA_APPEAR, _on_area_small_basement_aomika_appear)
	if quick_aooni_behind_door:
		quick_aooni_behind_door.tree_exited.connect(_on_quick_aooni_behind_door_disappeared)


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.AREA_SECRET_AOONI_PRANK, _on_area_aooni_prank)
	Services.event_bus.unsubscribe(GameEventTypes.AREA_SMALL_BASMENT_AOMIKA_APPEAR, _on_area_small_basement_aomika_appear)


func _hud() -> Node:
	if not Services.world_context:
		return null
	return Services.world_context.get_hud()

func _level() -> Level:
	if not Services.world_context:
		return null
	var level := Services.world_context.get_level_node()
	if level and level is Level:
		return level as Level
	return null


func _music() -> AudioStreamPlayer:
	if not Services.world_context:
		return null
	return Services.world_context.get_global_music_player()


func _enemies() -> Node:
	if not Services.world_context:
		return null
	return Services.world_context.get_enemies_node()


func _on_area_aooni_prank(_event: GameEvent) -> void:
	if hidden_narrow_door:
		hidden_narrow_door.open()
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#a600cf]Ao oni:[/color] Hello.", false, 3.0)


func _on_area_small_basement_aomika_appear(_event: GameEvent) -> void:
	var level := _level()
	if not level:
		return

	var enemies := _enemies()
	if not enemies:
		return

	var aomika = Services.get_scene_catalog().get_enemy_scene(&"aomika").instantiate() as CharacterBody3D
	enemies.add_child(aomika)

	if small_basement_aomika_spawn:
		aomika.global_position = small_basement_aomika_spawn.global_position
		aomika.current_room = "SmallBasement"
		aomika.makepath()

	if small_basement_aomika_disappear_zone:
		aomika.add_disappear_zone(small_basement_aomika_disappear_zone)

	var music := _music()
	if music:
		music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
		music.volume_db = -5
		music.play()
		aomika.tree_exited.connect(music.stop)

	var hud := _hud()
	if hud:
		hud.show_event_text("The Ao Oni! Run!!!", false, 3.0)

	aomika.tree_exited.connect(_on_aomika_disappeared)


func _on_aomika_disappeared() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it disappeared...", false, 3.0)


func _on_quick_aooni_behind_door_disappeared() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it disappeared...", false, 3.0)
