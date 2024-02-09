extends Label


func create(log_msg: String, wait_time: float):
	text = log_msg
	get_tree().create_timer(wait_time).connect("timeout", fade_out)
	
func fade_out():
	await create_tween().tween_property(self, "modulate:a", 0, 1.0).finished
	queue_free()
