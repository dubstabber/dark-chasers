class_name PlayerSlideController
extends RefCounted

var slide_timer: float = 0.0
var slide_vector: Vector2 = Vector2.ZERO


func start_slide(input_dir: Vector2, duration: float) -> void:
	slide_timer = max(duration, 0.0)
	slide_vector = input_dir


func update(delta: float) -> bool:
	if slide_timer <= 0.0:
		return false
	slide_timer = max(slide_timer - delta, 0.0)
	return slide_timer <= 0.0


func end_slide() -> void:
	slide_timer = 0.0


func get_slide_timer() -> float:
	return slide_timer


func get_slide_vector() -> Vector2:
	return slide_vector
