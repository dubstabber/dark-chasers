class_name HudPlayerBindingController
extends RefCounted


func connect_player_signals(
	provider: Node,
	health_changed_callback: Callable,
	armor_changed_callback: Callable,
	weapon_ammo_changed_callback: Callable,
	weapon_switched_callback: Callable,
	reserve_ammo_changed_callback: Callable,
	damage_overlay: ColorRect
) -> void:
	if not provider:
		return

	var health_component := HudDataProvider.get_health_component(provider)
	var armor_component := HudDataProvider.get_armor_component(provider)
	var weapon_manager := HudDataProvider.get_weapon_manager(provider)
	var ammo_component := HudDataProvider.get_ammo_component(provider)
	var damage_effects_component := HudDataProvider.get_damage_effects_component(provider)

	if health_component and health_changed_callback.is_valid() and not health_component.health_changed.is_connected(health_changed_callback):
		health_component.health_changed.connect(health_changed_callback)

	if armor_component and armor_changed_callback.is_valid() and not armor_component.armor_changed.is_connected(armor_changed_callback):
		armor_component.armor_changed.connect(armor_changed_callback)

	if weapon_manager:
		if weapon_ammo_changed_callback.is_valid() and not weapon_manager.weapon_ammo_changed.is_connected(weapon_ammo_changed_callback):
			weapon_manager.weapon_ammo_changed.connect(weapon_ammo_changed_callback)
		if weapon_switched_callback.is_valid() and not weapon_manager.weapon_switched.is_connected(weapon_switched_callback):
			weapon_manager.weapon_switched.connect(weapon_switched_callback)

	if ammo_component and reserve_ammo_changed_callback.is_valid() and not ammo_component.ammo_changed.is_connected(reserve_ammo_changed_callback):
		ammo_component.ammo_changed.connect(reserve_ammo_changed_callback)

	if damage_effects_component:
		damage_effects_component.color_rect = damage_overlay


func disconnect_player_signals(
	provider: Node,
	health_changed_callback: Callable,
	armor_changed_callback: Callable,
	weapon_ammo_changed_callback: Callable,
	weapon_switched_callback: Callable,
	reserve_ammo_changed_callback: Callable
) -> void:
	if not provider:
		return

	var health_component := HudDataProvider.get_health_component(provider)
	var armor_component := HudDataProvider.get_armor_component(provider)
	var weapon_manager := HudDataProvider.get_weapon_manager(provider)
	var ammo_component := HudDataProvider.get_ammo_component(provider)
	var damage_effects_component := HudDataProvider.get_damage_effects_component(provider)

	if health_component and health_changed_callback.is_valid() and health_component.health_changed.is_connected(health_changed_callback):
		health_component.health_changed.disconnect(health_changed_callback)

	if armor_component and armor_changed_callback.is_valid() and armor_component.armor_changed.is_connected(armor_changed_callback):
		armor_component.armor_changed.disconnect(armor_changed_callback)

	if weapon_manager:
		if weapon_ammo_changed_callback.is_valid() and weapon_manager.weapon_ammo_changed.is_connected(weapon_ammo_changed_callback):
			weapon_manager.weapon_ammo_changed.disconnect(weapon_ammo_changed_callback)
		if weapon_switched_callback.is_valid() and weapon_manager.weapon_switched.is_connected(weapon_switched_callback):
			weapon_manager.weapon_switched.disconnect(weapon_switched_callback)

	if ammo_component and reserve_ammo_changed_callback.is_valid() and ammo_component.ammo_changed.is_connected(reserve_ammo_changed_callback):
		ammo_component.ammo_changed.disconnect(reserve_ammo_changed_callback)

	if damage_effects_component:
		damage_effects_component.color_rect = null
