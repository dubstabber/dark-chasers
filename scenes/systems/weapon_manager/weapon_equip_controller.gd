class_name WeaponEquipController
extends RefCounted

var _weapon_manager: Node
var _switch_controller: WeaponSwitchController
var _ammo_controller: WeaponAmmoController
var _ui_event_controller: WeaponUiEventController
var _sound_controller: WeaponSoundController
var _animation_player: AnimationPlayer
var _bullet_raycast: RayCast3D
var _player: Player
var _slots: Array

var _get_slot_array: Callable
var _set_is_auto_hitting: Callable
var _on_weapon_ammo_changed: Callable
var _on_weapon_ammo_depleted: Callable
var _emit_weapon_switched: Callable
var _emit_weapon_ammo_changed: Callable


func setup(
	weapon_manager: Node,
	switch_controller: WeaponSwitchController,
	ammo_controller: WeaponAmmoController,
	ui_event_controller: WeaponUiEventController,
	sound_controller: WeaponSoundController,
	animation_player: AnimationPlayer,
	bullet_raycast: RayCast3D,
	player: Player,
	slots: Array,
	get_slot_array: Callable,
	set_is_auto_hitting: Callable,
	on_weapon_ammo_changed: Callable,
	on_weapon_ammo_depleted: Callable,
	emit_weapon_switched: Callable,
	emit_weapon_ammo_changed: Callable
) -> void:
	_weapon_manager = weapon_manager
	_switch_controller = switch_controller
	_ammo_controller = ammo_controller
	_ui_event_controller = ui_event_controller
	_sound_controller = sound_controller
	_animation_player = animation_player
	_bullet_raycast = bullet_raycast
	_player = player
	_slots = slots

	_get_slot_array = get_slot_array
	_set_is_auto_hitting = set_is_auto_hitting
	_on_weapon_ammo_changed = on_weapon_ammo_changed
	_on_weapon_ammo_depleted = on_weapon_ammo_depleted
	_emit_weapon_switched = emit_weapon_switched
	_emit_weapon_ammo_changed = emit_weapon_ammo_changed


func switch_weapon(slot_index: int) -> void:
	var slot_array: Array = _get_slot_array.call(slot_index)
	if slot_array.is_empty():
		return

	if _switch_controller.is_switching:
		_switch_controller.queue_switch(slot_index)
		return

	_switch_controller.start_switching()
	await _process_weapon_switch(slot_index)
	await _process_weapon_switch_queue()


func equip_selected_slot(slot: Array) -> void:
	await _equip_from_slot(slot)


func _process_weapon_switch_queue() -> void:
	while _switch_controller.has_queued_switch():
		var next_slot := _switch_controller.pop_queued_switch()
		await _process_weapon_switch(next_slot)
	_switch_controller.finish_switching()


func _process_weapon_switch(slot_index: int) -> void:
	var slot_array: Array = _get_slot_array.call(slot_index)
	var target_weapon := _switch_controller.resolve_target_weapon(slot_index, slot_array)
	if target_weapon == null:
		return
	await _equip_from_slot(slot_array)


func _equip_from_slot(slot: Array) -> void:
	if slot.is_empty():
		return

	if slot.size() <= _switch_controller.selected_slot_position:
		_switch_controller.selected_slot_position = 0

	var next_weapon := slot[_switch_controller.selected_slot_position] as WeaponResource
	var current_weapon := _switch_controller.get_current_weapon()
	if current_weapon == next_weapon:
		return

	if _set_is_auto_hitting.is_valid():
		_set_is_auto_hitting.call(false)

	if current_weapon and current_weapon.pullout_anim_name:
		_ui_event_controller.disconnect_weapon_signals(
			current_weapon,
			_on_weapon_ammo_changed,
			_on_weapon_ammo_depleted
		)

		if _animation_player and _animation_player.is_playing():
			await _animation_player.animation_finished

		if _animation_player:
			_animation_player.play_backwards(current_weapon.pullout_anim_name)
			await _animation_player.animation_finished

	_switch_controller.set_current_weapon(next_weapon)
	current_weapon = next_weapon

	if _bullet_raycast:
		_bullet_raycast.target_position.z = -1.2 if current_weapon.melee_attack else -1000.0
	_sound_controller.set_hit_sound_stream(current_weapon)

	_ammo_controller.ensure_weapon_wired(current_weapon, _slots, _player, _weapon_manager)

	_ui_event_controller.connect_weapon_signals(
		current_weapon,
		_on_weapon_ammo_changed,
		_on_weapon_ammo_depleted
	)

	_ui_event_controller.emit_weapon_equipped(
		current_weapon,
		_emit_weapon_switched,
		_emit_weapon_ammo_changed
	)

	if current_weapon.pullout_anim_name and _animation_player:
		_animation_player.play(current_weapon.pullout_anim_name)
		await _animation_player.animation_finished
