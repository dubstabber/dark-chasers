class_name WeaponAmmoController
extends RefCounted

var _ammo_components_initialized := false


func _get_player_ammo_component(player: Player) -> PlayerAmmoComponent:
	if not player:
		return null

	if player.ammo_component:
		return player.ammo_component

	return player.get_node_or_null("PlayerAmmoComponent")


func initialize_slot_wiring(slots: Array, player: Player, manager: Node) -> bool:
	var player_ammo_component := _get_player_ammo_component(player)
	if not player_ammo_component:
		push_warning("WeaponAmmoController: PlayerAmmoComponent not ready yet, will retry when equipping weapons")
		_ammo_components_initialized = false
		return false

	initialize_slot_weapons(slots, player_ammo_component, manager)
	_ammo_components_initialized = true
	return true


func ensure_weapon_wired(weapon: WeaponResource, slots: Array, player: Player, manager: Node) -> bool:
	if not weapon:
		return false

	var player_ammo_component := _get_player_ammo_component(player)
	if not player_ammo_component:
		push_warning("WeaponAmmoController: PlayerAmmoComponent not ready yet, will retry when equipping weapons")
		_ammo_components_initialized = false
		return false

	if not _ammo_components_initialized:
		initialize_slot_weapons(slots, player_ammo_component, manager)
		_ammo_components_initialized = true

	if not weapon.ammo_component:
		wire_weapon_manager(weapon, player_ammo_component, manager)

	return weapon.ammo_component != null


func wire_weapon_manager(weapon: WeaponResource, player_ammo_component: PlayerAmmoComponent, manager: Node) -> void:
	if not weapon or not player_ammo_component:
		return
	weapon.ammo_component = player_ammo_component
	weapon.weapon_manager = manager


func initialize_slot_weapons(slots: Array, player_ammo_component: PlayerAmmoComponent, manager: Node) -> void:
	if not player_ammo_component:
		return

	for slot in slots:
		if not (slot is Array):
			continue
		for weapon in slot:
			wire_weapon_manager(weapon, player_ammo_component, manager)


func add_ammo_to_weapons(slots: Array, current_weapon: WeaponResource, player: Player, amount: int, all_weapons: bool = false) -> bool:
	var player_ammo_component := _get_player_ammo_component(player)
	if not player_ammo_component:
		return false

	var ammo_added := false
	var ammo_types_added := {}

	if all_weapons:
		for slot in slots:
			if not (slot is Array):
				continue
			for weapon in slot:
				if weapon and not weapon.infinite_ammo and weapon.ammo_type != "":
					if not ammo_types_added.has(weapon.ammo_type):
						if player_ammo_component.add_ammo(weapon.ammo_type, amount):
							ammo_added = true
							ammo_types_added[weapon.ammo_type] = true
	else:
		if current_weapon and not current_weapon.infinite_ammo:
			if current_weapon.ammo_type != "":
				ammo_added = player_ammo_component.add_ammo(current_weapon.ammo_type, amount)
			else:
				push_warning("WeaponManager: Current weapon '%s' has no ammo_type specified!" % current_weapon.name)

	return ammo_added


func reset_to_idle_frame(animation_player: AnimationPlayer, current_weapon: WeaponResource, lighter_off_callback: Callable) -> void:
	if not animation_player or not current_weapon:
		return
	if not current_weapon.pullout_anim_name or animation_player.is_playing():
		return

	animation_player.stop()
	animation_player.current_animation = current_weapon.pullout_anim_name
	var pullout_anim := animation_player.get_animation(current_weapon.pullout_anim_name)
	if pullout_anim:
		animation_player.seek(pullout_anim.length, true, true)
		if lighter_off_callback.is_valid():
			lighter_off_callback.call()


func reset_after_auto_fire(animation_player: AnimationPlayer, current_weapon: WeaponResource, is_auto_hitting: bool, lighter_off_callback: Callable) -> void:
	if not animation_player:
		return

	if animation_player.is_playing():
		await animation_player.animation_finished

	if is_auto_hitting:
		return

	reset_to_idle_frame(animation_player, current_weapon, lighter_off_callback)
