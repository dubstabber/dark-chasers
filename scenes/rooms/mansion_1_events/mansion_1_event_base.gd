extends Node


func _level() -> Level:
	var n: Node = self
	while n != null:
		if n is Level:
			return n as Level
		n = n.get_parent()
	return null


func _hud() -> Node:
	var level := _level()
	if not level:
		return null
	return level.get_node_or_null("HUD")


func _players() -> Node:
	var level := _level()
	if not level:
		return null
	return level.get_node_or_null("NavigationRegion3D/Players")


func _enemies() -> Node:
	var level := _level()
	if not level:
		return null
	return level.get_node_or_null("NavigationRegion3D/Enemies")


func _music() -> AudioStreamPlayer:
	var level := _level()
	if not level:
		return null
	return level.get_node_or_null("GlobalMusic") as AudioStreamPlayer


func _show_monster_disappeared_text() -> void:
	var hud := _hud()
	if not hud:
		return
	var random_texts := [
		"[color=#6c6c6c]You:[/color] I think he dissapeared..",
		"[color=#6c6c6c]You:[/color] I have the feeling it's gone...",
		"[color=#6c6c6c]You:[/color] Phew, that was close...",
		"[color=#6c6c6c]You:[/color] I think he's away.",
		"[color=#6c6c6c]You:[/color] I think that thing is gone...",
	]
	hud.show_event_text(random_texts.pick_random(), false, 3.0)
