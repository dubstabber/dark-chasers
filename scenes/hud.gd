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


func _ready():
	timer.connect("timeout", hide_event_text)

	# Initialize key display if keys are already collected
	call_deferred("_initialize_key_display")


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
	if health_ui_value_container and health_ui_value_container.has_method("set_value_with_aooni_font"):
		health_ui_value_container.set_value_with_aooni_font(current_health)


func update_ammo_display(current_ammo: int, _max_ammo: int):
	"""Update the ammo display in the HUD

	Args:
		current_ammo: Current ammo value to display
		_max_ammo: Maximum ammo value (for future use with ammo bars)
	"""
	if ammo_ui_value_container and ammo_ui_value_container.has_method("set_value_with_aooni_font"):
		ammo_ui_value_container.set_value_with_aooni_font(current_ammo)


func update_armor_display(current_armor: int, _max_armor: int):
	"""Update the armor display in the HUD

	Args:
		current_armor: Current armor value to display
		_max_armor: Maximum armor value (for future use with armor bars)
	"""
	if shield_ui_value_container and shield_ui_value_container.has_method("set_value_with_aooni_font"):
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
	if key_ui_container and key_ui_container.has_method("update_keys_ui"):
		key_ui_container.update_keys_ui(collected_keys)


func _initialize_key_display():
	"""Initialize the key display by getting keys from the current level"""
	if key_ui_container and key_ui_container.has_method("refresh_display"):
		key_ui_container.refresh_display()
