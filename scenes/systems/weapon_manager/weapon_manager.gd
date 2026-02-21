class_name WeaponManager extends Node3D

const WeaponAmmoControllerScript = preload("res://scenes/systems/weapon_manager/weapon_ammo_controller.gd")

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
var _sound_controller := WeaponSoundController.new()
var _ammo_controller := WeaponAmmoControllerScript.new()

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

const BOB_IDLE_EPSILON_SQUARED := 0.0001

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
@export var slots: Array = [[], [], [], [], [], [], [], [], []]

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
	_ensure_min_slot_count(9)
	
	# Initialize controllers with scene references
	_hit_executor.setup(get_tree(), bullet_raycast)
	_sound_controller.setup(hit_sound_player, weapon_sound_player)
	
	# Initialize ammo component references for all weapons
	_setup_weapon_ammo_components()
	
	# Connect to player's weapon pickup signal
	if player and WeaponReceiver.check(player):
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
	_ammo_controller.initialize_slot_weapons(slots, player_ammo_component, self)
	
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
	# Skip bobbing when no weapon is equipped or core refs are unavailable
	if not current_weapon or not player or not gun_base:
		return

	var player_is_moving := player.velocity.length_squared() > BOB_IDLE_EPSILON_SQUARED
	var bob_offset := _bob_controller.get_offset()
	var has_significant_bob := bob_offset.length_squared() > BOB_IDLE_EPSILON_SQUARED
	var should_update_bob := player_is_moving or is_shooting or is_auto_hitting or has_significant_bob

	if not should_update_bob:
		if gun_base.position != base_gun_position:
			gun_base.position = base_gun_position
		return

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
func _ensure_min_slot_count(min_count: int) -> void:
	while slots.size() < min_count:
		slots.append([])

	for i in range(slots.size()):
		if not (slots[i] is Array):
			slots[i] = []


func _get_slot_array(slot_index: int) -> Array:
	if slot_index < 1:
		return []

	var array_index := slot_index - 1
	if array_index >= slots.size():
		return []

	var slot: Variant = slots[array_index]
	if slot is Array:
		return slot
	return []


func get_slot_weapons(slot_index: int) -> Array:
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
		_ammo_controller.wire_weapon_manager(new_weapon, player_ammo_component, self)
	
	var slot_index: int = clamp(new_weapon.slot, 1, 9)
	var slot_array: Array = _get_slot_array(slot_index)
	
	# Insert weapon (or get existing position) and equip it
	var weapon_position := _switch_controller.insert_weapon_sorted(new_weapon, slot_array)
	selected_slot_index = slot_index
	selected_slot_position = weapon_position
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
	await _ammo_controller.reset_after_auto_fire(
		animation_player,
		current_weapon,
		is_auto_hitting,
		Callable(self, "_emit_lighter_off")
	)


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

func _equip_from_slot(slot: Array) -> void:
	if slot.size() <= selected_slot_position:
		selected_slot_position = 0

	var next_weapon := slot[selected_slot_position] as WeaponResource
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
	var player_ammo_component = _get_player_ammo_component()
	if player_ammo_component:
		_ammo_controller.wire_weapon_manager(current_weapon, player_ammo_component, self)
	
	# Retry setting up all ammo components if they weren't initialized during _ready
	if not _ammo_components_initialized:
		_setup_weapon_ammo_components()
	
	# Ensure ammo component is set (in case it wasn't set during initialization)
	if not current_weapon.ammo_component:
		player_ammo_component = _get_player_ammo_component()
		if player_ammo_component:
			_ammo_controller.wire_weapon_manager(current_weapon, player_ammo_component, self)

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
	return _ammo_controller.add_ammo_to_weapons(
		slots,
		current_weapon,
		_get_player_ammo_component(),
		amount,
		all_weapons
	)


func _on_weapon_ammo_depleted():
	"""Called when the current weapon's ammo is completely depleted

	This handles the same logic as mouse button release for auto-hit weapons
	to ensure the weapon returns to the correct idle frame when ammo runs out.
	"""
	if not current_weapon or not current_weapon.auto_hit:
		return

	# Stop auto-hitting behavior
	is_auto_hitting = false
	await _ammo_controller.reset_after_auto_fire(
		animation_player,
		current_weapon,
		is_auto_hitting,
		Callable(self, "_emit_lighter_off")
	)


func _emit_lighter_off() -> void:
	lighter_off.emit()
