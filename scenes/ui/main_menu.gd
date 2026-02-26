class_name MainMenu
extends Control

@export var new_game_scene_id: StringName = &"mansion_1"

@onready var _new_game_button: Button = $CenterContainer/Panel/VBox/NewGameButton
@onready var _load_game_button: Button = $CenterContainer/Panel/VBox/LoadGameButton
@onready var _options_button: Button = $CenterContainer/Panel/VBox/OptionsButton
@onready var _exit_game_button: Button = $CenterContainer/Panel/VBox/ExitGameButton


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_exit_game_button.pressed.connect(_on_exit_game_pressed)

	# Placeholder buttons until save/options screens are implemented.
	_load_game_button.disabled = true
	_options_button.disabled = true


func _on_new_game_pressed() -> void:
	var next_scene := _resolve_new_game_scene()
	if next_scene == null:
		push_warning("MainMenu: Could not resolve new game scene id '%s'." % String(new_game_scene_id))
		return

	if Services and Services.level_manager:
		var level_manager := Services.level_manager as LevelManager
		if level_manager:
			var err := level_manager.request_level_transition_scene(next_scene, {
				"from_menu": true,
				"menu_action": "new_game"
			})
			if err == OK:
				return
			push_warning("MainMenu: LevelManager transition failed (err=%d). Falling back to SceneTree change." % err)

	var fallback_err := get_tree().change_scene_to_packed(next_scene)
	if fallback_err != OK:
		push_warning("MainMenu: change_scene_to_packed failed (err=%d)." % fallback_err)


func _resolve_new_game_scene() -> PackedScene:
	if Services:
		var catalog := Services.get_scene_catalog()
		if catalog:
			var map_scene := catalog.get_map_scene(new_game_scene_id)
			if map_scene:
				return map_scene
			return catalog.get_scene(new_game_scene_id)
	return null


func _on_exit_game_pressed() -> void:
	get_tree().quit()
