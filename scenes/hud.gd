extends CanvasLayer

var tween: Tween

@onready var black_screen = $BlackScreen
@onready var top_left_container = $TopLeft/VBoxContainer
@onready var mode_label = $MiddleLeft/VBoxContainer/ModeText
@onready var event_label = $Center/VBoxContainer/EventText
@onready var log_label_scene = load("res://scenes/ui/log_label.tscn")


func _ready():
	pass


func show_black_screen():
	black_screen.color.a = 1.0


func fade_black_screen():
	tween = create_tween()
	tween.tween_property(black_screen, "color:a", 0, 2.0)


func add_log(text: String):
	var log_label = log_label_scene.instantiate()
	top_left_container.add_child(log_label)
	log_label.create(text, 5.0)


func show_event_text(text: String, faded := true, text_time := 0.0):
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
		await get_tree().create_timer(text_time).timeout
		hide_event_text(faded)

func hide_event_text(faded := true):
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

