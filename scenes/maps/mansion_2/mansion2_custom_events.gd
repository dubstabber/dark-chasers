extends Node

@export var ao_oni1: Enemy
@export var ao_oni2: Enemy
@export var fuwatty: Enemy

@export var blueberry_farm_fuwatty: Enemy
@export var blueberry_farm_jellyfish: Enemy
@export var blueberry_farm_hundred_eyed_monster: Enemy
@export var blueberry_farm_squatto: Enemy
@export var blueberry_farm_hunchback_monster: Enemy

@export var blueberry_door: Door
@export var blueberry_farm_blocker: StaticBody3D

@export var blueberry_farm_open_door_zone: Area3D

@export var blueberry_farm_all_enemies_disappear_zone: Area3D

var _ao_oni1_triggered := false
var _ao_oni2_triggered := false
var _fuwatty_triggered := false
var _blueberry_farm_open_door_zone_triggered := false
var _blueberry_farm_all_enemies_disappear_zone_triggered := false


func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.ENEMY_TARGET_ACQUIRED, _on_aooni_target_acquired)
	Services.event_bus.subscribe(GameEventTypes.CUSTOM_BLUEBERRY_FARM_CHASE_SEQUENCE, _on_blueberry_farm_chase_sequence)
	if blueberry_farm_open_door_zone:
		blueberry_farm_open_door_zone.body_entered.connect(_on_blueberry_farm_open_door_zone_body_entered)
	if blueberry_farm_all_enemies_disappear_zone:
		blueberry_farm_all_enemies_disappear_zone.body_entered.connect(_on_blueberry_farm_all_enemies_disappear_zone_body_entered)


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.ENEMY_TARGET_ACQUIRED, _on_aooni_target_acquired)
	Services.event_bus.unsubscribe(GameEventTypes.CUSTOM_BLUEBERRY_FARM_CHASE_SEQUENCE, _on_blueberry_farm_chase_sequence)
	if blueberry_farm_open_door_zone:
		blueberry_farm_open_door_zone.body_entered.disconnect(_on_blueberry_farm_open_door_zone_body_entered)
	if blueberry_farm_all_enemies_disappear_zone:
		blueberry_farm_all_enemies_disappear_zone.body_entered.disconnect(_on_blueberry_farm_all_enemies_disappear_zone_body_entered)


func _hud() -> Node:
	if not Services.world_context:
		return null
	return Services.world_context.get_hud()


func _music() -> AudioStreamPlayer:
	if not Services.world_context:
		return null
	return Services.world_context.get_global_music_player()

func _on_aooni_target_acquired(event: GameEvent) -> void:
	var spotted_player: Node = event.payload.get("body")
	if not (spotted_player is CharacterBody3D):
		return

	
	var hud := _hud()
	# Side effects (music + disappear text) should only happen once per enemy.
	if ao_oni1 == event.source:
		if _ao_oni1_triggered:
			return
		ao_oni1.tree_exited.connect(_on_aooni1_disappear)
		var music := _music()
		if music:
			music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
			music.volume_db = -5
			music.play()
			ao_oni1.tree_exited.connect(music.stop)
		_ao_oni1_triggered = true
	elif ao_oni2 == event.source:
		if _ao_oni2_triggered:
			return
		if hud and spotted_player:
			hud.show_event_text_for_player(spotted_player, "The Ao oni! Run!", false, 3.0)
		ao_oni2.tree_exited.connect(_on_aooni2_disappear)
		var music := _music()
		if music:
			music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
			music.volume_db = -5
			music.play()
			ao_oni2.tree_exited.connect(music.stop)
		_ao_oni2_triggered = true
	elif fuwatty == event.source:
		if _fuwatty_triggered:
			return
		if hud and spotted_player:
			hud.show_event_text_for_player(spotted_player, "The Ao Oni! Run!", false, 3.0)
		fuwatty.tree_exited.connect(_on_fuwatty_disappear)
		var music := _music()
		if music:
			music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
			music.volume_db = -5
			music.play()
			fuwatty.tree_exited.connect(music.stop)
		_fuwatty_triggered = true


func _on_aooni1_disappear() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it disappeared...", false, 3.0)


func _on_aooni2_disappear() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it's gone now...", false, 3.0)


func _on_fuwatty_disappear() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it disappeared...", false, 3.0)


func _on_blueberry_farm_chase_sequence(event: GameEvent) -> void:
	var player: Player = event.payload.get("body")
	if not (player is Player):
		return

	var seq := SequenceData.create(&"blueberry_farm_chase_sequence")
	seq.wait(randf_range(6.0, 13.0))
	seq.custom(_on_blueberry_farm_chase_sequence_custom.bind(player))
	seq.wait(randf_range(1.0, 10.0))
	seq.custom(_on_blueberry_farm_chase_sequence_custom_2.bind(player))
	Services.sequence_director.play_sequence(seq)


func _on_blueberry_farm_chase_sequence_custom(player: Player) -> void:
	blueberry_farm_blocker.queue_free()
	var first_enemy: Enemy = [blueberry_farm_jellyfish, blueberry_farm_squatto].pick_random()
	first_enemy.current_target = player
	first_enemy.makepath()


func _on_blueberry_farm_chase_sequence_custom_2(player: Player) -> void:
	if blueberry_farm_jellyfish and blueberry_farm_jellyfish.current_target != player:
		blueberry_farm_jellyfish.current_target = player
		blueberry_farm_jellyfish.makepath()
	if blueberry_farm_squatto and blueberry_farm_squatto.current_target != player:
		blueberry_farm_squatto.current_target = player
		blueberry_farm_squatto.makepath()


func _on_blueberry_farm_open_door_zone_body_entered(body: Enemy) -> void:
	if not body:
		return
	if _blueberry_farm_open_door_zone_triggered:
		return
	_blueberry_farm_open_door_zone_triggered = true
	blueberry_door.open()


func _on_blueberry_farm_all_enemies_disappear_zone_body_entered(body: Player) -> void:
	if not body:
		return
	if _blueberry_farm_all_enemies_disappear_zone_triggered or not _blueberry_farm_open_door_zone_triggered:
		return
	_blueberry_farm_all_enemies_disappear_zone_triggered = true
	if blueberry_farm_fuwatty:
		blueberry_farm_fuwatty.queue_free()
	if blueberry_farm_jellyfish:
		blueberry_farm_jellyfish.queue_free()
	if blueberry_farm_hundred_eyed_monster:
		blueberry_farm_hundred_eyed_monster.queue_free()
	if blueberry_farm_squatto:
		blueberry_farm_squatto.queue_free()
	if blueberry_farm_hunchback_monster:
		blueberry_farm_hunchback_monster.queue_free()
