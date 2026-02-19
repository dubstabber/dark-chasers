extends CanvasLayer

var tween: Tween
var faded: bool

@onready var black_screen = $BlackScreen
@onready var top_left_container = $TopLeft/VBoxContainer
@onready var mode_label = $MiddleLeft/VBoxContainer/ModeText
@onready var event_label = $Center/VBoxContainer/EventText
@onready var log_label_scene = preload("res://scenes/ui/log_label.tscn")
@onready var timer = $Timer
@onready var health_ui_value_container: HBoxContainer = %HealthUIValueContainer
@onready var ammo_ui_value_container: HBoxContainer = %AmmoUIValueContainer
@onready var shield_ui_value_container: HBoxContainer = %ShieldUIValueContainer
@onready var key_ui_container: HBoxContainer = $TopRight/KeyUIContainer
@onready var damage_overlay: ColorRect = $DamageOverlay
@onready var crosshair: TextureRect = $Crosshair
@onready var bottom_left_container: Control = $BottomLeft
@onready var bottom_right_container: Control = $BottomRight


var _connected_player: CharacterBody3D = null


func _ready():
	timer.connect("timeout", hide_event_text)
	Services.camera_manager.active_camera_changed.connect(_on_active_camera_changed)

	# Initialize key display if keys are already collected
	call_deferred("_initialize_key_display")


func _on_active_camera_changed(new_camera: Camera3D) -> void:
	# Show player UI only when player camera is active
	# Use CameraOwner interface for typed camera access
	var player_camera = CameraOwner.get_camera(_connected_player)
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


func connect_to_player(player: CharacterBody3D) -> void:
	"""Connect HUD directly to player components for automatic updates
	
	This eliminates the need for player.gd to forward signals to the HUD.
	The HUD connects directly to HealthComponent, ArmorComponent, and WeaponManager.
	"""
	if _connected_player == player:
		return
	
	# Disconnect from previous player if any
	if _connected_player:
		disconnect_from_player()
	
	_connected_player = player
	
	# Connect to HealthComponent
	if player.health_component:
		player.health_component.health_changed.connect(_on_player_health_changed)
		update_health_display(player.health_component.current_health, player.health_component.max_health)
	
	# Connect to ArmorComponent
	if player.armor_component:
		player.armor_component.armor_changed.connect(_on_player_armor_changed)
		update_armor_display(player.armor_component.current_armor, player.armor_component.max_armor)
	
	# Connect to WeaponManager
	if player.weapon_manager:
		player.weapon_manager.weapon_ammo_changed.connect(_on_player_ammo_changed)
		player.weapon_manager.weapon_switched.connect(_on_player_weapon_switched)
		# Initialize ammo display
		call_deferred("_initialize_ammo_from_player", player)
	
	# Connect to AmmoComponent for reserve ammo updates
	if player.ammo_component:
		player.ammo_component.ammo_changed.connect(_on_player_reserve_ammo_changed.bind(player))
	
	# Wire up DamageEffectsComponent to use HUD's damage overlay
	# Player is a typed class, so we can access damage_effects_component directly
	if player.damage_effects_component:
		player.damage_effects_component.color_rect = damage_overlay


func disconnect_from_player() -> void:
	"""Disconnect HUD from the current player's components"""
	if not _connected_player:
		return
	
	if _connected_player.health_component and _connected_player.health_component.health_changed.is_connected(_on_player_health_changed):
		_connected_player.health_component.health_changed.disconnect(_on_player_health_changed)
	
	if _connected_player.armor_component and _connected_player.armor_component.armor_changed.is_connected(_on_player_armor_changed):
		_connected_player.armor_component.armor_changed.disconnect(_on_player_armor_changed)
	
	if _connected_player.weapon_manager:
		if _connected_player.weapon_manager.weapon_ammo_changed.is_connected(_on_player_ammo_changed):
			_connected_player.weapon_manager.weapon_ammo_changed.disconnect(_on_player_ammo_changed)
		if _connected_player.weapon_manager.weapon_switched.is_connected(_on_player_weapon_switched):
			_connected_player.weapon_manager.weapon_switched.disconnect(_on_player_weapon_switched)
	
	_connected_player = null


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	update_health_display(current_health, max_health)


func _on_player_armor_changed(current_armor: int, max_armor: int) -> void:
	update_armor_display(current_armor, max_armor)


func _on_player_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	update_ammo_display(current_ammo, max_ammo)


func _on_player_weapon_switched(weapon: WeaponResource) -> void:
	update_ammo_display(weapon.get_current_ammo(), weapon.get_max_ammo_amount())


func _on_player_reserve_ammo_changed(ammo_type: String, current_amount: int, max_amount: int, player: CharacterBody3D) -> void:
	if player.weapon_manager and player.weapon_manager.current_weapon:
		var weapon = player.weapon_manager.current_weapon
		if not weapon.infinite_ammo and weapon.ammo_type == ammo_type:
			update_ammo_display(current_amount, max_amount)


func _initialize_ammo_from_player(player: CharacterBody3D) -> void:
	if player.weapon_manager and player.weapon_manager.current_weapon:
		var weapon = player.weapon_manager.current_weapon
		update_ammo_display(weapon.get_current_ammo(), weapon.get_max_ammo_amount())


func show_black_screen():
	black_screen.color.a = 1.0


func fade_black_screen():
	tween = create_tween()
	tween.tween_property(black_screen, "color:a", 0, 2.0)


func add_log(text: String):
	var log_label = log_label_scene.instantiate()
	top_left_container.add_child(log_label)
	log_label.create(text, 5.0)


func show_event_text(text: String, _faded: bool = true, text_time: float = 0.0):
	faded = _faded
	if faded:
		if event_label.get_child_count():
			tween = create_tween()
			await tween.tween_property(event_label, "modulate:a", 0, 1.0).finished
		event_label.set_text_with_aooni_font(text)
		tween = create_tween()
		tween.tween_property(event_label, "modulate:a", 1, 0.4)
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


func _get_hud_owner() -> CharacterBody3D:
	"""Get the player that owns this HUD instance

	Returns:
		The player CharacterBody3D that this HUD belongs to, or null if not found
	"""
	# Use explicit connected player reference instead of scene-tree discovery
	return _connected_player


func hide_event_text():
	if faded:
		tween = create_tween()
		await tween.tween_property(event_label, "modulate:a", 0, 1.0).finished
	else:
		event_label.modulate.a = 0
	event_label.set_text_with_aooni_font("")


func _on_player_mode_changed(mode, value):
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
