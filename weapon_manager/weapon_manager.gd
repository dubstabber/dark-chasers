class_name WeaponManager extends Node3D
"""
Handles weapon slots, equipping, animations as well as sway & bob effects that react to
player movement. The overall behaviour is unchanged; the script is just cleaned up.
"""

# --------------------------------------------------------------------------
# Runtime state
# --------------------------------------------------------------------------
var image_height: float
var selected_slot_index := 2
var selected_slot_position := 0

var time := 0.0
var sway_time := 0.0

var smooth_movement_speed := 0.0
var movement_speed_smoothing := 5.0

var left_hand: Sprite2D
var right_hand: Sprite2D

var weapon_bob_amount: Vector2 = Vector2.ZERO
var weapon_sway_amount: Vector2 = Vector2.ZERO
var base_gun_position: Vector2 = Vector2.ZERO

var current_weapon: WeaponResource

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
@export var bullet_raycast: RayCast3D

# --------------------------------------------------------------------------
# Bob & sway tuning values
# --------------------------------------------------------------------------
@export var sway_noise: NoiseTexture2D
@export var WEAPON_BOB_SPD: float = 2.0
@export var WEAPON_BOB_H: float = 3.0
@export var WEAPON_BOB_V: float = 2.0

@export var WEAPON_SWAY_SMOOTHING: float = 8.0
@export var WEAPON_SWAY_MAX_OFFSET: float = 180.0
@export var WEAPON_SWAY_HORIZONTAL_RANGE: float = 110.0
@export var WEAPON_SWAY_VERTICAL_RANGE: float = 95.0
@export var WEAPON_SWAY_SPEED: float = 2.5
@export var WEAPON_SWAY_SPEED_REFERENCE: float = 5.0
@export var WEAPON_SWAY_MIN_SPEED_MULT: float = 0.5
@export var WEAPON_SWAY_MAX_SPEED_MULT: float = 2.5
@export var WEAPON_SWAY_IDLE_INTENSITY: float = 0.3
@export var WEAPON_SWAY_IDLE_SPEED_MULT: float = 0.4

# ========================================================================== #
# Lifecycle
# ========================================================================== #
func _ready() -> void:
	left_hand = gun_base.get_node_or_null("LeftHandSlot")
	right_hand = gun_base.get_node_or_null("RightHandSlot")
	base_gun_position = gun_base.position
	switch_weapon(2) # default

func _process(delta: float) -> void:
	_update_speed(delta)
	_update_sway(delta)
	_update_bob(delta)
	_apply_offsets()

func _physics_process(_delta: float) -> void:
	if Input.is_action_pressed("hit") and current_weapon.auto_hit:
		if current_weapon and current_weapon.shoot_anim_name and not animation_player.is_playing():
			animation_player.play(current_weapon.shoot_anim_name)

# ========================================================================== #
# Update helpers
# ========================================================================== #
func _update_speed(delta: float) -> void:
	var speed: float = player.velocity.length()
	smooth_movement_speed = lerp(smooth_movement_speed, speed, delta * movement_speed_smoothing)

func _update_sway(delta: float) -> void:
	var intensity: float = clamp(smooth_movement_speed / WEAPON_SWAY_SPEED_REFERENCE, 0.0, 1.0)

	var time_scale: float = WEAPON_SWAY_IDLE_SPEED_MULT
	if smooth_movement_speed > 0.1:
		time_scale = clamp(smooth_movement_speed / WEAPON_SWAY_SPEED_REFERENCE,
			WEAPON_SWAY_MIN_SPEED_MULT,
			WEAPON_SWAY_MAX_SPEED_MULT)

	sway_time += delta * time_scale

	var h: float = sin(sway_time * WEAPON_SWAY_SPEED) * WEAPON_SWAY_HORIZONTAL_RANGE
	var curve: float = pow(h / WEAPON_SWAY_HORIZONTAL_RANGE, 4)
	var v: float = (1.0 - curve) * WEAPON_SWAY_VERTICAL_RANGE

	var target: Vector2 = Vector2(h, v) * intensity
	weapon_sway_amount = weapon_sway_amount.lerp(target, delta * WEAPON_SWAY_SMOOTHING)
	weapon_sway_amount.x = clamp(weapon_sway_amount.x, -WEAPON_SWAY_MAX_OFFSET, WEAPON_SWAY_MAX_OFFSET)
	weapon_sway_amount.y = clamp(weapon_sway_amount.y, -WEAPON_SWAY_MAX_OFFSET, WEAPON_SWAY_MAX_OFFSET)

func _update_bob(delta: float) -> void:
	var has_input: bool = Input.get_axis("move-left", "move-right") != 0.0 or Input.get_axis("move-up", "move-down") != 0.0
	var speed: float = player.velocity.length()
	var active: bool = speed > 0.1 and has_input and player.is_on_floor()

	if active:
		var mult: float = clamp(speed / WEAPON_SWAY_SPEED_REFERENCE, WEAPON_SWAY_MIN_SPEED_MULT, WEAPON_SWAY_MAX_SPEED_MULT)
		_weapon_bob(delta, WEAPON_BOB_SPD * mult, WEAPON_BOB_H, WEAPON_BOB_V)
	else:
		weapon_bob_amount = weapon_bob_amount.lerp(Vector2.ZERO, delta * 8.0)


func _apply_offsets() -> void:
	if gun_base:
		gun_base.position = base_gun_position + weapon_sway_amount + weapon_bob_amount


func _weapon_bob(delta: float, bob_speed: float, hbob: float, vbob: float) -> void:
	time += delta
	weapon_bob_amount.x = sin(time * bob_speed) * hbob
	weapon_bob_amount.y = abs(cos(time * bob_speed) * vbob)


func _unhandled_input(event: InputEvent) -> void:
	if player.blocked_movement:
		return

	if event.is_action_pressed("hit") and not current_weapon.auto_hit:
		if current_weapon and current_weapon.shoot_anim_name and not animation_player.is_playing():
			animation_player.play(current_weapon.shoot_anim_name)
			hit_sound_player.play()

	if event is InputEventKey and event.pressed:
		var num: int = event.unicode - KEY_0
		if num > 0 and num < 10:
			switch_weapon(num)

func hit() -> void:
	if current_weapon and current_weapon.has_method("hit"):
		current_weapon.hit()


func switch_weapon(slot_index: int) -> void:
	if animation_player.is_playing():
		await animation_player.animation_finished

	
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

	if slot_index != selected_slot_index:
		selected_slot_index = slot_index
		selected_slot_position = 0
	else:
		selected_slot_position += 1

	match slot_index:
		1: _equip_from_slot(slot_1)
		2: _equip_from_slot(slot_2)
		3: _equip_from_slot(slot_3)
		4: _equip_from_slot(slot_4)
		5: _equip_from_slot(slot_5)
		6: _equip_from_slot(slot_6)
		7: _equip_from_slot(slot_7)
		8: _equip_from_slot(slot_8)
		9: _equip_from_slot(slot_9)

func _equip_from_slot(slot: Array[WeaponResource]) -> void:
	if slot.size() <= selected_slot_position:
		selected_slot_position = 0

	var next_weapon := slot[selected_slot_position]
	if current_weapon == next_weapon:
		return

	# Put away current weapon
	if current_weapon and current_weapon.pullout_anim_name:
		animation_player.play_backwards(current_weapon.pullout_anim_name)
		await animation_player.animation_finished

	# Equip new one
	current_weapon = next_weapon
	bullet_raycast.target_position.z = -1 if current_weapon.melee_attack else -1000
	hit_sound_player.stream = current_weapon.hit_sound if current_weapon.hit_sound else null
	current_weapon.weapon_manager = self

	if current_weapon.pullout_anim_name:
		animation_player.play(current_weapon.pullout_anim_name)
		await animation_player.animation_finished


func _get_sway_noise() -> float:
	return sway_noise.noise.get_noise_2d(player.position.x, player.position.z)
