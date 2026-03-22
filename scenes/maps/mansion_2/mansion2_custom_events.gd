extends Node

@export var ao_oni1: Enemy
var _ao_oni1_triggered := false


func _ready() -> void:
	Services.event_bus.subscribe(GameEventTypes.ENEMY_TARGET_ACQUIRED, _on_aooni_target_acquired)
	


func _exit_tree() -> void:
	Services.event_bus.unsubscribe(GameEventTypes.ENEMY_TARGET_ACQUIRED, _on_aooni_target_acquired)


func _hud() -> Node:
	if not Services.world_context:
		return null
	return Services.world_context.get_hud()


func _music() -> AudioStreamPlayer:
	if not Services.world_context:
		return null
	return Services.world_context.get_global_music_player()

func _on_aooni_target_acquired(event: GameEvent) -> void:
	if _ao_oni1_triggered: 
		return
	if ao_oni1 == event.source:
		var hud := _hud()
		if hud:
			hud.show_event_text("The Ao oni! Run!", false, 3.0)
		ao_oni1.tree_exited.connect(_on_aooni1_disappear)
		var music := _music()
		if music:
			music.stream = Services.get_sfx_catalog().get_sound(&"ao_see")
			music.volume_db = -5
			music.play()
			ao_oni1.tree_exited.connect(music.stop)
		_ao_oni1_triggered = true


func _on_aooni1_disappear() -> void:
	var hud := _hud()
	if hud:
		hud.show_event_text("[color=#6c6c6c]You:[/color] I think it disappeared...", false, 3.0)
