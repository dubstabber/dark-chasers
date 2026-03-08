class_name WeaponManager extends Node3D

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
var _ammo_controller := WeaponAmmoController.new()
var _fire_controller := WeaponFireController.new()
var _ui_event_controller := WeaponUiEventController.new()
var _equip_controller := WeaponEquipController.new()
var _animation_state_controller: WeaponAnimationStateController = WeaponAnimationStateController.new()

# --------------------------------------------------------------------------
# Runtime state
# --------------------------------------------------------------------------
var image_height: float
var left_hand: Node
var right_hand: Node
var base_gun_position: Vector3 = Vector3.ZERO

var is_auto_hitting := false

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
	_ammo_controller.initialize_slot_wiring(slots, player, self)
	
	# Connect to player's weapon pickup signal
	if player and WeaponReceiver.check(player):
		player.weapon_added.connect(_on_weapon_added)
	
	# Connect animation player signals to track shooting animations
	if animation_player:
		animation_player.animation_started.connect(_on_animation_started)
		animation_player.animation_finished.connect(_on_animation_finished)

	_configure_equip_controller()
	
	switch_weapon(2) # default


func _configure_equip_controller() -> void:
	_equip_controller.setup(
		self,
		_switch_controller,
		_ammo_controller,
		_ui_event_controller,
		_sound_controller,
		animation_player,
		bullet_raycast,
		player,
		slots,
		Callable(self, "_get_slot_array"),
		Callable(self, "_set_is_auto_hitting"),
		Callable(self, "_on_weapon_ammo_changed"),
		Callable(self, "_on_weapon_ammo_depleted"),
		Callable(self, "_emit_weapon_switched"),
		Callable(self, "_emit_weapon_ammo_changed")
	)


func _set_is_auto_hitting(value: bool) -> void:
	is_auto_hitting = value


func _process(delta: float) -> void:
	# Skip bobbing when no weapon is equipped or core refs are unavailable
	if not current_weapon or not player or not gun_base:
		return

	var player_is_moving := player.velocity.length_squared() > BOB_IDLE_EPSILON_SQUARED
	var bob_offset := _bob_controller.get_offset()
	var has_significant_bob := bob_offset.length_squared() > BOB_IDLE_EPSILON_SQUARED
	var should_update_bob: bool = player_is_moving or _animation_state_controller.is_shooting() or is_auto_hitting or has_significant_bob

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
	_bob_controller.update_bob(delta, _animation_state_controller.is_shooting(), is_auto_hitting)


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
	_ammo_controller.ensure_weapon_wired(new_weapon, slots, player, self)
	
	var slot_index: int = clamp(new_weapon.slot, 1, 9)
	var slot_array: Array = _get_slot_array(slot_index)
	
	# Insert weapon (or get existing position) and equip it
	var weapon_position := _switch_controller.insert_weapon_sorted(new_weapon, slot_array)
	selected_slot_index = slot_index
	selected_slot_position = weapon_position
	await _equip_controller.equip_selected_slot(slot_array)


# ========================================================================== #
# Public fire control methods (called by WeaponInputComponent)
# ========================================================================== #
func try_fire() -> void:
	"""Attempt to fire the current weapon (single shot)"""
	_fire_controller.try_fire(current_weapon, animation_player, is_switching_weapon)


func try_auto_fire() -> void:
	"""Attempt to continue auto-fire for automatic weapons"""
	_fire_controller.try_auto_fire(current_weapon, animation_player, is_auto_hitting)


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
	_fire_controller.consume_and_execute_hit(current_weapon, _hit_executor)


func switch_weapon(slot_index: int) -> void:
	_equip_controller.switch_weapon(slot_index)


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
	_animation_state_controller.reset()

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
	_animation_state_controller.on_animation_started(anim_name, current_weapon, _fire_controller)


func _on_animation_finished(anim_name: String) -> void:
	"""Called when an animation finishes playing
	
	Re-enables weapon bobbing after shooting/hit animations complete.
	"""
	_animation_state_controller.on_animation_finished(anim_name, current_weapon, _fire_controller)


# ========================================================================== #
# Ammo System Signal Handlers
# ========================================================================== #
func _on_weapon_ammo_changed(current_ammo: int, max_ammo: int):
	"""Called when the current weapon's ammo changes

	Forwards the ammo change signal to any connected systems (like the HUD).
	"""
	_ui_event_controller.forward_ammo_change(
		current_ammo,
		max_ammo,
		Callable(self, "_emit_weapon_ammo_changed")
	)


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
		player,
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


func _emit_weapon_switched(weapon: WeaponResource) -> void:
	weapon_switched.emit(weapon)


func _emit_weapon_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	weapon_ammo_changed.emit(current_ammo, max_ammo)
