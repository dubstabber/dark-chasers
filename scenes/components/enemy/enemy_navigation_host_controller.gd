class_name EnemyNavigationHostController
extends RefCounted


func refresh_navigation_component(
	owner_name: String,
	current_component: EnemyNavigationComponent,
	available_components: Array[EnemyNavigationComponent],
	requested_mode: StringName,
	is_flying: bool,
	requires_vertical_navigation: bool,
	target_reached_callback: Callable,
	link_reached_callback: Callable,
	waypoint_reached_callback: Callable,
	warning_callback: Callable
) -> EnemyNavigationComponent:
	_disconnect_navigation_component_signals(current_component, target_reached_callback, link_reached_callback, waypoint_reached_callback)
	if available_components.is_empty():
		return null

	var desired_mode := _get_effective_navigation_mode_id(
		owner_name,
		requested_mode,
		is_flying,
		requires_vertical_navigation,
		warning_callback
	)
	var active_component := _find_navigation_component_for_mode(desired_mode, available_components)
	if not active_component and desired_mode != &"godot":
		_warn(
			warning_callback,
			"Enemy '%s': navigation mode '%s' is not available; falling back to Godot navigation." % [owner_name, String(desired_mode)]
		)
		active_component = _find_navigation_component_for_mode(&"godot", available_components)
	if not active_component:
		active_component = available_components[0]

	for component in available_components:
		component.set_navigation_active(component == active_component)

	_connect_navigation_component_signals(active_component, target_reached_callback, link_reached_callback, waypoint_reached_callback)
	return active_component


func get_navigation_components(owner: Node) -> Array[EnemyNavigationComponent]:
	var components: Array[EnemyNavigationComponent] = []
	if owner == null:
		return components
	for child in owner.get_children():
		if child is EnemyNavigationComponent:
			components.append(child as EnemyNavigationComponent)
	return components


func _get_effective_navigation_mode_id(
	owner_name: String,
	requested_mode: StringName,
	is_flying: bool,
	requires_vertical_navigation: bool,
	warning_callback: Callable
) -> StringName:
	if requested_mode != &"doom":
		return requested_mode

	var unsupported_reason := _get_doom_mode_unsupported_reason(is_flying, requires_vertical_navigation)
	if unsupported_reason.is_empty():
		return requested_mode

	_warn(
		warning_callback,
		"Enemy '%s': Doom navigation is not supported for %s; falling back to Godot navigation." % [owner_name, unsupported_reason]
	)
	return &"godot"


func _get_doom_mode_unsupported_reason(is_flying: bool, requires_vertical_navigation: bool) -> String:
	if is_flying:
		return "flying enemies"
	if requires_vertical_navigation:
		return "enemies that require vertical navigation"
	return ""


func _find_navigation_component_for_mode(mode_id: StringName, components: Array[EnemyNavigationComponent]) -> EnemyNavigationComponent:
	for component in components:
		if component.get_navigation_mode_id() == mode_id:
			return component
	return null


func _connect_navigation_component_signals(
	component: EnemyNavigationComponent,
	target_reached_callback: Callable,
	link_reached_callback: Callable,
	waypoint_reached_callback: Callable
) -> void:
	if not component:
		return
	if target_reached_callback.is_valid() and not component.target_reached.is_connected(target_reached_callback):
		component.target_reached.connect(target_reached_callback)
	if link_reached_callback.is_valid() and not component.link_reached.is_connected(link_reached_callback):
		component.link_reached.connect(link_reached_callback)
	if waypoint_reached_callback.is_valid() and not component.waypoint_reached.is_connected(waypoint_reached_callback):
		component.waypoint_reached.connect(waypoint_reached_callback)


func _disconnect_navigation_component_signals(
	component: EnemyNavigationComponent,
	target_reached_callback: Callable,
	link_reached_callback: Callable,
	waypoint_reached_callback: Callable
) -> void:
	if not component:
		return
	if target_reached_callback.is_valid() and component.target_reached.is_connected(target_reached_callback):
		component.target_reached.disconnect(target_reached_callback)
	if link_reached_callback.is_valid() and component.link_reached.is_connected(link_reached_callback):
		component.link_reached.disconnect(link_reached_callback)
	if waypoint_reached_callback.is_valid() and component.waypoint_reached.is_connected(waypoint_reached_callback):
		component.waypoint_reached.disconnect(waypoint_reached_callback)


func _warn(warning_callback: Callable, message: String) -> void:
	if warning_callback.is_valid():
		warning_callback.call(message)
