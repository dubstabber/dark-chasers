class_name HudDataProvider
extends RefCounted

## Interface/adapter for nodes that provide HUD data and signals.
##
## Preferred contract on provider nodes:
## - get_hud_health_component() -> HealthComponent
## - get_hud_armor_component() -> ArmorComponent
## - get_hud_ammo_component() -> PlayerAmmoComponent
## - get_hud_weapon_manager() -> WeaponManager
## - get_hud_damage_effects_component() -> DamageEffectsComponent
## - get_hud_camera() -> Camera3D
##
## The adapter keeps a compatibility fallback to common property names.


static func check(node: Node) -> bool:
	if node == null:
		return false
	return get_health_component(node) != null \
		or get_armor_component(node) != null \
		or get_weapon_manager(node) != null


static func get_health_component(node: Node) -> HealthComponent:
	var component = _get_component(node, "get_hud_health_component", "health_component")
	if component is HealthComponent:
		return component
	return null


static func get_armor_component(node: Node) -> ArmorComponent:
	var component = _get_component(node, "get_hud_armor_component", "armor_component")
	if component is ArmorComponent:
		return component
	return null


static func get_ammo_component(node: Node) -> PlayerAmmoComponent:
	var component = _get_component(node, "get_hud_ammo_component", "ammo_component")
	if component is PlayerAmmoComponent:
		return component
	return null


static func get_weapon_manager(node: Node) -> WeaponManager:
	var manager = _get_component(node, "get_hud_weapon_manager", "weapon_manager")
	if manager is WeaponManager:
		return manager
	return null


static func get_damage_effects_component(node: Node) -> DamageEffectsComponent:
	var component = _get_component(node, "get_hud_damage_effects_component", "damage_effects_component")
	if component is DamageEffectsComponent:
		return component
	return null


static func get_camera(node: Node) -> Camera3D:
	if node == null:
		return null
	if node.has_method("get_hud_camera"):
		var provider_camera = node.get_hud_camera()
		if provider_camera is Camera3D:
			return provider_camera
	return CameraOwner.get_camera(node)


static func get_current_health(node: Node) -> int:
	var health_component = get_health_component(node)
	if not health_component:
		return 0
	return health_component.current_health


static func get_max_health(node: Node) -> int:
	var health_component = get_health_component(node)
	if not health_component:
		return 0
	return health_component.max_health


static func get_current_armor(node: Node) -> int:
	var armor_component = get_armor_component(node)
	if not armor_component:
		return 0
	return armor_component.current_armor


static func get_max_armor(node: Node) -> int:
	var armor_component = get_armor_component(node)
	if not armor_component:
		return 0
	return armor_component.max_armor


static func get_current_weapon(node: Node) -> WeaponResource:
	var manager = get_weapon_manager(node)
	if not manager:
		return null
	return manager.current_weapon


static func _get_component(node: Node, method_name: String, property_name: String) -> Variant:
	if node == null:
		return null
	if node.has_method(method_name):
		return node.call(method_name)
	return node.get(property_name)
