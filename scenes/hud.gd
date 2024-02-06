extends CanvasLayer

var tween: Tween

@onready var mode_label = $MarginContainer/VBoxContainer/ModeText
@onready var event_label = $MarginContainer/VBoxContainer/EventText
@onready var black_screen = $BlackScreen


func _ready():
	pass


func show_black_screen():
	black_screen.color.a = 1.0


func fade_black_screen():
	tween = create_tween()
	tween.tween_property(black_screen, "color:a", 0, 2.0)


func show_event_text(text: String):
	if event_label.get_child_count():
		tween = create_tween()
		await tween.tween_property(event_label, "modulate:a", 0, 1.0).finished
	event_label.set_text_with_custom_font(text)
	tween = create_tween()
	await tween.tween_property(event_label, "modulate:a", 1, 0.4).finished


func hide_event_text():
	tween = create_tween()
	tween.tween_property(event_label, "modulate:a", 0, 1.0)


func _on_player_mode_changed(mode, value):
	match mode:
		"clip_mode":
			if value:
				mode_label.text = "Clip mode enabled"
			else:
				mode_label.text = ""
