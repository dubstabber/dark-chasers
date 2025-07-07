extends Node3D
#
#const HOTKEYS := {
	#KEY_1: 1,
	#KEY_2: 2,
	#KEY_3: 3,
	#KEY_4: 4,
	#KEY_5: 5,
	#KEY_6: 6,
	#KEY_7: 7,
	#KEY_8: 8,
	#KEY_9: 9,
#}
#
#var weapons := {
	#1: [],
	#2: [],
	#3: [],
	#4: [],
	#5: [],
	#6: [],
	#7: [],
	#8: [],
	#9: []
#}
#var selected_weapon_slot := 1
#var selected_weapon_index := 0
#
#
#func _input(event: InputEvent) -> void:
	#if event is InputEventKey and event.pressed and event.keycode in HOTKEYS:
		#switch_weapon(HOTKEYS[event.keycode])
#
#
#func switch_weapon(slot_id:int) -> void:
	#if selected_weapon_slot == slot_id:
		#if weapons[selected_weapon_slot].size() > 1:
			#remove_child(weapons[selected_weapon_slot][selected_weapon_index])
			#selected_weapon_index = (selected_weapon_index + 1) % weapons[selected_weapon_slot].size()
			#add_child(weapons[selected_weapon_slot][selected_weapon_index])
	#elif not weapons[slot_id].is_empty():
		#remove_child(weapons[selected_weapon_slot][selected_weapon_index])
		#selected_weapon_slot = slot_id
		#selected_weapon_index = 0
		#add_child(weapons[selected_weapon_slot][selected_weapon_index])
#
	#
