extends Control

@onready var log_text = $AoOniFont


func _ready():
	log_text.set_font_scale(0.3)
	custom_minimum_size = Vector2(1000,10)


func create(log_msg: String, wait_time: float):
	log_text.set_text_with_aooni_font(log_msg)
	get_tree().create_timer(wait_time).connect("timeout", fade_out)


func fade_out():
	await create_tween().tween_property(self, "modulate:a", 0, 1.0).finished
	queue_free()
