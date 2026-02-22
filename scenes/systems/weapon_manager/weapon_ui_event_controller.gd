class_name WeaponUiEventController
extends RefCounted


func disconnect_weapon_signals(
	weapon: WeaponResource,
	ammo_changed_callback: Callable,
	ammo_depleted_callback: Callable
) -> void:
	if not weapon:
		return
	if weapon.ammo_changed.is_connected(ammo_changed_callback):
		weapon.ammo_changed.disconnect(ammo_changed_callback)
	if weapon.ammo_depleted.is_connected(ammo_depleted_callback):
		weapon.ammo_depleted.disconnect(ammo_depleted_callback)


func connect_weapon_signals(
	weapon: WeaponResource,
	ammo_changed_callback: Callable,
	ammo_depleted_callback: Callable
) -> void:
	if not weapon:
		return
	disconnect_weapon_signals(weapon, ammo_changed_callback, ammo_depleted_callback)
	weapon.ammo_changed.connect(ammo_changed_callback)
	weapon.ammo_depleted.connect(ammo_depleted_callback)


func emit_weapon_equipped(
	weapon: WeaponResource,
	emit_weapon_switched: Callable,
	emit_weapon_ammo_changed: Callable
) -> void:
	if not weapon:
		return
	if emit_weapon_switched.is_valid():
		emit_weapon_switched.call(weapon)
	if emit_weapon_ammo_changed.is_valid():
		emit_weapon_ammo_changed.call(weapon.get_current_ammo(), weapon.get_max_ammo_amount())


func forward_ammo_change(
	current_ammo: int,
	max_ammo: int,
	emit_weapon_ammo_changed: Callable
) -> void:
	if emit_weapon_ammo_changed.is_valid():
		emit_weapon_ammo_changed.call(current_ammo, max_ammo)
