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


func _ready():
	timer.connect("timeout", hide_event_text)


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
		print("Health display updated: ", current_health) # Debug - remove in production
