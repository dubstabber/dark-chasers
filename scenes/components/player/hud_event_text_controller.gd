class_name HudEventTextController
extends RefCounted

var _faded := false


func show_text(event_label: Node, timer: Timer, restart_tween_callback: Callable, text: String, faded: bool, text_time: float) -> void:
	if event_label == null:
		return
	_faded = faded
	if _faded:
		if event_label.get_child_count() > 0 and restart_tween_callback.is_valid():
			await restart_tween_callback.call().tween_property(event_label, "modulate:a", 0, 1.0).finished
		event_label.set_text_with_aooni_font(text)
		if restart_tween_callback.is_valid():
			restart_tween_callback.call().tween_property(event_label, "modulate:a", 1, 0.4)
	else:
		event_label.set_text_with_aooni_font(text)
		event_label.modulate.a = 1
	if timer != null and text_time > 0.0:
		if not timer.is_stopped():
			timer.stop()
		timer.wait_time = text_time
		timer.start()


func hide_text(event_label: Node, restart_tween_callback: Callable) -> void:
	if event_label == null:
		return
	if _faded and restart_tween_callback.is_valid():
		await restart_tween_callback.call().tween_property(event_label, "modulate:a", 0, 1.0).finished
	else:
		event_label.modulate.a = 0
	event_label.set_text_with_aooni_font("")
