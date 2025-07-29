class_name WeaponManager extends Node3D

signal lighter_on
signal lighter_off
signal weapon_ammo_changed(current_ammo: int, max_ammo: int)
signal weapon_switched(weapon: WeaponResource)

# --------------------------------------------------------------------------
# Runtime state
# --------------------------------------------------------------------------
var image_height: float
var selected_slot_index := 2
var selected_slot_position := 0

var time := 0.0
var bob_time := 0.0

var smooth_movement_speed := 0.0
var movement_speed_smoothing := 5.0

var left_hand: Sprite2D
var right_hand: Sprite2D

var weapon_bob_amount: Vector2 = Vector2.ZERO
var base_gun_position: Vector2 = Vector2.ZERO

var current_weapon: WeaponResource

var is_auto_hitting := false
var bobbing_enabled := true # Controls whether weapon bobbing is active

# --------------------------------------------------------------------------
# Weapon switching state management
# --------------------------------------------------------------------------
var is_switching_weapon := false
var weapon_switch_queue: Array[int] = []

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
@export var player: CharacterBody3D
@export var gun_base: Node2D
@export var animation_player: AnimationPlayer
@export var hit_sound_player: AudioStreamPlayer3D
@export var weapon_sound_player: AudioStreamPlayer3D
@export var bullet_raycast: RayCast3D

# --------------------------------------------------------------------------
# Bob tuning values
# --------------------------------------------------------------------------
const WEAPON_BOB_SMOOTHING: float = 8.0
const WEAPON_BOB_MAX_OFFSET: float = 180.0
const WEAPON_BOB_HORIZONTAL_RANGE: float = 110.0
const WEAPON_BOB_VERTICAL_RANGE: float = 95.0
const WEAPON_BOB_SPEED: float = 2.5
const WEAPON_BOB_SPEED_REFERENCE: float = 5.0
const WEAPON_BOB_MIN_SPEED_MULT: float = 0.5
const WEAPON_BOB_MAX_SPEED_MULT: float = 2.5
const WEAPON_BOB_IDLE_SPEED_MULT: float = 0.4

# ========================================================================== #
# Lifecycle
# ========================================================================== #
func _ready() -> void:
	left_hand = gun_base.get_node_or_null("LeftHandSlot")
	right_hand = gun_base.get_node_or_null("RightHandSlot")
	base_gun_position = gun_base.position
	
	# Connect to player's weapon pickup signal
	if player and player.has_signal("weapon_added"):
		player.weapon_added.connect(_on_weapon_added)
	
	switch_weapon(2) # default


func _process(delta: float) -> void:
	_update_speed(delta)
	_update_bob(delta)
	_apply_offsets()


func _physics_process(_delta: float) -> void:
	# Don't process weapon actions if player is dead
	if player and player.has_method("is_dead") and player.is_dead():
		return

	if Input.is_action_just_pressed("hit") and current_weapon.shoot_anim_name:
		if not animation_player.is_playing() and current_weapon.can_fire():
			animation_player.play(current_weapon.shoot_anim_name)

	if is_auto_hitting and current_weapon.can_fire():
		if current_weapon.repeat_shoot_anim_name and not animation_player.is_playing():
			animation_player.play(current_weapon.repeat_shoot_anim_name)
		elif current_weapon.shoot_anim_name and not animation_player.is_playing():
			animation_player.play(current_weapon.shoot_anim_name)


# ========================================================================== #
# Update helpers
# ========================================================================== #
func _update_speed(delta: float) -> void:
	var speed: float = player.velocity.length()
	smooth_movement_speed = lerp(smooth_movement_speed, speed, delta * movement_speed_smoothing)

func _update_bob(delta: float) -> void:
	# If bobbing is disabled, lerp weapon_bob_amount to zero
	if not bobbing_enabled:
		weapon_bob_amount = weapon_bob_amount.lerp(Vector2.ZERO, delta * WEAPON_BOB_SMOOTHING)
		return

	var intensity: float = clamp(smooth_movement_speed / WEAPON_BOB_SPEED_REFERENCE, 0.0, 1.0)

	var time_scale: float = WEAPON_BOB_IDLE_SPEED_MULT
	if smooth_movement_speed > 0.1:
		time_scale = clamp(smooth_movement_speed / WEAPON_BOB_SPEED_REFERENCE,
			WEAPON_BOB_MIN_SPEED_MULT,
			WEAPON_BOB_MAX_SPEED_MULT)

	bob_time += delta * time_scale

	var h: float = sin(bob_time * WEAPON_BOB_SPEED) * WEAPON_BOB_HORIZONTAL_RANGE
	var curve: float = pow(h / WEAPON_BOB_HORIZONTAL_RANGE, 4)
	var v: float = (1.0 - curve) * WEAPON_BOB_VERTICAL_RANGE

	var target: Vector2 = Vector2(h, v) * intensity
	weapon_bob_amount = weapon_bob_amount.lerp(target, delta * WEAPON_BOB_SMOOTHING)
	weapon_bob_amount.x = clamp(weapon_bob_amount.x, -WEAPON_BOB_MAX_OFFSET, WEAPON_BOB_MAX_OFFSET)
	weapon_bob_amount.y = clamp(weapon_bob_amount.y, -WEAPON_BOB_MAX_OFFSET, WEAPON_BOB_MAX_OFFSET)


func _apply_offsets() -> void:
	if gun_base:
		gun_base.position = base_gun_position + weapon_bob_amount


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


func _unhandled_input(event: InputEvent) -> void:
	if player.blocked_movement:
		return

	# Don't process weapon input if player is dead
	if player and player.has_method("is_dead") and player.is_dead():
		return

	if event.is_action_pressed("hit") and current_weapon and current_weapon.auto_hit:
		is_auto_hitting = true
	elif event.is_action_released("hit") and is_auto_hitting:
		is_auto_hitting = false

		if animation_player.is_playing():
			await animation_player.animation_finished

		if is_auto_hitting:
			return

		if current_weapon and current_weapon.pullout_anim_name and not animation_player.is_playing():
			animation_player.stop()

			animation_player.current_animation = current_weapon.pullout_anim_name
			var pullout_anim := animation_player.get_animation(current_weapon.pullout_anim_name)
			if pullout_anim:
				animation_player.seek(pullout_anim.length, true, true)
				lighter_off.emit()

	if event.is_action_pressed("hit") and current_weapon and not current_weapon.auto_hit:
		if current_weapon.shoot_anim_name and not animation_player.is_playing() and not is_switching_weapon and current_weapon.can_fire():
			animation_player.play(current_weapon.shoot_anim_name)

	if event is InputEventKey and event.pressed:
		var num: int = event.unicode - KEY_0
		if num > 0 and num < 10:
			switch_weapon(num)

func hit() -> void:
	if current_weapon and current_weapon.has_method("hit"):
		# Consume ammo before hitting (for non-melee weapons)
		if not current_weapon.melee_attack:
			if not current_weapon.consume_ammo():
				print("Cannot fire ", current_weapon.name, " - insufficient ammo (need ", current_weapon.ammo_per_shot, ", have ", current_weapon.current_ammo, ")") # Debug - remove in production
				return # Don't hit if insufficient ammo
		current_weapon.hit()


func switch_weapon(slot_index: int) -> void:
	match slot_index:
		1: if slot_1.is_empty(): return
		2: if slot_2.is_empty(): return
		3: if slot_3.is_empty(): return
		4: if slot_4.is_empty(): return
		5: if slot_5.is_empty(): return
		6: if slot_6.is_empty(): return
		7: if slot_7.is_empty(): return
		8: if slot_8.is_empty(): return
		9: if slot_9.is_empty(): return

	if is_switching_weapon:
		weapon_switch_queue.clear()
		weapon_switch_queue.append(slot_index)
	else:
		is_switching_weapon = true
		_start_weapon_switch_process(slot_index)

func _start_weapon_switch_process(slot_index: int) -> void:
	await _process_weapon_switch(slot_index)
	await _process_weapon_switch_queue()

func _process_weapon_switch_queue() -> void:
	while not weapon_switch_queue.is_empty():
		var next_slot = weapon_switch_queue.pop_front()
		await _process_weapon_switch(next_slot)
	is_switching_weapon = false

func _process_weapon_switch(slot_index: int) -> void:
	# Determine which weapon we're switching to
	var target_slot_position = 0
	if slot_index == selected_slot_index:
		target_slot_position = selected_slot_position + 1
	
	var target_slot: Array[WeaponResource]
	match slot_index:
		1: target_slot = slot_1
		2: target_slot = slot_2
		3: target_slot = slot_3
		4: target_slot = slot_4
		5: target_slot = slot_5
		6: target_slot = slot_6
		7: target_slot = slot_7
		8: target_slot = slot_8
		9: target_slot = slot_9
	
	# Handle slot position wrapping
	if target_slot.size() <= target_slot_position:
		target_slot_position = 0
	
	# Check if we're already on the target weapon
	var target_weapon = target_slot[target_slot_position]
	if current_weapon == target_weapon:
		return # No need to switch to the same weapon
	
	# Update slot tracking
	selected_slot_index = slot_index
	selected_slot_position = target_slot_position

	# Perform the actual weapon switch
	await _equip_from_slot(target_slot)

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
	hit_sound_player.stream = current_weapon.hit_sound if current_weapon.hit_sound else null
	current_weapon.weapon_manager = self

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
	weapon_ammo_changed.emit(current_weapon.current_ammo, current_weapon.max_ammo)

	# Play draw animation for new weapon
	if current_weapon.pullout_anim_name:
		animation_player.play(current_weapon.pullout_anim_name)
		await animation_player.animation_finished


# ========================================================================== #
# Weapon sound functions (for use in AnimationPlayer)
# ========================================================================== #
func play_weapon_draw_sound() -> void:
	if not current_weapon or not weapon_sound_player:
		return
	
	var sound_to_play: AudioStream = null
	var is_playing_backwards: bool = animation_player.get_playing_speed() < 0.0

	if is_playing_backwards:
		sound_to_play = current_weapon.holster_sound
	else:
		sound_to_play = current_weapon.draw_sound
	
	if sound_to_play:
		weapon_sound_player.stream = sound_to_play
		weapon_sound_player.play()


func play_weapon_holster_sound() -> void:
	if not current_weapon or not weapon_sound_player:
		return
	
	var sound_to_play: AudioStream = null
	var is_playing_backwards: bool = animation_player.get_playing_speed() < 0.0

	if is_playing_backwards:
		sound_to_play = current_weapon.draw_sound
	else:
		sound_to_play = current_weapon.holster_sound
	
	if sound_to_play:
		weapon_sound_player.stream = sound_to_play
		weapon_sound_player.play()


func play_hit_sound() -> void:
	if not current_weapon or not hit_sound_player:
		return
	
	if current_weapon.hit_sound:
		hit_sound_player.stream = current_weapon.hit_sound
		hit_sound_player.play()


func light_lighter() -> void:
	lighter_on.emit()


func extinguish_lighter() -> void:
	lighter_off.emit()


# ========================================================================== #
# Death handling methods
# ========================================================================== #
func disable_weapon_bobbing() -> void:
	"""Disable weapon bobbing animations (called when player dies)"""
	bobbing_enabled = false
	smooth_movement_speed = 0.0


func enable_weapon_bobbing() -> void:
	"""Re-enable weapon bobbing animations (for revival or respawn)"""
	bobbing_enabled = true


func reset_weapon_on_revival() -> void:
	"""Reset weapon state when player is revived or respawns"""
	enable_weapon_bobbing()
	is_auto_hitting = false

	# If there's a current weapon, play its pullout animation to "re-equip" it
	if current_weapon and current_weapon.pullout_anim_name and animation_player:
		animation_player.stop()
		animation_player.play(current_weapon.pullout_anim_name)


# ========================================================================== #
# Ammo System Signal Handlers
# ========================================================================== #
func _on_weapon_ammo_changed(current_ammo: int, max_ammo: int):
	"""Called when the current weapon's ammo changes

	Forwards the ammo change signal to any connected systems (like the HUD).
	"""
	weapon_ammo_changed.emit(current_ammo, max_ammo)


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
