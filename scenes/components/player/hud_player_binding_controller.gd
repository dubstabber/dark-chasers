class_name HudPlayerBindingController
extends RefCounted


func connect_player_signals(
	player: CharacterBody3D,
	health_changed_callback: Callable,
	armor_changed_callback: Callable,
	weapon_ammo_changed_callback: Callable,
	weapon_switched_callback: Callable,
	reserve_ammo_changed_callback: Callable,
	damage_overlay: ColorRect
) -> void:
	if not player:
		return

	if player.health_component and health_changed_callback.is_valid() and not player.health_component.health_changed.is_connected(health_changed_callback):
		player.health_component.health_changed.connect(health_changed_callback)

	if player.armor_component and armor_changed_callback.is_valid() and not player.armor_component.armor_changed.is_connected(armor_changed_callback):
		player.armor_component.armor_changed.connect(armor_changed_callback)

	if player.weapon_manager:
		if weapon_ammo_changed_callback.is_valid() and not player.weapon_manager.weapon_ammo_changed.is_connected(weapon_ammo_changed_callback):
			player.weapon_manager.weapon_ammo_changed.connect(weapon_ammo_changed_callback)
		if weapon_switched_callback.is_valid() and not player.weapon_manager.weapon_switched.is_connected(weapon_switched_callback):
			player.weapon_manager.weapon_switched.connect(weapon_switched_callback)

	if player.ammo_component and reserve_ammo_changed_callback.is_valid() and not player.ammo_component.ammo_changed.is_connected(reserve_ammo_changed_callback):
		player.ammo_component.ammo_changed.connect(reserve_ammo_changed_callback)

	if player.damage_effects_component:
		player.damage_effects_component.color_rect = damage_overlay


func disconnect_player_signals(
	player: CharacterBody3D,
	health_changed_callback: Callable,
	armor_changed_callback: Callable,
	weapon_ammo_changed_callback: Callable,
	weapon_switched_callback: Callable,
	reserve_ammo_changed_callback: Callable
) -> void:
	if not player:
		return

	if player.health_component and health_changed_callback.is_valid() and player.health_component.health_changed.is_connected(health_changed_callback):
		player.health_component.health_changed.disconnect(health_changed_callback)

	if player.armor_component and armor_changed_callback.is_valid() and player.armor_component.armor_changed.is_connected(armor_changed_callback):
		player.armor_component.armor_changed.disconnect(armor_changed_callback)

	if player.weapon_manager:
		if weapon_ammo_changed_callback.is_valid() and player.weapon_manager.weapon_ammo_changed.is_connected(weapon_ammo_changed_callback):
			player.weapon_manager.weapon_ammo_changed.disconnect(weapon_ammo_changed_callback)
		if weapon_switched_callback.is_valid() and player.weapon_manager.weapon_switched.is_connected(weapon_switched_callback):
			player.weapon_manager.weapon_switched.disconnect(weapon_switched_callback)

	if player.ammo_component and reserve_ammo_changed_callback.is_valid() and player.ammo_component.ammo_changed.is_connected(reserve_ammo_changed_callback):
		player.ammo_component.ammo_changed.disconnect(reserve_ammo_changed_callback)

	if player.damage_effects_component:
		player.damage_effects_component.color_rect = null
