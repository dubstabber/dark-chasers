class_name WeaponSwitchController
extends RefCounted

var is_switching := false
var switch_queue: Array[int] = []
var selected_slot_index := 2
var selected_slot_position := 0

var _current_weapon: WeaponResource


func get_current_weapon() -> WeaponResource:
	return _current_weapon


func set_current_weapon(weapon: WeaponResource) -> void:
	_current_weapon = weapon


func has_queued_switch() -> bool:
	return not switch_queue.is_empty()


func pop_queued_switch() -> int:
	return switch_queue.pop_front()


func queue_switch(slot_index: int) -> void:
	switch_queue.clear()
	switch_queue.append(slot_index)


func start_switching() -> void:
	is_switching = true


func finish_switching() -> void:
	is_switching = false


func resolve_target_weapon(slot_index: int, slot_array: Array) -> WeaponResource:
	"""Resolve which weapon to switch to in the given slot.
	Returns null if already on target weapon or slot is empty."""
	if slot_array.is_empty():
		return null
	
	# Determine target position (cycle through slot if same slot pressed)
	var target_slot_position = 0
	if slot_index == selected_slot_index:
		target_slot_position = selected_slot_position + 1
	
	# Handle slot position wrapping
	if slot_array.size() <= target_slot_position:
		target_slot_position = 0
	
	var target_weapon = slot_array[target_slot_position]
	
	# Check if we're already on the target weapon
	if _current_weapon == target_weapon:
		return null
	
	# Update slot tracking
	selected_slot_index = slot_index
	selected_slot_position = target_slot_position
	
	return target_weapon


func insert_weapon_sorted(new_weapon: WeaponResource, slot_array: Array) -> int:
	"""Insert weapon into slot respecting slot_priority (lower = higher priority).
	Returns the position where the weapon was inserted."""
	if not new_weapon:
		return -1
	
	# If we already own this weapon, return its position
	if new_weapon in slot_array:
		return slot_array.find(new_weapon)
	
	# Insert weapon respecting slot_priority
	for i in range(slot_array.size()):
		if new_weapon.slot_priority < slot_array[i].slot_priority:
			slot_array.insert(i, new_weapon)
			return i
	
	slot_array.append(new_weapon)
	return slot_array.size() - 1
