extends CanvasLayer

var tween: Tween
var faded: bool

@onready var black_screen = $BlackScreen
@onready var top_left_container = $TopLeft/VBoxContainer
@onready var mode_label = $MiddleLeft/VBoxContainer/ModeText
@onready var event_label = $Center/VBoxContainer/EventText
@export var log_label_scene: PackedScene
@onready var timer = $Timer
@onready var health_ui_value_container: HBoxContainer = %HealthUIValueContainer
@onready var ammo_ui_value_container: HBoxContainer = %AmmoUIValueContainer
@onready var shield_ui_value_container: HBoxContainer = %ShieldUIValueContainer
@onready var key_ui_container: HBoxContainer = $TopRight/KeyUIContainer
@onready var damage_overlay: ColorRect = $DamageOverlay
@onready var crosshair: TextureRect = $Crosshair
@onready var bottom_left_container: Control = $BottomLeft
@onready var bottom_right_container: Control = $BottomRight


var _connected_provider: Node = null
var _reserve_ammo_callback: Callable
var _player_binding_controller := HudPlayerBindingController.new()


func _ready():
	timer.connect("timeout", hide_event_text)
	Services.camera_manager.active_camera_changed.connect(_on_active_camera_changed)
	Services.event_bus.subscribe(GameEventTypes.PLAYER_MODE_CHANGED, _on_player_mode_changed_event)

	# Initialize key display if keys are already collected
	call_deferred("_initialize_key_display")


func _exit_tree() -> void:
	if Services.camera_manager and Services.camera_manager.active_camera_changed.is_connected(_on_active_camera_changed):
		Services.camera_manager.active_camera_changed.disconnect(_on_active_camera_changed)
	if Services.event_bus:
		Services.event_bus.unsubscribe(GameEventTypes.PLAYER_MODE_CHANGED, _on_player_mode_changed_event)
	disconnect_from_player()


func _on_active_camera_changed(new_camera: Camera3D) -> void:
	# Show player UI only when player camera is active
	# Use HUD provider adapter for typed camera access
	var player_camera = HudDataProvider.get_camera(_connected_provider)
	if player_camera:
		var is_player_camera = new_camera == player_camera
		_set_player_ui_visible(is_player_camera)


func _set_player_ui_visible(show_ui: bool) -> void:
	"""Show or hide all player-specific UI elements (crosshair, health, armor, ammo, damage overlay)"""
	if crosshair:
		crosshair.visible = show_ui
	if bottom_left_container:
		bottom_left_container.visible = show_ui
	if bottom_right_container:
		bottom_right_container.visible = show_ui
	if damage_overlay:
		damage_overlay.visible = show_ui


func connect_to_player(provider: Node) -> void:
	"""Connect HUD to a HUD data provider for automatic updates
	
	This eliminates the need for player.gd to forward signals to the HUD.
	The HUD depends on the HudDataProvider contract instead of concrete player fields.
	"""
	if _connected_provider == provider:
		return
	
	# Disconnect from previous provider if any
	if _connected_provider:
		disconnect_from_player()
	
	_connected_provider = provider
	_reserve_ammo_callback = Callable(self, "_on_player_reserve_ammo_changed").bind(provider)
	_player_binding_controller.connect_player_signals(
		provider,
		Callable(self, "_on_player_health_changed"),
		Callable(self, "_on_player_armor_changed"),
		Callable(self, "_on_player_ammo_changed"),
		Callable(self, "_on_player_weapon_switched"),
		_reserve_ammo_callback,
		damage_overlay
	)
	
	var health_component := HudDataProvider.get_health_component(provider)
	if health_component:
		update_health_display(health_component.current_health, health_component.max_health)
	
	var armor_component := HudDataProvider.get_armor_component(provider)
	if armor_component:
		update_armor_display(armor_component.current_armor, armor_component.max_armor)
	
	if HudDataProvider.get_weapon_manager(provider):
		call_deferred("_initialize_ammo_from_provider", provider)


func disconnect_from_player() -> void:
	"""Disconnect HUD from the current player's components"""
	if not _connected_provider:
		return

	_player_binding_controller.disconnect_player_signals(
		_connected_provider,
		Callable(self, "_on_player_health_changed"),
		Callable(self, "_on_player_armor_changed"),
		Callable(self, "_on_player_ammo_changed"),
		Callable(self, "_on_player_weapon_switched"),
		_reserve_ammo_callback
	)

	_reserve_ammo_callback = Callable()
	_connected_provider = null


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	update_health_display(current_health, max_health)


func _on_player_armor_changed(current_armor: int, max_armor: int) -> void:
	update_armor_display(current_armor, max_armor)


func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	update_ammo_display(current_ammo, max_ammo)


func _on_player_weapon_switched(weapon: WeaponResource) -> void:
	update_ammo_display(weapon.get_current_ammo(), weapon.get_max_ammo_amount())


func _on_player_reserve_ammo_changed(ammo_type: String, current_amount: int, max_amount: int, provider: Node) -> void:
	var weapon := HudDataProvider.get_current_weapon(provider)
	if weapon and not weapon.infinite_ammo and weapon.ammo_type == ammo_type:
		update_ammo_display(current_amount, max_amount)


func _initialize_ammo_from_provider(provider: Node) -> void:
	var weapon := HudDataProvider.get_current_weapon(provider)
	if weapon:
		update_ammo_display(weapon.get_current_ammo(), weapon.get_max_ammo_amount())


func show_black_screen():
	black_screen.color.a = 1.0


func fade_to_black(duration: float = 0.25):
	_restart_tween().tween_property(black_screen, "color:a", 1.0, duration)


func fade_from_black(duration: float = 2.0):
	_restart_tween().tween_property(black_screen, "color:a", 0.0, duration)


func _restart_tween() -> Tween:
	if tween:
		tween.kill()
	tween = create_tween()
	return tween


func fade_black_screen():
	fade_from_black(2.0)


func add_log(text: String):
	if not log_label_scene:
		push_warning("HUD: log_label_scene is not assigned")
		return
	var log_label = log_label_scene.instantiate()
	top_left_container.add_child(log_label)
	log_label.create(text, 5.0)


func show_event_text(text: String, _faded: bool = true, text_time: float = 0.0):
	faded = _faded
	if faded:
		if event_label.get_child_count():
			await _restart_tween().tween_property(event_label, "modulate:a", 0, 1.0).finished
		event_label.set_text_with_aooni_font(text)
		_restart_tween().tween_property(event_label, "modulate:a", 1, 0.4)
	else:
		event_label.set_text_with_aooni_font(text)
		event_label.modulate.a = 1
	if text_time:
		if not timer.is_stopped():
			timer.stop()
		timer.wait_time = text_time
		timer.start()


func show_event_text_for_player(player: CharacterBody3D, text: String, _faded: bool = true, text_time: float = 0.0):
	"""Show event text only if this HUD belongs to the specified player

	This method allows for player-specific event text display in multiplayer scenarios.
	If the HUD doesn't belong to the specified player, the text won't be shown.

	Args:
		player: The player who should see this event text
		text: The text to display
		_faded: Whether to use fade animation
		text_time: How long to display the text (0 = indefinite)
	"""
	# Get the player that owns this HUD by traversing up the scene tree
	var hud_owner = _get_hud_owner()

	# Only show the text if this HUD belongs to the specified player
	if hud_owner == player:
		show_event_text(text, _faded, text_time)


func _get_hud_owner() -> Node:
	"""Get the player that owns this HUD instance

	Returns:
		The provider node that this HUD belongs to, or null if not found
	"""
	# Use explicit connected provider reference instead of scene-tree discovery
	return _connected_provider


func hide_event_text():
	if faded:
		await _restart_tween().tween_property(event_label, "modulate:a", 0, 1.0).finished
	else:
		event_label.modulate.a = 0
	event_label.set_text_with_aooni_font("")


func _on_player_mode_changed_event(event: RefCounted) -> void:
	var mode = event.payload.get("mode", "")
	var value = event.payload.get("value", false)
	var event_player = event.payload.get("player", null)
	
	# Only respond if this HUD belongs to the player that triggered the event
	if event_player and _connected_provider and event_player != _connected_provider:
		return
	
	_apply_mode_change(mode, value)


func _apply_mode_change(mode: String, value: bool) -> void:
	match mode:
		"clip_mode":
			if value:
				mode_label.text = "Clip mode enabled"
			else:
				mode_label.text = ""


func update_health_display(current_health: int, _max_health: int):
	"""Update the health display in the HUD

	Args:
		current_health: Current health value to display
		_max_health: Maximum health value (for future use with health bars)
	"""
	# UI containers are @onready scene references with known scripts
	if health_ui_value_container:
		health_ui_value_container.set_value_with_aooni_font(current_health)


func update_ammo_display(current_ammo: int, _max_ammo: int):
	"""Update the ammo display in the HUD

	Args:
		current_ammo: Current ammo value to display
		_max_ammo: Maximum ammo value (for future use with ammo bars)
	"""
	if ammo_ui_value_container:
		ammo_ui_value_container.set_value_with_aooni_font(current_ammo)


func update_armor_display(current_armor: int, _max_armor: int):
	"""Update the armor display in the HUD

	Args:
		current_armor: Current armor value to display
		_max_armor: Maximum armor value (for future use with armor bars)
	"""
	if shield_ui_value_container:
		# When armor is 0, we don't want to show any digits in the HUD. The
		# ui_bitmap_text script treats negative values (e.g. -1) as a sentinel
		# to hide the value completely. Re-use that convention here.
		var display_value := -1 if current_armor == 0 else current_armor
		shield_ui_value_container.set_value_with_aooni_font(display_value)


func update_keys_display(collected_keys: Array):
	"""Update the keys display in the HUD

	Args:
		collected_keys: Array of key types that have been collected
	"""
	if key_ui_container:
		key_ui_container.update_keys_ui(collected_keys)


func _initialize_key_display():
	"""Initialize the key display by getting keys from the current level"""
	if key_ui_container:
		key_ui_container.refresh_display()
