class_name WeaponManager extends Node3D

const WeaponSoundControllerScript = preload("res://scenes/systems/weapon_manager/weapon_sound_controller.gd")

signal lighter_on
signal lighter_off
signal weapon_ammo_changed(current_ammo: int, max_ammo: int)
signal weapon_switched(weapon: WeaponResource)

# --------------------------------------------------------------------------
# Controllers
# --------------------------------------------------------------------------
var _bob_controller := WeaponBobController.new()
var _switch_controller := WeaponSwitchController.new()
var _hit_executor := WeaponHitExecutor.new()
var _sound_controller := WeaponSoundControllerScript.new()

# --------------------------------------------------------------------------
# Runtime state
# --------------------------------------------------------------------------
var image_height: float
var left_hand: Node
var right_hand: Node
var base_gun_position: Vector3 = Vector3.ZERO

var is_auto_hitting := false
var is_shooting := false # Tracks if a shooting/hit animation is playing
var _ammo_components_initialized := false # Track if ammo components have been set up

# Controller property accessors
var current_weapon: WeaponResource:
	get: return _switch_controller.get_current_weapon()
	set(value): _switch_controller.set_current_weapon(value)

var is_switching_weapon: bool:
	get: return _switch_controller.is_switching

var selected_slot_index: int:
	get: return _switch_controller.selected_slot_index
	set(value): _switch_controller.selected_slot_index = value

var selected_slot_position: int:
	get: return _switch_controller.selected_slot_position
	set(value): _switch_controller.selected_slot_position = value

# --------------------------------------------------------------------------
# Weapon slot resources (numbers correspond to keyboard shortcuts 1-9)
# --------------------------------------------------------------------------
@export var slot_1: Array[WeaponResource] = []
@export var slot_2: Array[WeaponResource] = []
@export var slot_3: Array[WeaponResource] = []
@export var slot_4: Array[WeaponResource] = []
@export var slot_5: Array[WeaponResource] = []
@export var slot_6: Array[WeaponResource] = []
@export var slot_7: Array[WeaponResource] = []
@export var slot_8: Array[WeaponResource] = []
@export var slot_9: Array[WeaponResource] = []

# --------------------------------------------------------------------------
# Scene references
# --------------------------------------------------------------------------
@export var player: Player
@export var gun_base: Node
@export var animation_player: AnimationPlayer
@export var hit_sound_player: AudioStreamPlayer3D
@export var weapon_sound_player: AudioStreamPlayer3D
@export var bullet_raycast: RayCast3D


# ========================================================================== #
# Lifecycle
# ========================================================================== #
func _ready() -> void:
	left_hand = gun_base.get_node_or_null("LeftHandSlot")
	right_hand = gun_base.get_node_or_null("RightHandSlot")
	base_gun_position = gun_base.position
	
	# Initialize controllers with scene references
	_hit_executor.setup(get_tree(), bullet_raycast)
	_sound_controller.setup(hit_sound_player, weapon_sound_player)
	
	# Initialize ammo component references for all weapons
	_setup_weapon_ammo_components()
	
	# Connect to player's weapon pickup signal
	if player and player.has_signal("weapon_added"):
		player.weapon_added.connect(_on_weapon_added)
	
	# Connect animation player signals to track shooting animations
	if animation_player:
		animation_player.animation_started.connect(_on_animation_started)
		animation_player.animation_finished.connect(_on_animation_finished)
	
	switch_weapon(2) # default


func _setup_weapon_ammo_components() -> void:
	"""Initialize ammo component references for all weapons in all slots"""
	var player_ammo_component = _get_player_ammo_component()
	if not player_ammo_component:
		Services.utils.debug_warning("WeaponManager: PlayerAmmoComponent not ready yet, will retry when equipping weapons")
		_ammo_components_initialized = false
		return
	
	# Set up ammo component reference for all weapons in all slots
	var all_slots = [slot_1, slot_2, slot_3, slot_4, slot_5, slot_6, slot_7, slot_8, slot_9]
	for slot in all_slots:
		for weapon in slot:
			if weapon:
				weapon.ammo_component = player_ammo_component
				weapon.weapon_manager = self
	
	_ammo_components_initialized = true


func _get_player_ammo_component() -> PlayerAmmoComponent:
	"""Get the player's ammo component with robust detection
	
	Returns:
		PlayerAmmoComponent: The player's ammo component, or null if not found
	"""
	if not player:
		return null
	
	# Player class has typed ammo_component property
	if player.ammo_component:
		return player.ammo_component
	
	# Fallback: try to find ammo component as a child node
	return player.get_node_or_null("PlayerAmmoComponent")


func _process(delta: float) -> void:
	_update_speed(delta)
	_update_bob(delta)
	_apply_offsets()


# Note: Input polling moved to WeaponInputComponent
# WeaponManager is now a pure orchestrator - call try_fire(), start_auto_hitting(), etc.


# ========================================================================== #
# Update helpers (delegated to bob controller)
# ========================================================================== #
func _update_speed(delta: float) -> void:
	_bob_controller.update_speed(player.velocity, delta)


func _update_bob(delta: float) -> void:
	_bob_controller.update_bob(delta, is_shooting, is_auto_hitting)


func _apply_offsets() -> void:
	if gun_base:
		gun_base.position = base_gun_position + _bob_controller.get_offset()


# --------------------------------------------------------------------------
# Weapon pickup helpers
# --------------------------------------------------------------------------
func _get_slot_array(slot_index: int) -> Array[WeaponResource]:
	match slot_index:
		1: return slot_1
		2: return slot_2
		3: return slot_3
		4: return slot_4
		5: return slot_5
		6: return slot_6
		7: return slot_7
		8: return slot_8
		9: return slot_9
	return []


func get_slot_weapons(slot_index: int) -> Array[WeaponResource]:
	"""Get weapons in a specific slot (public method for ammo management)

	Args:
		slot_index: Slot number (1-9)

	Returns:
		Array[WeaponResource]: Array of weapons in the slot
	"""
	return _get_slot_array(slot_index)


func _on_weapon_added(new_weapon: WeaponResource) -> void:
	if not new_weapon:
		return
	
	# Set up ammo component reference for the new weapon
	var player_ammo_component = _get_player_ammo_component()
	if player_ammo_component:
		new_weapon.ammo_component = player_ammo_component
		new_weapon.weapon_manager = self
	
	var slot_index: int = clamp(new_weapon.slot, 1, 9)
	var slot_array: Array[WeaponResource] = _get_slot_array(slot_index)
	
	# If we already own this weapon, simply equip it
	if new_weapon in slot_array:
		selected_slot_index = slot_index
		selected_slot_position = slot_array.find(new_weapon)
		await _equip_from_slot(slot_array)
		return
	
	# Insert weapon respecting slot_priority (lower value = higher priority)
	var inserted := false
	for i in range(slot_array.size()):
		if new_weapon.slot_priority < slot_array[i].slot_priority:
			slot_array.insert(i, new_weapon)
			inserted = true
			break
	if not inserted:
		slot_array.append(new_weapon)
	
	# Equip the newly picked-up weapon
	selected_slot_index = slot_index
	selected_slot_position = slot_array.find(new_weapon)
	await _equip_from_slot(slot_array)


# ========================================================================== #
# Public fire control methods (called by WeaponInputComponent)
# ========================================================================== #
func try_fire() -> void:
	"""Attempt to fire the current weapon (single shot)"""
	if not current_weapon or not current_weapon.shoot_anim_name:
		return
	if animation_player.is_playing() or is_switching_weapon:
		return
	if not current_weapon.can_fire():
		return
	animation_player.play(current_weapon.shoot_anim_name)


func try_auto_fire() -> void:
	"""Attempt to continue auto-fire for automatic weapons"""
	if not current_weapon or not is_auto_hitting:
		return
	if not current_weapon.can_fire():
		return
	if animation_player.is_playing():
		return
	
	if current_weapon.repeat_shoot_anim_name:
		animation_player.play(current_weapon.repeat_shoot_anim_name)
	elif current_weapon.shoot_anim_name:
		animation_player.play(current_weapon.shoot_anim_name)


func start_auto_hitting() -> void:
	"""Start auto-fire mode for automatic weapons"""
	is_auto_hitting = true


func stop_auto_hitting() -> void:
	"""Stop auto-fire mode and reset to idle"""
	is_auto_hitting = false
	_reset_to_idle_after_auto_fire()


func _reset_to_idle_after_auto_fire() -> void:
	"""Reset weapon to idle state after auto-fire ends"""
	if animation_player.is_playing():
		await animation_player.animation_finished
	
	if is_auto_hitting:
		return # User started firing again
	
	if current_weapon and current_weapon.pullout_anim_name and not animation_player.is_playing():
		animation_player.stop()
		animation_player.current_animation = current_weapon.pullout_anim_name
		var pullout_anim := animation_player.get_animation(current_weapon.pullout_anim_name)
		if pullout_anim:
			animation_player.seek(pullout_anim.length, true, true)
			lighter_off.emit()


func hit() -> void:
	if not current_weapon:
		return
	
	# Consume ammo before hitting (for non-melee weapons)
	if not current_weapon.melee_attack:
		if not current_weapon.consume_ammo():
			return # Don't hit if insufficient ammo
	
	# Execute hit via the hit executor (handles particles, decals, damage)
	_hit_executor.execute_hit(current_weapon)


func switch_weapon(slot_index: int) -> void:
	var slot_array = _get_slot_array(slot_index)
	if slot_array.is_empty():
		return

	if _switch_controller.is_switching:
		_switch_controller.queue_switch(slot_index)
	else:
		_switch_controller.start_switching()
		_start_weapon_switch_process(slot_index)


func _start_weapon_switch_process(slot_index: int) -> void:
	await _process_weapon_switch(slot_index)
	await _process_weapon_switch_queue()


func _process_weapon_switch_queue() -> void:
	while _switch_controller.has_queued_switch():
		var next_slot = _switch_controller.pop_queued_switch()
		await _process_weapon_switch(next_slot)
	_switch_controller.finish_switching()


func _process_weapon_switch(slot_index: int) -> void:
	var slot_array = _get_slot_array(slot_index)
	var target_weapon = _switch_controller.resolve_target_weapon(slot_index, slot_array)
	
	if target_weapon == null:
		return # Already on target or slot empty
	
	# Perform the actual weapon switch
	await _equip_from_slot(slot_array)

func _equip_from_slot(slot: Array[WeaponResource]) -> void:
	if slot.size() <= selected_slot_position:
		selected_slot_position = 0

	var next_weapon := slot[selected_slot_position]
	if current_weapon == next_weapon:
		return

	is_auto_hitting = false

	# Put away current weapon if one is equipped
	if current_weapon and current_weapon.pullout_anim_name:
		# Disconnect signals from the old weapon
		if current_weapon.ammo_changed.is_connected(_on_weapon_ammo_changed):
			current_weapon.ammo_changed.disconnect(_on_weapon_ammo_changed)
		if current_weapon.ammo_depleted.is_connected(_on_weapon_ammo_depleted):
			current_weapon.ammo_depleted.disconnect(_on_weapon_ammo_depleted)

		# Wait for any current animation to finish before starting holster
		if animation_player.is_playing():
			await animation_player.animation_finished

		animation_player.play_backwards(current_weapon.pullout_anim_name)
		await animation_player.animation_finished

	# Equip new weapon
	current_weapon = next_weapon
	bullet_raycast.target_position.z = -1.2 if current_weapon.melee_attack else -1000.0
	_sound_controller.set_hit_sound_stream(current_weapon)
	current_weapon.weapon_manager = self
	
	# Retry setting up all ammo components if they weren't initialized during _ready
	if not _ammo_components_initialized:
		_setup_weapon_ammo_components()
	
	# Ensure ammo component is set (in case it wasn't set during initialization)
	if not current_weapon.ammo_component:
		var player_ammo_component = _get_player_ammo_component()
		if player_ammo_component:
			current_weapon.ammo_component = player_ammo_component

	# Connect to weapon's ammo signals
	if current_weapon.ammo_changed.is_connected(_on_weapon_ammo_changed):
		current_weapon.ammo_changed.disconnect(_on_weapon_ammo_changed)
	current_weapon.ammo_changed.connect(_on_weapon_ammo_changed)

	# Connect to weapon's ammo depleted signal
	if current_weapon.ammo_depleted.is_connected(_on_weapon_ammo_depleted):
		current_weapon.ammo_depleted.disconnect(_on_weapon_ammo_depleted)
	current_weapon.ammo_depleted.connect(_on_weapon_ammo_depleted)

	# Emit weapon switched signal and initial ammo state
	weapon_switched.emit(current_weapon)
	weapon_ammo_changed.emit(current_weapon.get_current_ammo(), current_weapon.get_max_ammo_amount())

	# Play draw animation for new weapon
	if current_weapon.pullout_anim_name:
		animation_player.play(current_weapon.pullout_anim_name)
		await animation_player.animation_finished


# ========================================================================== #
# Weapon sound functions (for use in AnimationPlayer, delegated to controller)
# ========================================================================== #
func play_weapon_draw_sound() -> void:
	_sound_controller.play_draw_sound(current_weapon, animation_player)


func play_weapon_holster_sound() -> void:
	_sound_controller.play_holster_sound(current_weapon, animation_player)


func play_hit_sound() -> void:
	_sound_controller.play_hit_sound(current_weapon)


func light_lighter() -> void:
	lighter_on.emit()


func extinguish_lighter() -> void:
	lighter_off.emit()


# ========================================================================== #
# Death handling methods
# ========================================================================== #
func disable_weapon_bobbing() -> void:
	"""Disable weapon bobbing animations (called when player dies)"""
	_bob_controller.disable()


func enable_weapon_bobbing() -> void:
	"""Re-enable weapon bobbing animations (for revival or respawn)"""
	_bob_controller.enable()


func reset_weapon_on_revival() -> void:
	"""Reset weapon state when player is revived or respawns"""
	enable_weapon_bobbing()
	is_auto_hitting = false
	is_shooting = false

	# If there's a current weapon, play its pullout animation to "re-equip" it
	if current_weapon and current_weapon.pullout_anim_name and animation_player:
		animation_player.stop()
		animation_player.play(current_weapon.pullout_anim_name)


# ========================================================================== #
# Animation tracking for weapon bobbing control
# ========================================================================== #
func _on_animation_started(anim_name: String) -> void:
	"""Called when an animation starts playing
	
	Disables weapon bobbing during shooting/hit animations to keep
	the weapon in its initial position during the attack.
	"""
	if not current_weapon:
		return
	
	# Check if this is a shooting animation
	if anim_name == current_weapon.shoot_anim_name or anim_name == current_weapon.repeat_shoot_anim_name:
		is_shooting = true


func _on_animation_finished(anim_name: String) -> void:
	"""Called when an animation finishes playing
	
	Re-enables weapon bobbing after shooting/hit animations complete.
	"""
	if not current_weapon:
		return
	
	# Check if this was a shooting animation
	if anim_name == current_weapon.shoot_anim_name or anim_name == current_weapon.repeat_shoot_anim_name:
		is_shooting = false


# ========================================================================== #
# Ammo System Signal Handlers
# ========================================================================== #
func _on_weapon_ammo_changed(current_ammo: int, max_ammo: int):
	"""Called when the current weapon's ammo changes

	Forwards the ammo change signal to any connected systems (like the HUD).
	"""
	weapon_ammo_changed.emit(current_ammo, max_ammo)


func add_ammo_to_weapons(amount: int, all_weapons: bool = false) -> bool:
	"""Add ammo to weapons using the component-based ammo system

	Args:
		amount: Amount of ammo to add
		all_weapons: If true, add ammo to all non-infinite weapons

	Returns:
		bool: True if ammo was added to at least one weapon, False otherwise
	"""
	var player_ammo_component = _get_player_ammo_component()
	if not player_ammo_component:
		return false

	var ammo_added = false
	var ammo_types_added = {}

	if all_weapons:
		var all_slots = [slot_1, slot_2, slot_3, slot_4, slot_5, slot_6, slot_7, slot_8, slot_9]
		for slot in all_slots:
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


func _on_weapon_ammo_depleted():
	"""Called when the current weapon's ammo is completely depleted

	This handles the same logic as mouse button release for auto-hit weapons
	to ensure the weapon returns to the correct idle frame when ammo runs out.
	"""
	if not current_weapon or not current_weapon.auto_hit:
		return

	# Stop auto-hitting behavior
	is_auto_hitting = false

	# Wait for current animation to finish, then reset to idle frame
	if animation_player.is_playing():
		await animation_player.animation_finished

	# Double-check that we're still not auto-hitting (user might have pressed mouse again)
	if is_auto_hitting:
		return

	# Reset to idle frame (same logic as mouse button release)
	if current_weapon.pullout_anim_name and not animation_player.is_playing():
		animation_player.stop()

		animation_player.current_animation = current_weapon.pullout_anim_name
		var pullout_anim := animation_player.get_animation(current_weapon.pullout_anim_name)
		if pullout_anim:
			animation_player.seek(pullout_anim.length, true, true)
			lighter_off.emit()
