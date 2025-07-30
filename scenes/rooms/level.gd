class_name Level extends Node3D

# Base key collection system - can be overridden by specific maps
var keys_collected: Array = []

@onready var hud = $HUD
@onready var transitions = get_node_or_null("%Transitions")
@onready var player_spawners = get_node_or_null("%PlayerSpawners")
@onready var players = get_node_or_null("%Players")
@onready var enemies = get_node_or_null("%Enemies")


func _ready():
	# Add this level to the "level" group so UI components can find it
	add_to_group("level")

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var doors = get_tree().get_nodes_in_group("door")
	for door in doors:
		if "door_locked" in door: door.connect("door_locked", _door_locked)
		
	var keys = get_tree().get_nodes_in_group("key")
	for key in keys:
		key.connect("key_collected", _key_body_entered)
	var items = get_tree().get_nodes_in_group("item")
	for item in items:
		item.connect("item_pickedup", hud.add_log)
	var buttons = get_tree().get_nodes_in_group("button")
	for button in buttons:
		button.connect("button_pressed", _handle_button_event)
	var area_events = get_tree().get_nodes_in_group("area_event")
	for area_event in area_events:
		area_event.connect("event_triggered", _handle_area_event)
	
	if transitions:
		for t in transitions.get_children():
			for m in t.get_children():
				if m.is_in_group("spawn_point"):
					t.connect("body_entered", handle_transition.bind(t.name, m))
				if m.is_in_group("manual_spawn_point"):
					t.connect("body_entered", _on_transition_entered.bind(m))
					t.connect("body_exited", _on_transition_exited)
	for mesh in %Map.get_children():
		if mesh is not MeshInstance3D: continue
		var material = mesh.get_active_material(0)
		if material and material.has_method('set_transparency') and material.transparency == 0:
			material.transparency = 1
			material.depth_draw_mode = 1
	

func _physics_process(_delta):
	if Input.is_action_just_pressed("menu"):
		get_tree().quit()
	if Input.is_action_just_pressed("toggle-window-mode"):
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func handle_transition(body, area3dname, marker):
	body.current_room = transitions.map_transitions[body.current_room][area3dname]
	body.position = marker.global_position
	if "find_path_timer" in body:
		body.find_path_timer.wait_time = 0.1
		body.find_path_timer.start()


func _on_transition_entered(body, transitor):
	if body.is_in_group("player") and transitor:
		if "transit_pos" in body:
			body.transit_pos = transitor


func _on_transition_exited(body):
	if body.is_in_group("player"):
		if "transit_pos" in body:
			body.transit_pos = null


func _key_body_entered(body, key_type, event, message_text):
	# Add log message to HUD
	if hud and hud.has_method("add_log"):
		hud.add_log(message_text)

	# Add key to collection if not already collected
	if key_type and key_type not in keys_collected:
		keys_collected.push_back(key_type)

		# Update the key display in the HUD
		if hud and hud.has_method("update_keys_display"):
			hud.update_keys_display(keys_collected)

	# Handle any specific events (can be overridden by child classes)
	_handle_key_event(body, key_type, event, message_text)


func _handle_key_event(_body, _key_type, _event, _message_text):
	"""Override this method in specific maps to handle key-specific events"""
	pass


func refresh_key_display():
	"""Manually refresh the key display - useful for testing or when keys are added programmatically"""
	if hud and hud.has_method("update_keys_display"):
		hud.update_keys_display(keys_collected)
func _handle_button_event(_body, _event): pass
func _handle_area_event(_body: CharacterBody3D, _event): pass
func _door_locked(_text): pass
