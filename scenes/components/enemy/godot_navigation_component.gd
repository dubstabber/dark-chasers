class_name GodotNavigationComponent
extends EnemyNavigationComponent

@export var navigation_agent: NavigationAgent3D


func _ready() -> void:
	super._ready()
	if navigation_agent:
		navigation_agent.target_reached.connect(_on_nav_target_reached)
		navigation_agent.link_reached.connect(_on_nav_link_reached)
		navigation_agent.waypoint_reached.connect(_on_nav_waypoint_reached)


func _on_target_set(pos: Vector3) -> void:
	if navigation_agent:
		navigation_agent.target_position = pos


func get_next_path_position() -> Vector3:
	if navigation_agent:
		return navigation_agent.get_next_path_position()
	return Vector3.ZERO


func is_target_reached() -> bool:
	if navigation_agent:
		return navigation_agent.is_target_reached()
	return true


func distance_to_target() -> float:
	if navigation_agent:
		return navigation_agent.distance_to_target()
	return 0.0


func is_navigation_finished() -> bool:
	if navigation_agent:
		return navigation_agent.is_navigation_finished()
	return true


func _on_nav_target_reached() -> void:
	target_reached.emit()


func _on_nav_link_reached(details: Dictionary) -> void:
	link_reached.emit(details)


func _on_nav_waypoint_reached(details: Dictionary) -> void:
	waypoint_reached.emit(details)
